import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../../core/ai/ai_engine.dart';
import '../../core/db/app_database.dart';
import '../../core/music/player_controller.dart';
import '../../core/settings/settings_storage.dart';
import '../../core/theme/colors.dart';
import '../../docs/rag_service.dart';
import '../../study/pomodoro.dart';
import '../notebooks/notebooks_provider.dart';
import 'assistant_pane.dart';
import 'notes_library.dart';
import 'pdf_pane.dart';
import 'reading_context.dart';

/// Tiled reader: PDF on the left, notebook notes on the right, separated by a
/// draggable divider whose ratio comes from Settings.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.notebookId});

  final int notebookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with SingleTickerProviderStateMixin {
  AnnotateTool _tool = AnnotateTool.none;
  int _selectedDocumentId = -1;
  late final TabController _tabController;
  final pdfrx.PdfViewerController _pdfController = pdfrx.PdfViewerController();
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(1);
  bool _pagesPanelOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _restoreLastDocument();
  }

  /// Reopens the notebook on the PDF that was open last time, so the AI
  /// assistant keeps grounding on the document the user was actually reading.
  Future<void> _restoreLastDocument() async {
    final storage = ref.read(settingsStorageProvider);
    final saved = await storage.getPref('lastOpenDoc:${widget.notebookId}');
    final id = int.tryParse(saved ?? '');
    if (id != null && mounted) setState(() => _selectedDocumentId = id);
  }

  Future<void> _rememberDocument(int id) async {
    final storage = ref.read(settingsStorageProvider);
    await storage.setPref('lastOpenDoc:${widget.notebookId}', '$id');
  }

  @override
  void dispose() {
    ref.read(readingContextProvider.notifier).clear();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(notebookDocumentsProvider(widget.notebookId));
    final notebooks = ref.watch(notebooksProvider).value ?? const <NotebookView>[];
    NotebookView? notebook;
    for (final n in notebooks) {
      if (n.id == widget.notebookId) {
        notebook = n;
        break;
      }
    }

    final doc = _displayedDoc(docs.value ?? const []);

    // Keep the Study Chat (and anything else) aware of the document the user
    // is currently reading.
    ref.listen(notebookDocumentsProvider(widget.notebookId), (_, next) {
      final list = next.value;
      if (list == null || list.isEmpty) return;
      final current = _displayedDoc(list);
      if (current == null) return;
      ref.read(readingContextProvider.notifier).open(current.id, current.name);
    });

    final pomodoro = ref.watch(pomodoroProvider);
    final nowPlaying = ref.watch(nowPlayingProvider).value;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Flexible(
              child: Text(
                notebook?.title ?? 'Notebook',
                style: const TextStyle(fontFamily: 'Fraunces', fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (pomodoro.isActive)
            _PomodoroPill(
              label: '${pomodoro.phaseLabel} · ${pomodoro.label}',
              fraction: pomodoro.fraction,
              isRunning: pomodoro.running,
              onTap: () => ref.read(pomodoroProvider.notifier).toggle(),
            ),
          if (nowPlaying != null && nowPlaying.hasTrack) ...[
            const SizedBox(width: 10),
            _NowPlayingPill(
              title: _trackTitle(nowPlaying.currentPath!),
              isPlaying: nowPlaying.isPlaying,
              onToggle: () => ref.read(musicPlayerProvider).toggle(),
              onPrevious: () => ref.read(musicPlayerProvider).previous(),
              onNext: () => ref.read(musicPlayerProvider).next(),
            ),
          ],
          IconButton(
            onPressed: () => _reindexCurrent(),
            tooltip: 'Re-index (extract / OCR) this PDF',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
          const SizedBox(width: 8),
        ],
        bottom: docs.value?.isEmpty == false && doc != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: _DocSwitcher(
                  docs: docs.value!,
                  selectedId: doc.id,
                  onSelect: (id) {
                    setState(() {
                      _selectedDocumentId = id;
                      _tool = AnnotateTool.none;
                    });
                    for (final d in docs.value ?? const <Document>[]) {
                      if (d.id == id) {
                        ref
                            .read(readingContextProvider.notifier)
                            .open(id, d.name);
                        break;
                      }
                    }
                    _rememberDocument(id);
                  },
                ),
              )
            : null,
      ),
      body: docs.when(
        data: (value) {
          if (value.isEmpty) {
            return const _ReaderEmpty();
          }
          if (doc == null) {
            return const _ReaderEmpty();
          }
          return _TiledLayout(
            document: doc,
            tool: _tool,
            notebookId: widget.notebookId,
            tabController: _tabController,
            pdfController: _pdfController,
            currentPage: _currentPage,
            pagesPanelOpen: _pagesPanelOpen,
            onPagesPanelToggle: () =>
                setState(() => _pagesPanelOpen = !_pagesPanelOpen),
            onToolChanged: (t) => setState(() => _tool = t),
            onSelectionAction: _handleSelection,
            onPageChanged: (page) => _currentPage.value = page,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  /// Resolves which document the reader is showing without mutating state.
  Document? _displayedDoc(List<Document> docs) {
    if (docs.isEmpty) return null;
    final id = (_selectedDocumentId == -1 ||
            !docs.any((d) => d.id == _selectedDocumentId))
        ? docs.first.id
        : _selectedDocumentId;
    for (final d in docs) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// The id of the document currently shown, or null when nothing is open.
  /// Used by selection actions so notes/assistant always bind to the doc the
  /// user is actually looking at (never a stale/removed id).
  int? get _currentDocumentId => _displayedDoc(
        ref.read(notebookDocumentsProvider(widget.notebookId)).value ??
            const [],
      )?.id;

  /// Re-extracts text (running OCR on scanned pages) and rebuilds chunks for
  /// the currently-open PDF. Slow for scanned documents, so it runs behind a
  /// minimal progress dialog that can be minimized to the background.
  Future<void> _reindexCurrent() async {
    final docs =
        ref.read(notebookDocumentsProvider(widget.notebookId)).value;
    if (docs == null || docs.isEmpty) return;
    final doc = _displayedDoc(docs);
    if (doc == null) return;

    final status = ValueNotifier<String>('Extracting text…');
    var minimized = false;
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text(
            'Re-indexing',
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w600,
            ),
          ),
          content: ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (context, value, _) => Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                minimized = true;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Run in background'),
            ),
          ],
        ),
      );
    }

    final rag = ref.read(ragServiceProvider);
    await rag.reindexDocument(
      doc.id,
      onOcrProgress: (page, total) {
        status.value = 'OCR "${doc.name}" — page $page/$total…';
      },
    );

    if (mounted && !minimized) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    status.dispose();
    if (mounted) _toast('Re-indexed "${doc.name}".');
  }

  Future<void> _handleSelection(SelectionRequest request, String action) async {
    switch (action) {
      case 'copy':
        final db = ref.read(appDatabaseProvider);
        await createNote(
          db,
          widget.notebookId,
          request.text,
          documentId: _currentDocumentId,
        );
        _toast('Copied selection to notes.');
        return;
      case 'summarize':
      case 'explain':
        if (!ref.read(aiEnabledProvider)) {
          _toast('AI is off — enable it in Models first.');
          return;
        }
        // Hand the selection to the AI assistant tab as a user query; the
        // assistant streams the answer there instead of blocking here.
        final label = action == 'summarize' ? 'Summarize this' : 'Explain this';
        ref
            .read(readerAssistantProvider(widget.notebookId).notifier)
            .ask(
              '$label: ${request.text}',
              documentId: _currentDocumentId,
            );
        if (mounted) {
          _tabController.animateTo(1);
          _toast('Sent to the AI assistant.');
        }
        return;
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DocSwitcher extends StatelessWidget {
  const _DocSwitcher({
    required this.docs,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Document> docs;
  final int selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final doc = docs[i];
          final selected = doc.id == selectedId;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ChoiceChip(
              label: Text(
                doc.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              selected: selected,
              selectedColor: CoffeeColors.caramel.withValues(alpha: 0.25),
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onSelect(doc.id),
            ),
          );
        },
      ),
    );
  }
}

