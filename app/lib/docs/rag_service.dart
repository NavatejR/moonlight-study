import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ai/ai_engine.dart';
import '../core/db/app_database.dart';
import '../core/logging/app_logger.dart';
import '../docs/document_service.dart';
import '../docs/ocr_service.dart';

/// A retrieved source chunk with its similarity score.
class RetrievedChunk {
  const RetrievedChunk({
    required this.text,
    required this.documentId,
    required this.documentName,
    required this.score,
    this.pageIndex = 0,
  });

  final String text;
  final int documentId;
  final String documentName;
  final double score;
  final int pageIndex;
}

/// Grounds answers by semantic search over the user's documents.
///
/// Uses the lightweight embedding model when available; falls back to
/// keyword scoring so the app keeps working even with AI disabled or
/// before the embedding model is downloaded.
class RagService {
  RagService(this._db, this._docService, this._ocr, this._ref);

  final AppDatabase _db;
  final DocumentService _docService;
  final OcrService _ocr;
  final Ref _ref;

  /// Creates the document row and returns its id. Fast: no text extraction.
  Future<int> addDocument(ImportedDocument doc, {String? subject}) async {
    return _db.into(_db.documents).insert(
          DocumentsCompanion.insert(
            name: doc.name,
            kind: doc.kind,
            filePath: doc.filePath,
            pageCount: Value(doc.pageCount),
            subject: Value(subject),
          ),
        );
  }

  /// Extracts text (running OCR first when the PDF has none), chunks it and
  /// embeds each chunk for [documentId]. Call after [addDocument].
  Future<void> indexDocumentContent(
    int documentId,
    ImportedDocument doc, {
    void Function(int page, int total)? onOcrProgress,
  }) async {
    var text = await _docService.extractText(doc);
    if (text.trim().isEmpty && doc.kind == 'pdf') {
      text = await _ocr.recognizeFile(doc.filePath, onProgress: onOcrProgress);
    }
    final chunks = _docService.chunkText(text);
    if (chunks.isEmpty) return;

    final vectors = await _embedBatch(chunks);
    await _db.batch((batch) {
      for (var i = 0; i < chunks.length; i++) {
        batch.insert(
          _db.chunks,
          ChunksCompanion.insert(
            documentId: documentId,
            pageIndex: const Value(0),
            content: chunks[i],
            embedding: vectors != null
                ? Value(encodeEmbedding(vectors[i]))
                : const Value(null),
          ),
        );
      }
    });
  }

  /// Creates the document row and indexes it; returns the new id.
  Future<int> indexDocument(
    ImportedDocument doc, {
    String? subject,
    void Function(int page, int total)? onOcrProgress,
  }) async {
    final docId = await addDocument(doc, subject: subject);
    await indexDocumentContent(docId, doc, onOcrProgress: onOcrProgress);
    return docId;
  }

  /// Rebuilds the chunks for an existing document (startup data repair and
  /// the manual Re-index action). Runs OCR when the embedded text is absent.
  Future<void> reindexDocument(
    int documentId, {
    void Function(int page, int total)? onOcrProgress,
  }) async {
    final doc = await (_db.select(_db.documents)
          ..where((t) => t.id.equals(documentId)))
        .getSingleOrNull();
    if (doc == null) return;

    await (_db.delete(_db.chunks)
          ..where((t) => t.documentId.equals(documentId)))
        .go();

    final imported = ImportedDocument(
      name: doc.name,
      kind: doc.kind,
      filePath: doc.filePath,
      pageCount: doc.pageCount,
    );
    await indexDocumentContent(documentId, imported, onOcrProgress: onOcrProgress);
  }

  /// Returns the top [k] chunks most relevant to [query].
  ///
  /// When [documentIds] is given, only chunks from those documents are
  /// considered (used to scope retrieval to a notebook).
  Future<List<RetrievedChunk>> retrieve(
    String query, {
    int k = 4,
    Set<int>? documentIds,
  }) async {
    final joined = _db.select(_db.chunks).join([
      innerJoin(
        _db.documents,
        _db.documents.id.equalsExp(_db.chunks.documentId),
      ),
    ]);
    // Scope to the requested documents in SQL so unrelated chunks are never
    // loaded for notebook/reader-scoped retrieval.
    if (documentIds != null && documentIds.isNotEmpty) {
      joined.where(_db.chunks.documentId.isIn(documentIds));
    }
    final all = await joined.get();

    if (all.isEmpty) return const [];

    final q = query.toLowerCase();
    final queryTerms = q.split(RegExp(r'\W+')).where((t) => t.length > 2).toList();
    final qEmbedding = queryTerms.isNotEmpty ? await _embedSingle(query) : null;

    final scored = <_ScoredRow>[];
    for (final row in all) {
      final chunk = row.readTable(_db.chunks);
      final doc = row.readTable(_db.documents);
      final emb = chunk.embedding;

      double score;
      if (emb != null && qEmbedding != null) {
        score = _cosine(decodeEmbedding(emb), qEmbedding);
      } else {
        score = _keywordScore(chunk.content, queryTerms);
      }

      scored.add(_ScoredRow(chunk, doc, score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored
        .take(k)
        .map(
          (s) => RetrievedChunk(
            text: s.chunk.content,
            documentId: s.doc.id,
            documentName: s.doc.name,
            score: s.score,
            pageIndex: s.chunk.pageIndex,
          ),
        )
        .toList();
  }

  double _keywordScore(String content, List<String> terms) {
    if (terms.isEmpty) return 0;
    final lower = content.toLowerCase();
    var hits = 0;
    for (final t in terms) {
      if (lower.contains(t)) hits++;
    }
    return hits / terms.length;
  }

  double _cosine(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0;
    var dot = 0.0, na = 0.0, nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  Future<List<double>?> _embedSingle(String text) async {
    final engine = _ref.read(aiEngineProvider.notifier);
    final active = _ref.read(activeModelProvider);
    if (!active.isEmbedding || !_ref.read(aiEnabledProvider)) return null;
    try {
      return await engine.embed(text);
    } catch (e, stackTrace) {
      logger.warning('Failed to embed query; falling back to keyword scoring', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<List<List<double>>?> _embedBatch(List<String> texts) async {
    final active = _ref.read(activeModelProvider);
    if (!active.isEmbedding || !_ref.read(aiEnabledProvider)) return null;
    final engine = _ref.read(aiEngineProvider.notifier);
    try {
      return await engine.embedBatch(texts);
    } catch (e, stackTrace) {
      logger.warning('Failed to embed batch; falling back to keyword scoring', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}

class _ScoredRow {
  const _ScoredRow(this.chunk, this.doc, this.score);
  final Chunk chunk;
  final Document doc;
  final double score;
}

final ragServiceProvider = Provider<RagService>((ref) {
  return RagService(
    ref.watch(appDatabaseProvider),
    ref.watch(documentServiceProvider),
    ref.watch(ocrServiceProvider),
    ref,
  );
});