import 'package:drift/drift.dart' hide Column;

import '../core/db/app_database.dart';
import 'rag_service.dart';

/// Startup repair for data created before the duplicate-document bug was
/// fixed and for documents that never got indexed:
///
/// 1. De-dupes `Documents` rows that share a `filePath` (the old indexing code
///    inserted a second row per PDF), keeping the one linked to a notebook and
///    dropping the orphans' chunks/annotations.
/// 2. Re-indexes any document that has no chunks yet (applying OCR when the
///    embedded text is missing).
///
/// Non-fatal; anything that fails is simply left for the manual Re-index
/// action. Run once at startup.
Future<void> repairLibrary(AppDatabase db, RagService rag) async {
  final linkedIds = <int>{};
  for (final link in await db.select(db.notebookDocuments).get()) {
    linkedIds.add(link.documentId);
  }

  final allDocs =
      await (db.select(db.documents)..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();
  final byPath = <String, List<Document>>{};
  for (final doc in allDocs) {
    byPath.putIfAbsent(doc.filePath, () => []).add(doc);
  }

  // 1. Remove duplicate rows for the same file.
  for (final group in byPath.values) {
    if (group.length < 2) continue;
    Document keep = group.first;
    for (final doc in group) {
      if (linkedIds.contains(doc.id)) {
        keep = doc;
        break;
      }
    }
    for (final doc in group) {
      if (doc.id == keep.id) continue;
      await (db.delete(db.chunks)..where((t) => t.documentId.equals(doc.id)))
          .go();
      await (db.delete(db.pdfAnnotations)
            ..where((t) => t.documentId.equals(doc.id)))
          .go();
      await (db.delete(db.documents)..where((t) => t.id.equals(doc.id))).go();
    }
  }

  // 2. Re-index documents that have no chunks.
  for (final doc in await db.select(db.documents).get()) {
    final existing = await (db.select(db.chunks)
          ..where((t) => t.documentId.equals(doc.id))
          ..limit(1))
        .get();
    if (existing.isNotEmpty) continue;
    if (doc.kind != 'pdf' && doc.kind != 'text') continue;
    await rag.reindexDocument(doc.id);
  }
}