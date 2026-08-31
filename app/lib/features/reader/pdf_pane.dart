import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../../core/db/app_database.dart';
import '../../core/settings/settings_storage.dart';
import '../../core/theme/colors.dart';
import 'annotations.dart';
import 'pages_panel.dart';

/// Which annotation tool is armed in the PDF pane.
enum AnnotateTool { none, highlight, sticky }

/// A handle on a live text selection, used to drive S/E/C actions.
class SelectionRequest {
  const SelectionRequest({required this.text, required this.pageNumber});
  final String text;
  final int pageNumber;
}

/// Left-hand PDF pane: renders the pdf, annotation overlays, selection menu.
class PdfPane extends ConsumerWidget {
  const PdfPane({
    super.key,
    required this.document,
    required this.tool,
    required this.controller,
    required this.onToolChanged,
    required this.onSelectionAction,
    required this.pagesPanelOpen,
    required this.onPagesPanelToggle,
    required this.currentPage,
    this.onPageChanged,
  });

  final Document document;
  final AnnotateTool tool;
  final pdfrx.PdfViewerController controller;
  final ValueChanged<AnnotateTool> onToolChanged;
  final void Function(SelectionRequest request, String action) onSelectionAction;
  final bool pagesPanelOpen;
  final VoidCallback onPagesPanelToggle;
  final ValueNotifier<int> currentPage;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annotations = ref.watch(pdfAnnotationsProvider(document.id)).value ??
        const [];
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final history = ref.watch(annotationHistoryProvider(document.id));
    final darkReading = settings.readerDarkMode;

