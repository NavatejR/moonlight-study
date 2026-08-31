import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';

/// Adds a note block to a notebook.
Future<Note> createNote(
  AppDatabase db,
  int notebookId,
  String content, {
  int? documentId,
}) async {
  final id = await db.into(db.notes).insert(
        NotesCompanion.insert(
          notebookId: notebookId,
          documentId: Value(documentId),
          content: content,
        ),
      );
  final created =
      await (db.select(db.notes)..where((t) => t.id.equals(id))).getSingle();
  return created;
}

/// Updates a note block's content.
Future<void> updateNote(AppDatabase db, int noteId, String content) async {
  await (db.update(db.notes)..where((t) => t.id.equals(noteId)))
      .write(NotesCompanion(content: Value(content)));
}

/// Deletes a note block.
Future<void> deleteNote(AppDatabase db, int noteId) async {
  await (db.delete(db.notes)..where((t) => t.id.equals(noteId))).go();
}

/// All note blocks for a notebook, scoped to one document. When [documentId]
/// is null, only notes not attached to a specific PDF are included.
final documentNotesProvider = StreamProvider.autoDispose
    .family<List<Note>, ({int notebookId, int? documentId})>(
        (ref, key) async* {
  final db = ref.watch(appDatabaseProvider);
  yield* (db.select(db.notes)
        ..where((t) =>
            t.notebookId.equals(key.notebookId) &
            (key.documentId == null
                ? t.documentId.isNull()
                : t.documentId.equals(key.documentId!)))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .watch();
});

/// Total number of note blocks across all notebooks (dashboard stat).
final notesCountProvider = StreamProvider<int>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  yield* db.select(db.notes).watch().map((rows) => rows.length);
});

/// A recently-updated note (for the dashboard "Continue studying" list).
class RecentNote {
  const RecentNote({
    required this.note,
    required this.notebookId,
    required this.notebookTitle,
  });

  final Note note;
  final int notebookId;
  final String notebookTitle;
}

/// The most recently updated notes across notebooks.
final recentNotesProvider = StreamProvider<List<RecentNote>>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.notes).join([
    innerJoin(
      db.notebooks,
      db.notebooks.id.equalsExp(db.notes.notebookId),
    ),
  ])
    ..orderBy([OrderingTerm.desc(db.notes.updatedAt)])
    ..limit(5);
  final rows = await query.get();
  yield [
    for (final row in rows)
      RecentNote(
        note: row.readTable(db.notes),
        notebookId: row.readTable(db.notebooks).id,
        notebookTitle: row.readTable(db.notebooks).title,
      ),
  ];
});