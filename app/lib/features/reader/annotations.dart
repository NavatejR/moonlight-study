import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/logging/app_logger.dart';

/// A normalized rectangle relative to a PDF page (0..1 fractions).
class PdfRectNorm {
  const PdfRectNorm({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  Rect toScreenRect(Rect pageRect) => Rect.fromLTWH(
        pageRect.left + left * pageRect.width,
        pageRect.top + top * pageRect.height,
        width * pageRect.width,
        height * pageRect.height,
      );

  factory PdfRectNorm.fromScreen(Rect pageRect, Rect screenRect) =>
      PdfRectNorm(
        left: pageRect.isEmpty ? 0 : (screenRect.left - pageRect.left) / pageRect.width,
        top: pageRect.isEmpty ? 0 : (screenRect.top - pageRect.top) / pageRect.height,
        width: pageRect.isEmpty ? 0 : screenRect.width / pageRect.width,
        height: pageRect.isEmpty ? 0 : screenRect.height / pageRect.height,
      );

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'width': width,
        'height': height,
      };

  factory PdfRectNorm.fromJson(Map<String, dynamic> json) => PdfRectNorm(
        left: (json['left'] as num?)?.toDouble() ?? 0,
        top: (json['top'] as num?)?.toDouble() ?? 0,
        width: (json['width'] as num?)?.toDouble() ?? 0,
        height: (json['height'] as num?)?.toDouble() ?? 0,
      );
}

/// A parsed annotation ready for the UI.
class AnnotationView {
  const AnnotationView({required this.row, required this.payload});

  final PdfAnnotation row;
  final AnnotationPayload payload;
}

enum AnnotationPayloadType { highlight, sticky }

class AnnotationPayload {
  const AnnotationPayload({required this.type, required this.data});

  final AnnotationPayloadType type;
  final Map<String, dynamic> data;

  static AnnotationPayload parse(PdfAnnotation row) {
    late final Map<String, dynamic> json;
    try {
      json = jsonDecode(row.data) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      logger.warning('Failed to parse annotation payload for row ${row.id}', error: e, stackTrace: stackTrace);
      json = const {};
    }
    final rawType = (json['type'] as String?) ?? row.type;
    final type = rawType == 'sticky'
        ? AnnotationPayloadType.sticky
        : AnnotationPayloadType.highlight;
    return AnnotationPayload(type: type, data: json);
  }

  factory AnnotationPayload.highlight(PdfRectNorm rect, String color) =>
      AnnotationPayload(
        type: AnnotationPayloadType.highlight,
        data: {'type': 'highlight', 'rect': rect.toJson(), 'color': color},
      );

  /// A text-selection highlight: one rectangle per selected line, plus the
  /// highlighted text itself.
  factory AnnotationPayload.highlightRects(
    List<PdfRectNorm> rects,
    String color, {
    String? text,
  }) =>
      AnnotationPayload(
        type: AnnotationPayloadType.highlight,
        data: {
          'type': 'highlight',
          'rects': [for (final r in rects) r.toJson()],
          if (text != null && text.isNotEmpty) 'text': text,
          'color': color,
        },
      );

  factory AnnotationPayload.sticky(Offset point, String text, String color) =>
      AnnotationPayload(
        type: AnnotationPayloadType.sticky,
        data: {'type': 'sticky', 'point': {'x': point.dx, 'y': point.dy}, 'text': text, 'color': color},
      );

  /// The highlight rectangles for this annotation (one per selected line).
  /// Single-rectangle highlights stored under `rect` are returned as a one
  /// element list so both legacy and text-selection highlights render alike.
  List<PdfRectNorm> get rects {
    if (type != AnnotationPayloadType.highlight) return const [];
    final raw = data['rects'];
    if (raw is List) {
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>) PdfRectNorm.fromJson(item),
      ];
    }
    final single = data['rect'];
    if (single is Map<String, dynamic>) return [PdfRectNorm.fromJson(single)];
    return const [];
  }

  PdfRectNorm? get rect => rects.isEmpty ? null : rects.first;

  Offset get point => type == AnnotationPayloadType.sticky
      ? Offset(
          ((data['point'] as Map<String, dynamic>)['x'] as num).toDouble(),
          ((data['point'] as Map<String, dynamic>)['y'] as num).toDouble(),
        )
      : Offset.zero;

  String get text => (data['text'] as String?) ?? '';

  String get color => (data['color'] as String?) ?? '#A3BFA6';

  String encode() => jsonEncode(data);
}

