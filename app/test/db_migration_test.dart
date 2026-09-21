import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_companion/core/db/app_database.dart';

void main() {
  group('database migration v4 → v5', () {
    test('creates the document indexes against a pre-index schema', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // A fresh install creates the schema at v5 (indexes included). Drop the
      // indexes to reproduce the shape of a real v4 database, then run the
      // exact statements the 4→5 migration uses (the generated Index objects).
      await db.customStatement('DROP INDEX idx_chunks_document');
      await db.customStatement('DROP INDEX idx_notebook_documents_document');

      final migrator = Migrator(db);
      await migrator.createIndex(db.idxChunksDocument);
      await migrator.createIndex(db.idxNotebookDocumentsDocument);

      final indices = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'",
      ).get();
      final names = indices.map((r) => r.data['name']).toList();
      expect(
        names,
        containsAll(['idx_chunks_document', 'idx_notebook_documents_document']),
      );

      await db.close();
    });

    test('index DDL targets the real snake_case columns', () {
      expect(dbIdxDdl('chunks'), contains('document_id'));
      expect(dbIdxDdl('notebook_documents'), contains('document_id'));
    });
  });
}

/// Extracts the CREATE INDEX statement for [indexName] from the generated
/// schema. Guards against drift schema definitions silently referencing the
/// wrong column (the source of the v4→v5 regression).
String dbIdxDdl(String indexName) {
  final db = AppDatabase(NativeDatabase.memory());
  final index = indexName == 'chunks'
      ? db.idxChunksDocument
      : db.idxNotebookDocumentsDocument;
  db.close();
  return index.createStatementsByDialect.values.single;
}