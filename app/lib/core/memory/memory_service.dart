import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../settings/settings_storage.dart';

/// Category labels for a memory entry. These help group and prune memories.
enum MemoryCategory {
  preference,
  goal,
  knowledgeGap,
  studyHabit;

  String get label {
    switch (this) {
      case MemoryCategory.preference:
        return 'preference';
      case MemoryCategory.goal:
        return 'goal';
      case MemoryCategory.knowledgeGap:
        return 'knowledge_gap';
      case MemoryCategory.studyHabit:
        return 'study_habit';
    }
  }
}

/// A single durable memory about the learner.
class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.content,
    required this.category,
    required this.importance,
    required this.createdAt,
    this.score = 0,
  });

  final int id;
  final String content;
  final MemoryCategory category;
  final int importance;
  final DateTime createdAt;
  final double score;
}

/// Stores and retrieves durable memories about the learner so the AI can
/// understand intent and tailor responses across Study Chat, the notebook
/// assistant and flashcard generation.
class MemoryService {
  MemoryService(this._db);

  final AppDatabase _db;

  static const int _maxPerCategory = 25;

  /// Stores a memory, de-duplicating near-identical content (case-insensitive
  /// prefix match) and pruning the category if it grows too large.
  Future<void> store(
    String content,
    MemoryCategory category, {
    int importance = 1,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final lower = trimmed.toLowerCase();

    final existing = await (_db.select(_db.memories)
          ..where((m) => m.category.equals(category.label)))
        .get();
    for (final row in existing) {
      if (row.content.toLowerCase() == lower ||
          lower.contains(row.content.toLowerCase())) {
        return; // already known
      }
    }

    await _db.into(_db.memories).insert(
          MemoriesCompanion.insert(
            content: trimmed,
            category: category.label,
            importance: Value(importance),
          ),
        );

    await _prune(category);
  }

  /// Returns up to [k] memories most relevant to [query], scored by keyword
  /// match (like RAG) with a small recency boost. Silently returns nothing
  /// when AI is disabled or no memories exist.
  Future<List<MemoryEntry>> retrieve(String query, {int k = 3}) async {
    final all = await _db.select(_db.memories).get();
    if (all.isEmpty) return const [];

    final terms = query
        .toLowerCase()
        .split(RegExp(r'[^\w]+'))
        .where((t) => t.length > 2)
        .toList();

    final scored = <MemoryEntry>[];
    for (final row in all) {
      final content = row.content.toLowerCase();
      var hits = 0;
      for (final t in terms) {
        if (content.contains(t)) hits++;
      }
      final termScore = terms.isEmpty ? 0.0 : hits / terms.length;
      final days = DateTime.now().difference(row.createdAt).inDays;
      final recency = (1.0 - (days / 60).clamp(0.0, 1.0)) * 0.2;
      final score = termScore + recency;
      if (score <= 0) continue;
      scored.add(
        MemoryEntry(
          id: row.id,
          content: row.content,
          category: _categoryFrom(row.category),
          importance: row.importance,
          createdAt: row.createdAt,
          score: score,
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(k).toList();
  }

  /// Total number of stored memories.
  Future<int> count() async {
    final rows = await _db.select(_db.memories).get();
    return rows.length;
  }

  /// Clears all stored memories.
  Future<void> clear() async {
    await _db.delete(_db.memories).go();
  }

  MemoryCategory _categoryFrom(String s) {
    for (final c in MemoryCategory.values) {
      if (c.label == s) return c;
    }
    return MemoryCategory.preference;
  }

  /// Keeps a category bounded by dropping the oldest / least-important rows.
  Future<void> _prune(MemoryCategory category) async {
    final rows = await (_db.select(_db.memories)
          ..where((m) => m.category.equals(category.label)))
        .get();
    if (rows.length <= _maxPerCategory) return;
    rows.sort((a, b) {
      final importance = b.importance.compareTo(a.importance);
      if (importance != 0) return importance;
      return a.createdAt.compareTo(b.createdAt);
    });
    final keep = rows.take(_maxPerCategory).map((r) => r.id).toSet();
    for (final row in rows) {
      if (!keep.contains(row.id)) {
        await (_db.delete(_db.memories)..where((m) => m.id.equals(row.id))).go();
      }
    }
  }
}

final memoryServiceProvider = Provider<MemoryService>((ref) {
  final db = ref.read(appDatabaseProvider);
  return MemoryService(db);
});

/// Master switch for the memory system. When off, memories are neither
/// captured nor injected. Persisted in the Drift settings KV table.
final memoriesEnabledProvider =
    NotifierProvider<MemoriesEnabledNotifier, bool>(MemoriesEnabledNotifier.new);

class MemoriesEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  Future<void> set(bool value) async {
    state = value;
    final storage = ref.read(settingsStorageProvider);
    await storage.setPref('memories_enabled', value.toString());
  }
}
