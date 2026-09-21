import 'package:study_companion/core/db/app_database.dart';
import 'package:study_companion/docs/document_service.dart';
import 'package:study_companion/docs/ocr_service.dart';
import 'package:study_companion/docs/rag_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_db.dart';

/// Exposes the container's own [Ref] so services that need a Riverpod ref can
/// be constructed directly in tests.
final _refProvider = Provider<Ref>((ref) => ref);

Future<int> _insertDoc(RagServiceTestEnv env, String name) {
  return env.db.into(env.db.documents).insert(
        DocumentsCompanion.insert(
          name: name,
          kind: 'pdf',
          filePath: '/tmp/$name',
          pageCount: const Value(1),
        ),
      );
}

Future<void> _insertChunk(AppDatabase db, int docId, String content) {
  return db.into(db.chunks).insert(
        ChunksCompanion.insert(
          documentId: docId,
          content: content,
        ),
      );
}

class RagServiceTestEnv {
  RagServiceTestEnv(this.db, this.rag);
  final AppDatabase db;
  final RagService rag;
}

void main() {
  late RagServiceTestEnv env;

  setUp(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final db = await openInMemoryDb();
    addTearDown(db.close);

    final ref = container.read(_refProvider);
    // Default active model (qwen v2.5-vl) has no `embeddings` capability, so
    // retrieval exercises the keyword-scoring fallback without any AI engine.
    final rag = RagService(db, DocumentService(), OcrService(ref), ref);
    env = RagServiceTestEnv(db, rag);
  });

  group('RagService.retrieve', () {
    test('returns empty list for an empty database', () async {
      final hits = await env.rag.retrieve('anything', k: 4);
      expect(hits, isEmpty);
    });

    test('keyword scoring ranks matching chunks first', () async {
      final docId = await _insertDoc(env, 'Biology.pdf');
      await _insertChunk(
        env.db,
        docId,
        'Football matches happen every weekend across various leagues.',
      );
      await _insertChunk(
        env.db,
        docId,
        'The mitochondria is the powerhouse of the cell, where chemical '
            'energy is produced for cellular respiration.',
      );

      final hits = await env.rag.retrieve('mitochondria energy cell', k: 2);
      expect(hits, hasLength(2));
      expect(hits.first.text, contains('mitochondria'));
      expect(hits.first.score, 1.0);
      expect(hits.first.documentId, docId);
      expect(hits.first.documentName, 'Biology.pdf');
    });

    test('documentIds scopes retrieval', () async {
      final docA = await _insertDoc(env, 'Alpha.pdf');
      final docB = await _insertDoc(env, 'Beta.pdf');
      await _insertChunk(env.db, docA, 'Quantum dots are special minerals.');
      await _insertChunk(env.db, docB, 'Quantum dots here should be hidden.');

      final hits =
          await env.rag.retrieve('quantum dots', k: 4, documentIds: {docA});
      expect(hits, isNotEmpty);
      for (final h in hits) {
        expect(h.documentId, docA);
      }
    });

    test('stops at k results', () async {
      final docId = await _insertDoc(env, 'Many.pdf');
      for (var i = 0; i < 10; i++) {
        await _insertChunk(env.db, docId, 'shared token content number $i');
      }
      final hits = await env.rag.retrieve('shared token', k: 3);
      expect(hits, hasLength(3));
    });

    test('terms shorter than 3 chars are ignored', () async {
      final docId = await _insertDoc(env, 'Short.pdf');
      await _insertChunk(env.db, docId, 'go near oak hill top');
      final hits = await env.rag.retrieve('go near oak', k: 4);
      // 'go' is dropped; remaining terms still match.
      expect(hits, isNotEmpty);
      expect(hits.first.score, greaterThan(0));
    });
  });
}