class _ReaderEmpty extends StatelessWidget {
  const _ReaderEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_rounded, size: 44, color: CoffeeColors.cacao),
          const SizedBox(height: 12),
          Text(
            'No PDFs in this notebook yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Add a textbook PDF when creating the notebook.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TiledLayout extends ConsumerWidget {
  const _TiledLayout({
    required this.document,
    required this.tool,
    required this.notebookId,
    required this.tabController,
    required this.pdfController,
    required this.currentPage,
    required this.pagesPanelOpen,
    required this.onPagesPanelToggle,
    required this.onToolChanged,
    required this.onSelectionAction,
    required this.onPageChanged,
  });

  final Document document;
  final AnnotateTool tool;
  final int notebookId;
  final TabController tabController;
  final pdfrx.PdfViewerController pdfController;
  final ValueNotifier<int> currentPage;
  final bool pagesPanelOpen;
  final VoidCallback onPagesPanelToggle;
  final ValueChanged<AnnotateTool> onToolChanged;
  final void Function(SelectionRequest request, String action) onSelectionAction;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratio = ref.watch(settingsProvider).value?.splitRatio ?? 0.55;
    return _DraggableSplit(
      ratio: ratio,
      left: PdfPane(
        document: document,
        tool: tool,
        controller: pdfController,
        currentPage: currentPage,
        pagesPanelOpen: pagesPanelOpen,
        onPagesPanelToggle: onPagesPanelToggle,
        onToolChanged: onToolChanged,
        onSelectionAction: onSelectionAction,
        onPageChanged: onPageChanged,
      ),
      right: ReaderRightPanel(
        notebookId: notebookId,
        documentId: document.id,
        tabController: tabController,
      ),
    );
  }
}

