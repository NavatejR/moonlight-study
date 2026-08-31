import 'package:drift/drift.dart' hide Column;

import '../../core/db/app_database.dart';

/// Removes a notebook and cleans up everything that becomes orphaned:
/// its notes, its document links, and — for PDFs no longer referenced by any
/// other notebook — their annotations, chunks and document rows. Source files
/// on disk are never touched.
Future<void> deleteNotebook(AppDatabase db, int notebookId) async {
  await db.transaction(() async {
    await (db.delete(db.notes)
          ..where((t) => t.notebookId.equals(notebookId)))
        .go();

    final links = await (db.select(db.notebookDocuments)
          ..where((t) => t.notebookId.equals(notebookId)))
        .get();
    final docIds = links.map((l) => l.documentId).toSet();
    await (db.delete(db.notebookDocuments)
          ..where((t) => t.notebookId.equals(notebookId)))
        .go();

    for (final docId in docIds) {
      final stillUsed = await (db.select(db.notebookDocuments)
            ..where((t) => t.documentId.equals(docId)))
          .get();
      if (stillUsed.isNotEmpty) continue;
      await (db.delete(db.pdfAnnotations)
            ..where((t) => t.documentId.equals(docId)))
          .go();
      await (db.delete(db.chunks)..where((t) => t.documentId.equals(docId)))
          .go();
      await (db.delete(db.documents)..where((t) => t.id.equals(docId))).go();
    }

    await (db.delete(db.notebooks)..where((t) => t.id.equals(notebookId))).go();
  });
}

/// Copies a notebook: creates a new notebook titled "… (copy)", re-links the
/// same PDFs and duplicates its notes. Returns the id of the new notebook.
Future<int> duplicateNotebook(AppDatabase db, int notebookId) async {
  final newId = await db.transaction(() async {
    final original =
        await (db.select(db.notebooks)..where((t) => t.id.equals(notebookId)))
            .getSingle();

    final newId = await db.into(db.notebooks).insert(
          NotebooksCompanion.insert(title: '${original.title} (copy)'),
        );

    final links = await (db.select(db.notebookDocuments)
          ..where((t) => t.notebookId.equals(notebookId)))
        .get();
    for (final link in links) {
      await db.into(db.notebookDocuments).insert(
            NotebookDocumentsCompanion.insert(
              notebookId: newId,
              documentId: link.documentId,
            ),
          );
    }

    final notes = await (db.select(db.notes)
          ..where((t) => t.notebookId.equals(notebookId)))
        .get();
    for (final note in notes) {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              notebookId: newId,
              documentId: Value(note.documentId),
              content: note.content,
              createdAt: Value(note.createdAt),
            ),
          );
    }
    return newId;
  });
  return newId;
}