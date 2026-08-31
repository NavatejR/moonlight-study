import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ai/ai_engine.dart';
import '../core/ai/chat_backend.dart';
import '../core/db/app_database.dart';
import '../core/memory/memory_capture.dart';
import '../core/memory/memory_service.dart';
import '../docs/document_service.dart';
import '../docs/prompt_builder.dart';
import '../docs/rag_service.dart';

/// Coordinates the user-facing "study actions": importing a document,
/// generating flashcards, and planning a week. All local.
class StudyActions {
  StudyActions(this.ref);

  final Ref ref;

  /// Imports a file into the library and indexes it for search.
  Future<String?> importDocument() async {
    final service = ref.read(documentServiceProvider);
    final rag = ref.read(ragServiceProvider);
    final doc = await service.importFile();
    if (doc == null) return 'No file selected.';

    await rag.indexDocument(doc);
    return 'Imported "${doc.name}"';
  }

  /// Generates flashcards from the given documents (notebook-scoped). When no
  /// documents are requested it falls back to the first document in the whole
  /// library (legacy behavior).
  Future<List<({String question, String answer})>> generateFlashcards({
    int count = 6,
    Set<int>? documentIds,
  }) async {
    final db = ref.read(appDatabaseProvider);

    if (!ref.read(aiEnabledProvider)) return const [];

    var ids = documentIds;
    if (ids == null || ids.isEmpty) {
      final doc = await db.select(db.documents).get().then(
            (rows) => rows.isEmpty ? null : rows.first,
          );
      if (doc == null) return const [];
      ids = {doc.id};
    }

    final targetIds = ids;
    final chunks = await (db.select(db.chunks)
          ..where((c) => c.documentId.isIn(targetIds)))
        .get();
    if (chunks.isEmpty) return const [];

    // Balance the material across the selected documents so one PDF doesn't
    // dominate a multi-PDF deck.
    final perDoc = <int, List<Chunk>>{};
    for (final row in chunks) {
      perDoc.putIfAbsent(row.documentId, () => []).add(row);
    }
    final capPerDoc = ((12 / perDoc.length).ceil()).clamp(1, 8).toInt();
    final material = perDoc.values
        .expand((list) => list.take(capPerDoc))
        .map((c) => c.content)
        .join('\n\n');

    final memory = ref.read(memoryServiceProvider);
    final memoryOn = ref.read(memoriesEnabledProvider);
    final recall =
        memoryOn ? await memory.retrieve(material, k: 2) : const [];
    final backend = await ref.read(chatBackendProvider.future);
    final stream = backend(
      PromptBuilder.flashcardPrompt(
        material: material,
        count: count,
          memories: recall.map<String>((m) => m.content).toList(),
      ),
    );

    final buffer = StringBuffer();
    await for (final delta in stream) {
      buffer.write(delta.content);
    }
    final cards = PromptBuilder.parseJsonArray(buffer.toString());
    if (memoryOn) {
      await MemoryCapture.capture(
        memory,
        user: 'Generate flashcards from my notes.',
        assistant: buffer.toString(),
      );
    }
    return cards
        .map(
          (c) => (
            question: (c['question'] ?? '').toString(),
            answer: (c['answer'] ?? '').toString(),
          ),
        )
        .where((c) => c.question.isNotEmpty && c.answer.isNotEmpty)
        .toList();
  }

  /// Persists generated flashcards for a document, optionally into [groupId]
  /// (a flashcard group, e.g. a chapter).
  Future<void> saveFlashcards(
    int documentId,
    List<({String question, String answer})> cards, {
    int? groupId,
  }) async {
    final db = ref.read(appDatabaseProvider);
    for (final card in cards) {
      await db.into(db.flashcards).insert(
            FlashcardsCompanion.insert(
              documentId: documentId,
              groupId: Value(groupId),
              question: card.question,
              answer: card.answer,
            ),
          );
    }
  }

  /// Adds a single manually-created flashcard. Falls back to the first
  /// document in the library when no [documentId] is given.
  Future<void> addFlashcard({
    required String question,
    required String answer,
    int? documentId,
    int? groupId,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final docId = documentId ?? await _firstDocumentId(db);
    if (docId == null) return;
    await saveFlashcards(docId, [(question: question, answer: answer)],
        groupId: groupId);
  }

  /// Creates a named flashcard group (e.g. a chapter) and returns its id.
  Future<int> createFlashcardGroup(String title) async {
    final db = ref.read(appDatabaseProvider);
    return db.into(db.flashcardGroups).insert(
          FlashcardGroupsCompanion.insert(title: title.trim()),
        );
  }

  /// Deletes a flashcard group. Its cards are kept but ungrouped.
  Future<void> deleteFlashcardGroup(int id) async {
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.flashcards)
          ..where((f) => f.groupId.equals(id)))
        .write(const FlashcardsCompanion(groupId: Value(null)));
    await (db.delete(db.flashcardGroups)..where((g) => g.id.equals(id))).go();
  }

  /// Deletes a single flashcard.
  Future<void> deleteFlashcard(int id) async {
    final db = ref.read(appDatabaseProvider);
    await (db.delete(db.flashcards)..where((f) => f.id.equals(id))).go();
  }

  Future<int?> _firstDocumentId(AppDatabase db) async {
    final rows = await (db.select(db.documents)..limit(1)).get();
    return rows.isEmpty ? null : rows.first.id;
  }
}

final studyActionsProvider = Provider<StudyActions>((ref) => StudyActions(ref));

/// Stream of flashcards for the Flashcards screen.
final flashcardsProvider = StreamProvider<List<Flashcard>>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  yield await db.select(db.flashcards).get();
});

/// Stream of flashcard groups (e.g. chapters) for the Flashcards screen.
final flashcardGroupsProvider = StreamProvider<List<FlashcardGroup>>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  yield await db.select(db.flashcardGroups).get();
});

/// Stream of planner sessions for the Planner screen.
final sessionsProvider = StreamProvider<List<StudySession>>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final rows = await (db.select(db.studySessions)
        ..orderBy([(t) => OrderingTerm.asc(t.date)]))
      .get();
  yield rows;
});