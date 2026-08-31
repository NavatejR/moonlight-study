import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../docs/document_service.dart';
import '../../docs/rag_service.dart';
import '../../shared/widgets/coffee_card.dart';
import '../../shared/widgets/coffee_mug_icon.dart';
import '../reader/reader_screen.dart';
import 'notebook_library.dart';
import 'notebooks_provider.dart';

class NotebooksScreen extends ConsumerWidget {
  const NotebooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebooks = ref.watch(notebooksProvider);
    final busy = ref.watch(_creatingProvider);
    final hasNotebooks = notebooks.value?.isNotEmpty ?? false;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: _NotebookHeader(
                busy: busy,
                showCreateButton: hasNotebooks,
                onCreate: () => _createNotebook(context, ref),
              ),
            ),
          ),
          notebooks.when(
            data: (list) {
              if (list.isEmpty) {
                return SliverToBoxAdapter(
                  child: _EmptyNotebooks(
                    busy: busy,
                    onCreate: () => _createNotebook(context, ref),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) => _NotebookCard(
                    notebook: list[i],
                    onDuplicate: () =>
                        _duplicateNotebook(context, ref, list[i]),
                    onDelete: () => _deleteNotebook(context, ref, list[i]),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load notebooks: $e'),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Future<void> _createNotebook(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<_NotebookDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CreateNotebookSheet(),
    );
    if (created == null || created.name.isEmpty) return;

    ref.read(_creatingProvider.notifier).set(true);
    try {
      final db = ref.read(appDatabaseProvider);
      final rag = ref.read(ragServiceProvider);
      final service = ref.read(documentServiceProvider);
      final notebookId = await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(title: created.name),
          );

      // Create + link document rows first (fast); extract/OCR/chunk aft
      final imports = <({ImportedDocument doc, int docId})>[];
      for (final path in created.pdfPaths) {
        final imported = await service.importDocumentAt(path);
        if (imported == null) continue;
        final docId = await rag.addDocument(imported, subject: created.name);
        await db.into(db.notebookDocuments).insert(
              NotebookDocumentsCompanion.insert(
                notebookId: notebookId,
                documentId: docId,
              ),
            );
        imports.add((doc: imported, docId: docId));
      }

      ref.invalidate(notebooksProvider);
      ref.invalidate(notebookDocumentsProvider(notebookId));

      if (imports.isNotEmpty && context.mounted) {
        await _indexImports(context, rag, imports);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              imports.isEmpty
                  ? '"${created.name}" created (no PDFs added).'
                  : 'Added ${imports.length} PDF${imports.length == 1 ? '' : 's'} to "${created.name}".',
            ),
          ),
        );
      }
      if (imports.isNotEmpty && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReaderScreen(notebookId: notebookId),
          ),
        );
      }
    } finally {
      ref.read(_creatingProvider.notifier).set(false);
    }
  }

  /// Indexes each new document (OCR + chunking) behind a progress dialog.
  /// OCR of scanned PDFs is slow, so the dialog can be minimized to the
  /// background; indexing keeps running.
  Future<void> _indexImports(
    BuildContext context,
    RagService rag,
    List<({ImportedDocument doc, int docId})> imports,
  ) async {
    final status = ValueNotifier<String>('');
    var minimized = false;
    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _IndexingDialog(
          status: status,
          onMinimize: () {
            minimized = true;
            Navigator.of(dialogContext).pop();
          },
        ),
      );
    }
    for (final entry in imports) {
      status.value = 'Indexing ${entry.doc.name}…';
      await rag.indexDocumentContent(
        entry.docId,
        entry.doc,
        onOcrProgress: (page, total) {
          status.value = 'OCR ${entry.doc.name} — page $page/$total…';
        },
      );
    }
    if (context.mounted && !minimized) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    status.dispose();
  }

  Future<void> _duplicateNotebook(
    BuildContext context,
    WidgetRef ref,
    NotebookView notebook,
  ) async {
    final db = ref.read(appDatabaseProvider);
    final newId = await duplicateNotebook(db, notebook.id);
    ref.invalidate(notebooksProvider);
    ref.invalidate(notebookDocumentsProvider(notebook.id));
    ref.invalidate(notebookDocumentsProvider(newId));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Duplicated "${notebook.title}".')),
        );
    }
  }

  Future<void> _deleteNotebook(
    BuildContext context,
    WidgetRef ref,
    NotebookView notebook,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete notebook?'),
        content: Text(
          'Delete "${notebook.title}"? Its notes go with it; '
          'PDFs still used by other notebooks stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = ref.read(appDatabaseProvider);
    await deleteNotebook(db, notebook.id);
    ref.invalidate(notebooksProvider);
    ref.invalidate(notebookDocumentsProvider(notebook.id));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('"${notebook.title}" deleted.')),
        );
    }
  }
}