/// A simple two-pane draggable split with a ratio from settings.
class _DraggableSplit extends StatefulWidget {
  const _DraggableSplit({
    required this.ratio,
    required this.left,
    required this.right,
  });

  final double ratio;
  final Widget left;
  final Widget right;

  @override
  State<_DraggableSplit> createState() => _DraggableSplitState();
}

class _DraggableSplitState extends State<_DraggableSplit> {
  late double _ratio;

  @override
  void initState() {
    super.initState();
    _ratio = widget.ratio;
  }

  @override
  void didUpdateWidget(_DraggableSplit old) {
    super.didUpdateWidget(old);
    if (old.ratio != widget.ratio) _ratio = widget.ratio;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final leftWidth = width * _ratio;
        const divider = 8.0;
        return Row(
          children: [
            SizedBox(width: leftWidth, child: widget.left),
            MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _ratio = ((leftWidth + details.delta.dx) / width)
                        .clamp(0.25, 0.75);
                  });
                },
                child: Container(
                  width: divider,
                  color: Theme.of(context).colorScheme.outlineVariant,
                  child: const Icon(
                    Icons.drag_handle_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: width - leftWidth - divider,
              child: widget.right,
            ),
          ],
        );
      },
    );
  }
}

String _trackTitle(String path) {
  final title = p.basenameWithoutExtension(path);
  return title.length > 26 ? '${title.substring(0, 26)}…' : title;
}

/// Compact pomodoro progress pill shown in the reader app bar while the timer
/// runs. Tapping pauses the session.
class _PomodoroPill extends StatelessWidget {
  const _PomodoroPill({
    required this.label,
    required this.fraction,
    required this.isRunning,
    required this.onTap,
  });

  final String label;
  final double fraction;
  final bool isRunning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isRunning ? 'Pomodoro: tap to pause' : 'Pomodoro: tap to resume',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: CoffeeColors.caramel.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Color(0x33B07A3C)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: fraction,
                      strokeWidth: 2,
                      color: CoffeeColors.caramel,
                      backgroundColor: CoffeeColors.caramel.withValues(alpha: 0.15),
                    ),
                    Icon(
                      isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 10,
                      color: CoffeeColors.caramel,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Now-playing pill with inline media controls, shown while a track plays.
class _NowPlayingPill extends StatelessWidget {
  const _NowPlayingPill({
    required this.title,
    required this.isPlaying,
    required this.onToggle,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final bool isPlaying;
  final VoidCallback onToggle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 2, 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.music_note_rounded,
            size: 16,
            color: CoffeeColors.caramel,
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 2),
          _mediaButton(
            Icons.skip_previous_rounded,
            'Previous',
            onPrevious,
            scheme,
          ),
          _mediaButton(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            isPlaying ? 'Pause' : 'Play',
            onToggle,
            scheme,
            prominent: true,
          ),
          _mediaButton(
            Icons.skip_next_rounded,
            'Next',
            onNext,
            scheme,
          ),
        ],
      ),
    );
  }

  Widget _mediaButton(IconData icon, String tooltip, VoidCallback onTap,
      ColorScheme scheme,
      {bool prominent = false}) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      padding: const EdgeInsets.all(5),
      constraints: const BoxConstraints(),
      icon: Icon(
        icon,
        color: prominent
            ? CoffeeColors.espresso
            : scheme.onSurfaceVariant,
      ),
      style: prominent
          ? IconButton.styleFrom(
              backgroundColor: CoffeeColors.caramel,
            )
          : null,
    );
  }
}