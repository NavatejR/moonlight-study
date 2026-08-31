import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/colors.dart';
import '../notebooks/notebooks_provider.dart';
import 'notes_library.dart';

/// The Notes tab: a point-style list of notes for the PDF currently open in
/// the reader. Each PDF keeps its own set of notes (scoped by [documentId]);
/// pressing the + button appends a new bullet note that autosaves as you type.
class NotesPane extends ConsumerStatefulWidget {
  const NotesPane({super.key, required this.notebookId, this.documentId});

  final int notebookId;
  final int? documentId;

  @override
  ConsumerState<NotesPane> createState() => _NotesPaneState();
}

class _NotesPaneState extends ConsumerState<NotesPane> {
  /// Id of the note just created with +, so its field gets focus.
  int? _focusId;

  Future<void> _addNote() async {
    if (widget.documentId == null) return;
    final db = ref.read(appDatabaseProvider);
    final created =
        await createNote(db, widget.notebookId, '', documentId: widget.documentId);
    if (mounted) setState(() => _focusId = created.id);
  }

  String _openDocumentName(List<Document> docs) {
    for (final doc in docs) {
      if (doc.id == widget.documentId) return doc.name;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(documentNotesProvider(
      (notebookId: widget.notebookId, documentId: widget.documentId),
    ));
    final docs =
        ref.watch(notebookDocumentsProvider(widget.notebookId)).value ?? const [];
    final scheme = Theme.of(context).colorScheme;
    final docName = _openDocumentName(docs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Stack(
            children: [
              Padding(
                // Reserve room so a long doc name never runs under the button.
                padding: const EdgeInsets.only(right: 96),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (widget.documentId != null && docName.isNotEmpty)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            docName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: widget.documentId == null ? null : _addNote,
                      style: TextButton.styleFrom(
                        foregroundColor: CoffeeColors.moss,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add note',
                          style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0x22925C4E)),
        Expanded(
          child: notes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) {
              if (widget.documentId == null) {
                return const _HintPane('Open a PDF to attach notes to it.');
              }
              if (items.isEmpty) {
                return const _EmptyWriteBox();
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final note = items[i];
                  return _NoteItem(
                    key: ValueKey(note.id),
                    note: note,
                    autofocus: note.id == _focusId,
                    onChanged: (text) async {
                      final db = ref.read(appDatabaseProvider);
                      await updateNote(db, note.id, text);
                    },
                    onDelete: () async {
                      final db = ref.read(appDatabaseProvider);
                      await deleteNote(db, note.id);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One bullet-style note row: a dot, an auto-growing text field and a delete
/// button. Saves (debounced) as the user types.
class _NoteItem extends StatefulWidget {
  const _NoteItem({
    super.key,
    required this.note,
    required this.onChanged,
    required this.onDelete,
    this.autofocus = false,
  });

  final Note note;
  final Future<void> Function(String text) onChanged;
  final Future<void> Function() onDelete;
  final bool autofocus;

  @override
  State<_NoteItem> createState() => _NoteItemState();
}

class _NoteItemState extends State<_NoteItem> {
  late final TextEditingController _controller;
  Timer? _debounce;
  String _lastSaved = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note.content);
    _lastSaved = widget.note.content;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || value == _lastSaved) return;
      _lastSaved = value;
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 10),
              decoration: const BoxDecoration(
                color: CoffeeColors.caramel,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              minLines: 1,
              textAlignVertical: TextAlignVertical.top,
              onChanged: _onChanged,
              style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface),
              cursorColor: CoffeeColors.caramel,
              decoration: InputDecoration(
                hintText: 'Write a point…',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                // Don't inherit the theme's filled (radius-20) decoration —
                // that paints the pill. The textbox is the row's radius-10
                // rounded-rectangle box instead.
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              ),
            ),
          ),
          IconButton(
            onPressed: () => widget.onDelete(),
            tooltip: 'Delete note',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered empty-state message. Adding notes happens via the + button in the
/// header (top-right corner of the Notes tab).
class _HintPane extends StatelessWidget {
  const _HintPane(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notes_rounded, size: 40, color: CoffeeColors.cacao),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed rounded "write here" box shown before the first note exists, so the
/// Notes tab always has a visible (rounded-rectangle) textbox. Adding happens
/// via the labeled "Add note" button in the top-right header.
class _EmptyWriteBox extends StatelessWidget {
  const _EmptyWriteBox();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.9),
            width: 1.2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 28,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'No notes for this PDF yet — tap "Add note" above to write your '
              'first point.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}