class _NotebookHeader extends StatelessWidget {
  const _NotebookHeader({
    required this.busy,
    required this.showCreateButton,
    required this.onCreate,
  });

  final bool busy;
  final bool showCreateButton;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notebooks',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Textbooks with a PDF reader, annotations, and an AI notebook.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (showCreateButton)
          FilledButton.icon(
            onPressed: busy ? null : onCreate,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded, size: 18),
            label: Text(busy ? 'Adding…' : 'Add notebook'),
          ),
      ],
    );
  }
}

class _NotebookCard extends StatelessWidget {
  const _NotebookCard({
    required this.notebook,
    required this.onDuplicate,
    required this.onDelete,
  });

  final NotebookView notebook;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final count = notebook.documents.length;
    return CoffeeCard(
      padding: const EdgeInsets.all(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReaderScreen(notebookId: notebook.id),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: CoffeeGradients.espressoDusk,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notebook.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0
                        ? 'No PDFs yet'
                        : '$count PDF${count == 1 ? '' : 's'} · tap to read',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_NotebookAction>(
              tooltip: 'Notebook options',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) {
                switch (action) {
                  case _NotebookAction.duplicate:
                    onDuplicate();
                  case _NotebookAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _NotebookAction.duplicate,
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18, color: CoffeeColors.cacao),
                      SizedBox(width: 10),
                      Text('Duplicate'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _NotebookAction.delete,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Color(0xFFC0514C),
                      ),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _NotebookAction { duplicate, delete }

class _EmptyNotebooks extends StatelessWidget {
  const _EmptyNotebooks({required this.busy, required this.onCreate});

  final bool busy;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: CoffeeCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CoffeeMugIcon(size: 56),
            const SizedBox(height: 16),
            const Text(
              'No notebooks yet',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a notebook for a textbook or chapter,\nadd its PDFs, then read + annotate + ask AI.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : onCreate,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(busy ? 'Adding…' : 'Add notebook'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A draft created by the Add-notebook sheet.
class _NotebookDraft {
  const _NotebookDraft({required this.name, required this.pdfPaths});
  final String name;
  final List<String> pdfPaths;
}

class _CreateNotebookSheet extends ConsumerStatefulWidget {
  const _CreateNotebookSheet();

  @override
  ConsumerState<_CreateNotebookSheet> createState() =>
      _CreateNotebookSheetState();
}

class _CreateNotebookSheetState extends ConsumerState<_CreateNotebookSheet> {
  final _nameController = TextEditingController();
  final _paths = <String>[];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      for (final file in result.files) {
        if (file.path != null &&
            !_paths.contains(file.path) &&
            file.path!.toLowerCase().endsWith('.pdf')) {
          _paths.add(file.path!);
        }
      }
    });
  }

  Future<void> _pickFolder() async {
    final folder = await FilePicker.platform.getDirectoryPath();
    if (folder == null) return;
    final pdfs = await ref
        .read(documentServiceProvider)
        .scanFolderForPdfs(folder);
    setState(() {
      for (final path in pdfs) {
        if (!_paths.contains(path)) _paths.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New notebook', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Name it, then add chapter or textbook PDFs.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name / Subject',
              hintText: 'e.g. Organic Chemistry · Chapter 4',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.insert_drive_file_rounded, size: 18),
                label: const Text('Add PDFs'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _pickFolder,
                icon: const Icon(Icons.folder_rounded, size: 18),
                label: const Text('Add folder'),
              ),
            ],
          ),
          if (_paths.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _paths.length,
                itemBuilder: (context, i) {
                  final path = _paths[i];
                  final name = Uri.file(path).pathSegments.last;
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 18,
                      color: CoffeeColors.caramel,
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => setState(() => _paths.removeAt(i)),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                context,
                _NotebookDraft(
                  name: _nameController.text.trim(),
                  pdfPaths: List.of(_paths),
                ),
              );
            },
            child: Text(
              _paths.isEmpty ? 'Create notebook' : 'Create with ${_paths.length} PDFs',
            ),
          ),
        ],
      ),
    );
  }
}

final _creatingProvider =
    NotifierProvider<_CreatingNotifier, bool>(_CreatingNotifier.new);

class _CreatingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Progress dialog shown while new PDFs are extracted/OCR'd and chunked.
/// OCR of scanned PDFs is slow, so a "Background" action lets indexing run on
/// without blocking the UI.
class _IndexingDialog extends StatelessWidget {
  const _IndexingDialog({required this.status, required this.onMinimize});

  final ValueNotifier<String> status;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: const Text(
        'Indexing PDFs',
        style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 360,
        child: ValueListenableBuilder<String>(
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
                  value.isEmpty ? 'Preparing…' : value,
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: onMinimize,
          child: const Text('Run in background'),
        ),
      ],
    );
  }
}