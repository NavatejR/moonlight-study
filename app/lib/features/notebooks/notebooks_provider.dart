import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';

/// A notebook with its documents, shown on the Notebooks screen.
class NotebookView {
  const NotebookView({
    required this.id,
    required this.title,
    required this.documents,
  });

  final int id;
  final String title;
  final List<Document> documents;

  bool get isEmpty => documents.isEmpty;
}

/// Watches all notebooks with their documents (joined).
final notebooksProvider =
    StreamProvider.autoDispose<List<NotebookView>>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  await for (final allNotebooks in (db.select(db.notebooks)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch()) {
    final views = <NotebookView>[];
    for (final notebook in allNotebooks) {
      final links = await (db.select(db.notebookDocuments)
            ..where((t) => t.notebookId.equals(notebook.id)))
          .get();
      final ids = links.map((l) => l.documentId).toList();
      final docs = ids.isEmpty
          ? const <Document>[]
          : await (db.select(db.documents)
                ..where((t) => t.id.isIn(ids))
                ..orderBy([(t) => OrderingTerm.asc(t.name)]))
              .get();
      views.add(NotebookView(
        id: notebook.id,
        title: notebook.title,
        documents: docs,
      ));
    }
    yield views;
  }
});

/// The documents belonging to a single notebook.
final notebookDocumentsProvider =
    StreamProvider.autoDispose.family<List<Document>, int>(
        (ref, notebookId) async* {
  final db = ref.watch(appDatabaseProvider);
  yield* (db.select(db.notebookDocuments)
        ..where((t) => t.notebookId.equals(notebookId)))
      .watch()
      .asyncMap((links) async {
    final ids = links.map((l) => l.documentId).toList();
    if (ids.isEmpty) return const <Document>[];
    return (db.select(db.documents)
          ..where((t) => t.id.isIn(ids))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  });
});

/// Selected notebook for the reader screen.
final activeNotebookProvider =
    NotifierProvider<ActiveNotebookNotifier, int?>(ActiveNotebookNotifier.new);

class ActiveNotebookNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void open(int notebookId) => state = notebookId;

  void close() => state = null;
}