    return Column(
      children: [
        _Toolbar(
          tool: tool,
          highlightColor: settings.highlightColor,
          onToolChanged: onToolChanged,
          undoEnabled: history.canUndo,
          redoEnabled: history.canRedo,
          onUndo: () => _applyHistory(ref, undo: true),
          onRedo: () => _applyHistory(ref, undo: false),
          darkReading: darkReading,
          onDarkToggle: () {
            ref
                .read(settingsProvider.notifier)
                .apply((s) => s.copyWith(readerDarkMode: !darkReading));
          },
          pagesPanelOpen: pagesPanelOpen,
          onPagesPanelToggle: onPagesPanelToggle,
        ),
        Expanded(
          child: Row(
            children: [
              if (pagesPanelOpen) ...[
                SizedBox(
                  width: 120,
                  child: PagesPanel(
                    controller: controller,
                    currentPage: currentPage,
                    document: document,
                  ),
                ),
                Container(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ],
              Expanded(
                child: _AnnotatedPdfViewer(
                  document: document,
                  tool: tool,
                  controller: controller,
                  highlightColor: settings.highlightColor,
                  annotations: annotations,
                  fitMode: settings.readerFitMode,
                  darkReading: darkReading,
                  onSelectionAction: onSelectionAction,
                  onToolChanged: onToolChanged,
                  onPageChanged: onPageChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _applyHistory(WidgetRef ref, {required bool undo}) async {
    final db = ref.read(appDatabaseProvider);
    final notifier =
        ref.read(annotationHistoryProvider(document.id).notifier);
    if (undo) {
      await notifier.undo(db);
    } else {
      await notifier.redo(db);
    }
    ref.invalidate(pdfAnnotationsProvider(document.id));
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.tool,
    required this.highlightColor,
    required this.onToolChanged,
    required this.undoEnabled,
    required this.redoEnabled,
    required this.onUndo,
    required this.onRedo,
    required this.darkReading,
    required this.onDarkToggle,
    required this.pagesPanelOpen,
    required this.onPagesPanelToggle,
  });

  final AnnotateTool tool;
  final String highlightColor;
  final ValueChanged<AnnotateTool> onToolChanged;
  final bool undoEnabled;
  final bool redoEnabled;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool darkReading;
  final VoidCallback onDarkToggle;
  final bool pagesPanelOpen;
  final VoidCallback onPagesPanelToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => onToolChanged(AnnotateTool.none),
            style: TextButton.styleFrom(
              foregroundColor: tool == AnnotateTool.none
                  ? CoffeeColors.coffee
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              backgroundColor: tool == AnnotateTool.none
                  ? CoffeeColors.caramel.withValues(alpha: 0.15)
                  : null,
            ),
            icon: const Icon(Icons.pan_tool_alt_rounded, size: 18),
            label: const Text('Select'),
          ),
          TextButton.icon(
            onPressed: () => onToolChanged(AnnotateTool.highlight),
            style: TextButton.styleFrom(
              foregroundColor: tool == AnnotateTool.highlight
                  ? CoffeeColors.coffee
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              backgroundColor: tool == AnnotateTool.highlight
                  ? CoffeeColors.caramel.withValues(alpha: 0.15)
                  : null,
            ),
            icon: const Icon(Icons.border_color_rounded, size: 18),
            label: const Text('Highlight'),
          ),
          TextButton.icon(
            onPressed: () => onToolChanged(AnnotateTool.sticky),
            style: TextButton.styleFrom(
              foregroundColor: tool == AnnotateTool.sticky
                  ? CoffeeColors.coffee
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              backgroundColor: tool == AnnotateTool.sticky
                  ? CoffeeColors.caramel.withValues(alpha: 0.15)
                  : null,
            ),
            icon: const Icon(Icons.sticky_note_2_rounded, size: 18),
            label: const Text('Sticky note'),
          ),
          const Spacer(),
          IconButton(
            onPressed: onPagesPanelToggle,
            tooltip: pagesPanelOpen
                ? 'Hide page thumbnails'
                : 'Show page thumbnails',
            visualDensity: VisualDensity.compact,
            color: pagesPanelOpen
                ? CoffeeColors.caramel
                : Theme.of(context).colorScheme.onSurfaceVariant,
            icon: Icon(
              Icons.view_list_rounded,
              size: 19,
              color: pagesPanelOpen ? CoffeeColors.coffee : null,
            ),
          ),
          IconButton(
            onPressed: onDarkToggle,
            tooltip: darkReading
                ? 'Night reading on (tap to go back to paper)'
                : 'Night reading (inverts page for low-light reading)',
            visualDensity: VisualDensity.compact,
            color: darkReading
                ? CoffeeColors.caramel
                : Theme.of(context).colorScheme.onSurfaceVariant,
            icon: Icon(
              darkReading
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              size: 19,
            ),
          ),
          IconButton(
            onPressed: undoEnabled ? onUndo : null,
            tooltip: 'Undo annotation',
            visualDensity: VisualDensity.compact,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            icon: const Icon(Icons.undo_rounded, size: 19),
          ),
          IconButton(
            onPressed: redoEnabled ? onRedo : null,
            tooltip: 'Redo annotation',
            visualDensity: VisualDensity.compact,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            icon: const Icon(Icons.redo_rounded, size: 19),
          ),
          Tooltip(
            message: 'Esc to leave the annotation tool',
            child: Icon(
              Icons.help_outline_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnotatedPdfViewer extends ConsumerStatefulWidget {
  const _AnnotatedPdfViewer({
    required this.document,
    required this.tool,
    required this.controller,
    required this.highlightColor,
    required this.annotations,
    required this.fitMode,
    required this.darkReading,
    required this.onSelectionAction,
    required this.onToolChanged,
    this.onPageChanged,
  });

  final Document document;
  final AnnotateTool tool;
  final pdfrx.PdfViewerController controller;
  final String highlightColor;
  final List<AnnotationView> annotations;
  final String fitMode;
  final bool darkReading;
  final void Function(SelectionRequest request, String action) onSelectionAction;
  final ValueChanged<AnnotateTool> onToolChanged;
  final ValueChanged<int>? onPageChanged;

  @override
  ConsumerState<_AnnotatedPdfViewer> createState() => _AnnotatedPdfViewerState();
}

class _AnnotatedPdfViewerState extends ConsumerState<_AnnotatedPdfViewer> {
  late pdfrx.PdfViewerController _controller;

  /// On-screen geometry (page + widget rect) for pages that have been laid
  /// out, keyed by 1-based page number. Used to convert selection bounds into
  /// page-fraction highlight rects with pdfrx's own coordinate math.
  final Map<int, ({pdfrx.PdfPage page, Rect pageRect})> _pageGeometry = {};
  bool _highlightInFlight = false;

  /// The right-click menu lives in an app-owned [OverlayEntry] instead of
  /// pdfrx's internal context-menu overlay, so its lifecycle never gets
  /// wedged (menu would otherwise stop appearing until the pane is rebuilt).
  OverlayEntry? _contextMenuEntry;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }

  @override
  void didUpdateWidget(_AnnotatedPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tool != widget.tool) _highlightInFlight = false;
  }

  @override
  void dispose() {
    _removeContextMenu();
    super.dispose();
  }

  void _removeContextMenu() {
    final entry = _contextMenuEntry;
    _contextMenuEntry = null;
    entry?.remove();
  }

  /// Shows [menu] in an overlay anchored to [anchor] (a global rect, e.g. the
/// selected text or the click point). The host flips the menu above/below the
/// anchor and clamps it inside the window so it always stays on screen.
/// Removes any previously open menu first. Called from the pointer event
/// handler, so it can insert the overlay synchronously.
  void _showContextMenu(BuildContext context, Rect anchor, Widget menu) {
    _removeContextMenu();
    final entry = OverlayEntry(
      builder: (overlayContext) => _ContextMenuHost(
        anchor: anchor,
        dismiss: _removeContextMenu,
        child: menu,
      ),
    );
    _contextMenuEntry = entry;
    Overlay.of(context).insert(entry);
  }

  /// Converts a viewer-local [local] position (pdfrx page/viewer space) to
  /// window-global coordinates for overlay placement, or null when the pane
  /// has no render box yet.
  Offset? _viewerToGlobal(Offset local) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return null;
    return renderBox.localToGlobal(local);
  }

  /// Converts a viewer-local [rect] to window-global coordinates.
  Rect? _viewerRectToGlobal(Rect rect) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return null;
    return Rect.fromPoints(
      renderBox.localToGlobal(rect.topLeft),
      renderBox.localToGlobal(rect.bottomRight),
    );
  }

  pdfrx.PdfTextSelectionDelegate? _delegateOf(pdfrx.PdfTextSelection selection) =>
      selection is pdfrx.PdfTextSelectionDelegate ? selection : null;

  /// Fired by pdfrx (debounced ~300 ms) when the text selection settles.
  /// Open the S/E/C menu for the select tool, or auto-highlight for the
  /// highlight tool — no right-click required.
  void _handleTextSelectionChanged(pdfrx.PdfTextSelection selection) {
    if (!mounted || _contextMenuEntry != null) return;
    if (widget.tool == AnnotateTool.sticky) return;
    if (!selection.hasSelectedText) return;

    if (widget.tool == AnnotateTool.highlight) {
      if (_highlightInFlight) return;
      _highlightInFlight = true;
      final delegate = _delegateOf(selection);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || delegate == null || !delegate.hasSelectedText) {
          _highlightInFlight = false;
          return;
        }
        await _runSelectionAction(delegate, 'highlight');
        if (mounted) widget.onToolChanged(AnnotateTool.none);
      });
      return;
    }

    _showMenuForSelection(selection);
  }

  /// Opens the S/E/C menu wrapped around the current selection.
  Future<void> _showMenuForSelection(pdfrx.PdfTextSelection selection) async {
    final delegate = _delegateOf(selection);
    if (delegate == null || !delegate.hasSelectedText) return;
    final ranges = await delegate.getSelectedTextRanges();
    if (!mounted || ranges.isEmpty) return;
    final geometry = _pageGeometry[ranges.first.pageNumber];
    if (geometry == null) return;
    final localRect = ranges.first.bounds.toRectInDocument(
      page: geometry.page,
      pageRect: geometry.pageRect,
    );
    final anchor = _viewerRectToGlobal(localRect);
    if (anchor == null || _contextMenuEntry != null) return;
    _showContextMenu(
      context,
      anchor,
      _SelectionMenu(
        onHighlight: () => _runSelectionAction(delegate, 'highlight'),
        onSummarize: () => _runSelectionAction(delegate, 'summarize'),
        onExplain: () => _runSelectionAction(delegate, 'explain'),
        onCopy: () => _runSelectionAction(delegate, 'copy'),
        onDismiss: _removeContextMenu,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only the sticky tool takes over the page surface (tap-to-place). The
    // highlight tool used to box a freeform region — instead it keeps pdfrx
    // text selection live so highlights snap to the actual glyphs (see
    // _highlightSelection).
    final interactive = widget.tool == AnnotateTool.sticky;
    final viewer = pdfrx.PdfViewer.file(
      widget.document.filePath,
      controller: _controller,
      params: pdfrx.PdfViewerParams(
        backgroundColor: _pageBackground(context),
        panEnabled: !interactive,
        textSelectionParams: pdfrx.PdfTextSelectionParams(
          enabled: !interactive,
          showContextMenuAutomatically: false,
          onTextSelectionChange: _handleTextSelectionChanged,
        ),
        onPageChanged: (page) {
          setState(() {});
          if (page != null) widget.onPageChanged?.call(page);
        },
        // The right-click menu is handled ourselves (see _handleSecondaryTap):
        // pdfrx's build-time context menu is disabled so its internal menu
        // overlay never interferes.
        onGeneralTap: (context, controller, details) {
          if (details.type == pdfrx.PdfViewerGeneralTapType.secondaryTap) {
            return _handleSecondaryTap(context, controller, details);
          }
          return false;
        },
        pageOverlaysBuilder: (context, pageRect, page) {
          _pageGeometry[page.pageNumber] = (page: page, pageRect: pageRect);
          final pageIndex = page.pageNumber - 1;
          final pageAnnotations = widget.annotations
              .where((a) => a.row.pageIndex == pageIndex)
              .toList();
          return [
            // Sticky-note hit area sits above everything for this page.
            _ToolOverlay(
              pageRect: pageRect,
              tool: widget.tool,
              pageAnnotations: pageAnnotations,
              darkReading: widget.darkReading,
              onTapPoint: (point) => _startSticky(pageIndex, point),
              onOpenSticky: (a) => _editSticky(a),
              onDeleteSticky: (a) => _deleteSticky(a),
            ),
          ];
        },
      ),
    );

    // Night reading: invert the rendered page so white text-PDFs read on a
    // dark field. Highlights/stickies are drawn with compensated colors (see
    // _ToolOverlay) so they survive the filter un-changed. Photos also invert
    // — the classic tradeoff of filter-based night mode.
    if (!widget.darkReading) return viewer;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -1, 0, 0, 0, 255, //
        0, -1, 0, 0, 255, //
        0, 0, -1, 0, 255, //
        0, 0, 0, 1, 0, //
      ]),
      child: viewer,
    );
  }

  Color _pageBackground(BuildContext context) {
    if (widget.darkReading) return const Color(0xFF17130F);
    return switch (ref.read(settingsProvider).value?.readingTheme ??
        'paper') {
      'sepia' => const Color(0xFFF4E9D5),
      'midnight' => const Color(0xFF1E1C1B),
      _ => Theme.of(context).colorScheme.surface,
    };
  }

  /// Handles a secondary (right) click on the PDF. Shows the selection menu
  /// when the click landed on live selected text, otherwise the Select
  /// All / Copy menu. Always consumes the gesture so pdfrx never builds its
  /// own context menu.
  bool _handleSecondaryTap(
    BuildContext context,
    pdfrx.PdfViewerController controller,
    pdfrx.PdfViewerGeneralTapHandlerDetails details,
  ) {
    final delegate = controller.textSelectionDelegate;

    if (details.tapOn == pdfrx.PdfViewerPart.selectedText &&
        delegate.hasSelectedText) {
      if (widget.tool == AnnotateTool.highlight && !_highlightInFlight) {
        // Highlight tool armed: turn the selection into a highlight right
        // away (no menu) instead of showing the S/E/C popup.
        _highlightInFlight = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || !delegate.hasSelectedText) {
            _highlightInFlight = false;
            return;
          }
          await _runSelectionAction(delegate, 'highlight');
          if (mounted) widget.onToolChanged(AnnotateTool.none);
        });
        return true;
      }
      final global = _viewerToGlobal(details.localPosition);
      if (global == null) return true;
      _showContextMenu(
        context,
        Rect.fromLTWH(global.dx, global.dy, 2, 2),
        _SelectionMenu(
          onHighlight: () => _runSelectionAction(delegate, 'highlight'),
          onSummarize: () => _runSelectionAction(delegate, 'summarize'),
          onExplain: () => _runSelectionAction(delegate, 'explain'),
          onCopy: () => _runSelectionAction(delegate, 'copy'),
          onDismiss: _removeContextMenu,
        ),
      );
      return true;
    }

    // Right-click on non-selected text or the page background: offer
    // Select All, plus Copy when a text selection already exists.
    final global = _viewerToGlobal(details.localPosition);
    if (global == null) return true;
    _showContextMenu(
      context,
      Rect.fromLTWH(global.dx, global.dy, 2, 2),
      _PdfContextMenu(
        onSelectAll: () => delegate.selectAllText(),
        onCopy: delegate.hasSelectedText
            ? () => delegate.copyTextSelection()
            : null,
        onDismiss: _removeContextMenu,
      ),
    );
    return true;
  }

  Future<void> _runSelectionAction(
    pdfrx.PdfTextSelectionDelegate delegate,
    String action,
  ) async {
    if (!delegate.hasSelectedText) return;
    if (action == 'highlight') {
      await _highlightSelection(delegate);
      return;
    }
    final text = await delegate.getSelectedText();
    if (text.trim().isEmpty) return;
    final page = _controller.pageNumber ?? 1;
    widget.onSelectionAction(
      SelectionRequest(text: text.trim(), pageNumber: page),
      action,
    );
  }

  /// Turns the current pdfrx text selection into glyph-accurate highlights:
  /// one normalized rectangle per selected line, persisted as a single
  /// annotation along with the highlighted text. Uses pdfrx's own
  /// [pdfrx.PdfRectExt.toRectInDocument] coordinate math so the rects land
  /// exactly on the selected glyphs (rotation-safe).
  Future<void> _highlightSelection(
    pdfrx.PdfTextSelectionDelegate delegate,
  ) async {
    try {
      final ranges = await delegate.getSelectedTextRanges();
      if (ranges.isEmpty) {
        _toast('Select some text to highlight first.');
        return;
      }

      final rects = <PdfRectNorm>[];
      for (final range in ranges) {
        final geometry = _pageGeometry[range.pageNumber];
        if (geometry == null) continue;
        final inDocument = range.bounds.toRectInDocument(
          page: geometry.page,
          pageRect: geometry.pageRect,
        );
        final norm = PdfRectNorm.fromScreen(geometry.pageRect, inDocument);
        if (norm.width > 0 && norm.height > 0) rects.add(norm);
      }
      if (rects.isEmpty) {
        _toast('Could not map that selection — try again.');
        return;
      }

      final text = await delegate.getSelectedText();
      await _saveHighlight(
        ranges.first.pageNumber - 1,
        rects,
        text: text.trim(),
      );
      await delegate.clearTextSelection();
      _toast('Text highlighted.');
    } catch (e) {
      _toast('Highlight failed: $e');
    } finally {
      _highlightInFlight = false;
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _saveHighlight(
    int pageIndex,
    List<PdfRectNorm> rects, {
    String? text,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final payload =
        AnnotationPayload.highlightRects(rects, widget.highlightColor, text: text);
    final row = await addPdfAnnotation(db, widget.document.id, pageIndex, payload);
    ref.invalidate(pdfAnnotationsProvider(widget.document.id));
    _recordAdd(row, payload);
  }

  AnnotationsHistoryNotifier _history() =>
      ref.read(annotationHistoryProvider(widget.document.id).notifier);

  void _recordAdd(PdfAnnotation row, AnnotationPayload payload) {
    _history().record(
      AnnotationAction(
        undo: (db) => deletePdfAnnotation(db, row),
        redo: (db) => addPdfAnnotation(
          db,
          row.documentId,
          row.pageIndex,
          payload,
        ),
      ),
    );
  }

  Future<void> _startSticky(int pageIndex, Offset point) async {
    final db = ref.read(appDatabaseProvider);
    final payload = AnnotationPayload.sticky(point, '', widget.highlightColor);
    final row = await addPdfAnnotation(db, widget.document.id, pageIndex, payload);
    ref.invalidate(pdfAnnotationsProvider(widget.document.id));
    _recordAdd(row, payload);
  }

  Future<void> _editSticky(AnnotationView annotation) async {
    final controller = TextEditingController(text: annotation.payload.text);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sticky note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Write a note…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (text == null) return;
    final db = ref.read(appDatabaseProvider);
    final row = annotation.row;
    final before = AnnotationPayload.parse(row).text;
    final after = text;
    await updatePdfAnnotationText(db, row, after);
    ref.invalidate(pdfAnnotationsProvider(widget.document.id));
    _history().record(
      AnnotationAction(
        undo: (db) => updatePdfAnnotationText(db, row, before),
        redo: (db) => updatePdfAnnotationText(db, row, after),
      ),
    );
  }

  Future<void> _deleteSticky(AnnotationView annotation) async {
    final db = ref.read(appDatabaseProvider);
    final row = annotation.row;
    final payload = annotation.payload;
    await deletePdfAnnotation(db, row);
    ref.invalidate(pdfAnnotationsProvider(widget.document.id));
    _history().record(
      AnnotationAction(
        undo: (db) => addPdfAnnotation(
          db,
          row.documentId,
          row.pageIndex,
          payload,
        ),
        redo: (db) => deletePdfAnnotation(db, row),
      ),
    );
  }
}

/// The sticky-note tap surface drawn over a single PDF page. The highlight
/// tool no longer draws over the page: highlights are made from pdfrx text
/// selections instead (see [_AnnotatedPdfViewerState._highlightSelection]).
class _ToolOverlay extends StatefulWidget {
  const _ToolOverlay({
    required this.pageRect,
    required this.tool,
    required this.pageAnnotations,
    required this.darkReading,
    required this.onTapPoint,
    required this.onOpenSticky,
    required this.onDeleteSticky,
  });

  final Rect pageRect;
  final AnnotateTool tool;
  final List<AnnotationView> pageAnnotations;
  final bool darkReading;
  final ValueChanged<Offset> onTapPoint;
  final ValueChanged<AnnotationView> onOpenSticky;
  final ValueChanged<AnnotationView> onDeleteSticky;

  @override
  State<_ToolOverlay> createState() => _ToolOverlayState();
}

class _ToolOverlayState extends State<_ToolOverlay> {
  @override
  Widget build(BuildContext context) {
    final interactive = widget.tool == AnnotateTool.sticky;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !interactive,
        // Opaque so the whole page area participates in hit-testing for taps
        // that should create sticky notes.
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerUp: (e) {
            if (widget.tool != AnnotateTool.sticky) return;
            // Sticky is created on tap (pointer-up) only when the tap did not
            // land on an existing sticky icon.
            if (!_hitTestStickyIcon(e.localPosition)) {
              widget.onTapPoint(_normalize(e.localPosition));
            }
          },
          child: Stack(
            children: [
              if (widget.pageAnnotations.isNotEmpty)
                for (final annotation in widget.pageAnnotations)
                  _annotationWidget(annotation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _annotationWidget(AnnotationView annotation) {
    switch (annotation.payload.type) {
      case AnnotationPayloadType.highlight:
        final rects = annotation.payload.rects;
        if (rects.isEmpty) return const SizedBox.shrink();
        return Stack(
          children: [
            for (final rect in rects)
              Positioned.fromRect(
                rect: _pageRectFor(rect),
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _annotationColor(
                              _parseColor(annotation.payload.color))
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        );
      case AnnotationPayloadType.sticky:
        final text = annotation.payload.text;
        final point = annotation.payload.point;
        return Positioned(
          left: point.dx * widget.pageRect.width,
          top: point.dy * widget.pageRect.height,
          child: GestureDetector(
            onTap: () => widget.onOpenSticky(annotation),
            onLongPress: () => widget.onDeleteSticky(annotation),
            // A real sticky note: a translucent square that grows with the
            // text (capped at a readable size) instead of a bare icon.
            child: Container(
              width: _stickyWidth(text),
              constraints: const BoxConstraints(maxHeight: 190),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _annotationColor(_parseColor(annotation.payload.color))
                    .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _annotationColor(_parseColor(annotation.payload.color))
                      .withValues(alpha: 0.85),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                text.isEmpty ? 'Note…' : text,
                maxLines: text.isEmpty ? 1 : 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  color: Color(0xFF3B2F1B),
                ),
              ),
            ),
          ),
        );
    }
  }

  /// When night reading is on the whole viewer is wrapped in an invert
  /// [ColorFiltered]. Overlays drawn inside it would get re-colored too, so
  /// compensate by painting the inverted value — the filter restores the
  /// intended hue.
  Color _annotationColor(Color color) {
    if (!widget.darkReading) return color;
    return Color.fromARGB(
      color.a.toInt().clamp(0, 255),
      255 - color.r.toInt().clamp(0, 255),
      255 - color.g.toInt().clamp(0, 255),
      255 - color.b.toInt().clamp(0, 255),
    );
  }

  Rect _pageRectFor(PdfRectNorm rect) => Rect.fromLTWH(
        rect.left * widget.pageRect.width,
        rect.top * widget.pageRect.height,
        rect.width * widget.pageRect.width,
        rect.height * widget.pageRect.height,
      );

  Offset _normalize(Offset p) => Offset(
        (p.dx / widget.pageRect.width).clamp(0.0, 1.0),
        (p.dy / widget.pageRect.height).clamp(0.0, 1.0),
      );

  bool _hitTestStickyIcon(Offset local) {
    for (final annotation in widget.pageAnnotations) {
      if (annotation.payload.type != AnnotationPayloadType.sticky) continue;
      final point = annotation.payload.point;
      final w = widget.pageRect.width;
      final h = widget.pageRect.height;
      final left = point.dx * w;
      final top = point.dy * h;
      final width = _stickyWidth(annotation.payload.text).clamp(0.0, w);
      final hit = Rect.fromLTWH(left, top, width, 130);
      if (hit.inflate(10).contains(local)) return true;
    }
    return false;
  }
}

Color _parseColor(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0xA3BFA6;
  return Color(0xFF000000 | value);
}

/// Width of a sticky-note tile: grows with the text, capped for readability.
double _stickyWidth(String text) {
  if (text.isEmpty) return 74;
  return (text.length * 5.6 + 46).clamp(74.0, 148.0).toDouble();
}

/// Wraps the menu in an app-owned overlay: a transparent full-window barrier
/// that dismisses the menu on any click outside it, and the menu itself placed
/// around [anchor] — below it when there's room, above it when the anchor is
/// near the bottom, always clamped to stay inside the window.
class _ContextMenuHost extends StatefulWidget {
  const _ContextMenuHost({
    required this.anchor,
    required this.dismiss,
    required this.child,
  });

  final Rect anchor;
  final VoidCallback dismiss;
  final Widget child;

  @override
  State<_ContextMenuHost> createState() => _ContextMenuHostState();
}

class _ContextMenuHostState extends State<_ContextMenuHost> {
  static const double _gap = 6;
  static const double _margin = 8;

  /// Measured size of the menu, used to pick a position that never
  /// overflows the window.
  Size? _menuSize;

  void _onMenuSize(Size size) {
    if (_menuSize == size) return;
    setState(() => _menuSize = size);
  }

  Offset _position(Size viewport, Size menu) {
    final anchor = widget.anchor;
    // Horizontal: align the menu's left edge with the anchor by default,
    // shifting left when the menu would run off the right edge.
    var dx = anchor.left;
    if (dx + menu.width > viewport.width - _margin) {
      dx = anchor.right - menu.width;
    }
    dx = dx.clamp(
      _margin,
      math.max(_margin, viewport.width - menu.width - _margin),
    );

    // Vertical: below the anchor by default; flip above when the anchor is
    // too close to the bottom of the window.
    final below = anchor.bottom + _gap;
    final above = anchor.top - _gap - menu.height;
    double dy;
    if (below + menu.height <= viewport.height - _margin) {
      dy = below;
    } else if (above >= _margin) {
      dy = above;
    } else {
      // No room on either side — keep it fully visible where possible.
      dy = (above < _margin)
          ? math.max(_margin, viewport.height - menu.height - _margin)
          : below;
    }
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.dismiss,
                onSecondaryTap: widget.dismiss,
              ),
            ),
            if (_menuSize == null)
              // First frame: render invisibly just to measure the menu size.
              Opacity(
                opacity: 0,
                child: _SizeReporter(
                  onSize: _onMenuSize,
                  child: widget.child,
                ),
              )
            else
              Positioned(
                left: _position(viewport, _menuSize!).dx,
                top: _position(viewport, _menuSize!).dy,
                child: widget.child,
              ),
          ],
        );
      },
    );
  }
}