/// Streams annotations for one document.
final pdfAnnotationsProvider =
    StreamProvider.autoDispose.family<List<AnnotationView>, int>(
        (ref, documentId) async* {
  final db = ref.watch(appDatabaseProvider);
  yield* (db.select(db.pdfAnnotations)
        ..where((t) => t.documentId.equals(documentId))
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .watch()
      .map((rows) => [
            for (final row in rows)
              AnnotationView(row: row, payload: AnnotationPayload.parse(row)),
          ]);
});

/// Adds a new annotation for [documentId], returning the inserted row.
Future<PdfAnnotation> addPdfAnnotation(
  AppDatabase db,
  int documentId,
  int pageIndex,
  AnnotationPayload payload,
) async {
  final id = await db.into(db.pdfAnnotations).insert(
        PdfAnnotationsCompanion.insert(
          documentId: documentId,
          pageIndex: Value(pageIndex),
          type: payload.type.name,
          data: payload.encode(),
        ),
      );
  return (db.select(db.pdfAnnotations)..where((t) => t.id.equals(id)))
      .getSingle();
}

/// Edits the sticky text of an annotation.
Future<void> updatePdfAnnotationText(
  AppDatabase db,
  PdfAnnotation annotation,
  String text,
) {
  final payload = AnnotationPayload.parse(annotation).deepCopy(text: text);
  return (db.update(db.pdfAnnotations)
        ..where((t) => t.id.equals(annotation.id)))
      .write(PdfAnnotationsCompanion(data: Value(payload.encode())));
}

/// Removes an annotation row.
Future<void> deletePdfAnnotation(AppDatabase db, PdfAnnotation annotation) async {
  await (db.delete(db.pdfAnnotations)..where((t) => t.id.equals(annotation.id))).go();
}

extension on AnnotationPayload {
  AnnotationPayload deepCopy({String? text, String? color}) {
    final json = Map<String, dynamic>.from(data);
    if (text != null) json['text'] = text;
    if (color != null) json['color'] = color;
    return AnnotationPayload(type: type, data: json);
  }
}

/// A reversible annotation operation captured for undo/redo. Each side
/// applies its change straight to the database; the watch-based
/// [pdfAnnotationsProvider] re-emits automatically.
class AnnotationAction {
  const AnnotationAction({required this.undo, required this.redo});

  final Future<void> Function(AppDatabase db) undo;
  final Future<void> Function(AppDatabase db) redo;
}

/// Undo/redo stack sizes (what the toolbar needs to enable/disable buttons).
class AnnotationsHistoryState {
  const AnnotationsHistoryState({this.undoCount = 0, this.redoCount = 0});

  final int undoCount;
  final int redoCount;

  bool get canUndo => undoCount > 0;
  bool get canRedo => redoCount > 0;

  AnnotationsHistoryState copyWith({int? undoCount, int? redoCount}) =>
      AnnotationsHistoryState(
        undoCount: undoCount ?? this.undoCount,
        redoCount: redoCount ?? this.redoCount,
      );
}

/// Session-scoped undo/redo for one document's annotations. History lives in
/// memory only; it resets when the reader (or the open document) changes.
class AnnotationsHistoryNotifier
    extends AutoDisposeFamilyNotifier<AnnotationsHistoryState, int> {
  final List<AnnotationAction> _undo = [];
  final List<AnnotationAction> _redo = [];

  @override
  AnnotationsHistoryState build(int documentId) => const AnnotationsHistoryState();

  void record(AnnotationAction action) {
    _undo.add(action);
    _redo.clear();
    state = state.copyWith(undoCount: _undo.length, redoCount: 0);
  }

  Future<void> undo(AppDatabase db) async {
    if (_undo.isEmpty) return;
    final action = _undo.removeLast();
    await action.undo(db);
    _redo.add(action);
    state = state.copyWith(undoCount: _undo.length, redoCount: _redo.length);
  }

  Future<void> redo(AppDatabase db) async {
    if (_redo.isEmpty) return;
    final action = _redo.removeLast();
    await action.redo(db);
    _undo.add(action);
    state = state.copyWith(undoCount: _undo.length, redoCount: _redo.length);
  }
}

final annotationHistoryProvider = NotifierProvider.autoDispose
    .family<AnnotationsHistoryNotifier, AnnotationsHistoryState, int>(
  AnnotationsHistoryNotifier.new,
);