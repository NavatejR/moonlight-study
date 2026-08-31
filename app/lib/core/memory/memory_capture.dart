import 'memory_service.dart';

/// Lightweight, rule-based memory extraction. Given a user message (and
/// optionally the assistant's reply), it detects memory-worthy facts about the
/// learner — goals, preferences, knowledge gaps and study habits — and stores
/// them via [MemoryService].
///
/// Deliberately no model call: stays fast and offline, aggregating paraphrases
/// into short, reusable memory lines.
abstract final class MemoryCapture {
  MemoryCapture._();

  /// Extracts and persists memories from a conversational exchange.
  /// Returns the number of memories stored (for testing / display).
  static Future<int> capture(
    MemoryService service, {
    required String user,
    String? assistant,
  }) async {
    final memories = <(String, MemoryCategory, int)>[];

    memories.addAll(_extractFromUser(user));

    if (assistant != null && assistant.trim().isNotEmpty) {
      memories.addAll(_extractFromAssistant(assistant, user));
    }

    for (final (content, category, importance) in memories) {
      await service.store(content, category, importance: importance);
    }
    return memories.length;
  }

  /// Patterns that reveal something durable about the learner from what they
  /// typed. Order matters: earlier (more specific) patterns win.
  static List<(String, MemoryCategory, int)> _extractFromUser(String user) {
    final text = user.trim();
    final lower = text.toLowerCase();
    final out = <(String, MemoryCategory, int)>[];

    // Goals: "I'm studying for X", "I have a test/exam on X"
    final goal = _matchFirst(
      lower,
      {
        RegExp(r"i'[m ]+studying (?:for|toward) ([\w ,\-&]+?)\.?$"),
        RegExp(r"i(?:'m| am)? preparing (?:for|to take) ([\w ,\-&]+?)\.?$"),
        RegExp(r"(?:test|exam|midterm|final)(?: is)? on ([a-z0-9 ,\-]+)"),
      },
    );
    if (goal != null && goal.length > 2 && goal.length < 80) {
      out.add((
        'Studying for: $goal',
        MemoryCategory.goal,
        2,
      ));
    }

    // Knowledge gaps: "I don't understand X", "I struggle with X"
    final gap = _matchFirst(
      lower,
      {
        RegExp(r"i (?:don'?t|do not) (?:understand|get|grasp) ([\w ,\-]+)"),
        RegExp(r"i (?:struggl[ae]|have trouble|find it hard) (?:with|to) ([\w ,\-]+)"),
        RegExp(r"i (?:always )?mix up ([\w ,\-]+)"),
      },
    );
    if (gap != null && gap.length > 1 && gap.length < 80) {
      out.add((
        'Knowledge gap: $gap',
        MemoryCategory.knowledgeGap,
        2,
      ));
    }

    // Preferences: "I like/prefer/need X", "I want/am aiming for X"
    final perf = _matchFirst(
      lower,
      {
        RegExp(r"i (?:like|love|prefer|need) ([\w ,\-&']+)"),
        RegExp(r"i want to ([\w ,\-]+)"),
      },
    );
    if (perf != null && perf.length > 2 && perf.length < 80) {
      out.add((
        'Prefers: $perf',
        MemoryCategory.preference,
        1,
      ));
    }

    return out;
  }

  /// Detects that the assistant helped with something the learner found hard
  /// or that the learner is making progress on (turns into a study habit /
  /// ongoing-topic memory).
  static List<(String, MemoryCategory, int)> _extractFromAssistant(
    String assistant,
    String user,
  ) {
    final out = <(String, MemoryCategory, int)>[];
    final lower = assistant.toLowerCase();

    if (lower.contains('keep practicing') ||
        lower.contains('you can do') ||
        lower.contains('good question')) {
      out.add((
        'Actively working on: ${user.trim()}',
        MemoryCategory.studyHabit,
        1,
      ));
    }
    return out;
  }

  /// Returns the first named-group-1 match across [patterns].
  static String? _matchFirst(String lower, Set<RegExp> patterns) {
    for (final re in patterns) {
      final m = re.firstMatch(lower);
      if (m != null && m.groupCount >= 1) {
        final g = m.group(1)?.trim();
        if (g != null && g.isNotEmpty) return g;
      }
    }
    return null;
  }
}