/// Reports the laid-out size of [child] via [onSize] after the first frame.
class _SizeReporter extends StatefulWidget {
  const _SizeReporter({required this.child, required this.onSize});

  final Widget child;
  final ValueChanged<Size> onSize;

  @override
  State<_SizeReporter> createState() => _SizeReporterState();
}

class _SizeReporterState extends State<_SizeReporter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  void _report() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is RenderBox) widget.onSize(box.size);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A popup menu with H/S/E/C keyboard shortcuts for a PDF text selection.
class _SelectionMenu extends ConsumerStatefulWidget {
  const _SelectionMenu({
    required this.onHighlight,
    required this.onSummarize,
    required this.onExplain,
    required this.onCopy,
    required this.onDismiss,
  });

  final VoidCallback onHighlight;
  final VoidCallback onSummarize;
  final VoidCallback onExplain;
  final VoidCallback onCopy;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_SelectionMenu> createState() => _SelectionMenuState();
}

class _SelectionMenuState extends ConsumerState<_SelectionMenu> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final c = event.character;
          if (c == 'h' || c == 'H') {
            widget.onHighlight();
            widget.onDismiss();
            return KeyEventResult.handled;
          }
          if (c == 's' || c == 'S') {
            widget.onSummarize();
            widget.onDismiss();
            return KeyEventResult.handled;
          }
          if (c == 'e' || c == 'E') {
            widget.onExplain();
            widget.onDismiss();
            return KeyEventResult.handled;
          }
          if (c == 'c' || c == 'C') {
            widget.onCopy();
            widget.onDismiss();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF2B2620) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _menuItem(Icons.border_color_rounded, 'Highlight', 'H', widget.onHighlight),
              _menuItem(Icons.summarize_rounded, 'Summarize', 'S', widget.onSummarize),
              _menuItem(Icons.chat_rounded, 'Explain', 'E', widget.onExplain),
              _menuItem(Icons.copy_rounded, 'Copy to notebook', 'C', widget.onCopy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, String shortcut, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        onTap();
        widget.onDismiss();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: CoffeeColors.coffee),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: CoffeeColors.caramel.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                shortcut,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback right-click menu shown over non-selected text or the page
/// background: Select All, plus Copy when a selection already exists.
class _PdfContextMenu extends StatelessWidget {
  const _PdfContextMenu({
    required this.onSelectAll,
    required this.onCopy,
    required this.onDismiss,
  });

  final VoidCallback onSelectAll;
  final VoidCallback? onCopy;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: isDark ? const Color(0xFF2B2620) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onCopy != null)
              _item(
                Icons.copy_rounded,
                'Copy',
                () {
                  onCopy!();
                  onDismiss();
                },
              ),
            _item(
              Icons.select_all_rounded,
              'Select All',
              () {
                onSelectAll();
                onDismiss();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: CoffeeColors.coffee),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}