import 'dart:convert';

import '../docs/rag_service.dart';

/// Builds grounded, citation-aware prompts for the chat model.
abstract final class PromptBuilder {
  PromptBuilder._();

  /// A single user prompt with document context inline, plus optional
  /// [memories] about the learner so the response is tailored to their intent.
  static String groundedQuestion({
    required String question,
    required List<RetrievedChunk> context,
    List<String> memories = const [],
  }) {
    final sb = StringBuffer();

    if (memories.isNotEmpty) {
      sb
        ..writeln('Context you remember about this learner:')
        ..writeln(memories.map((m) => '- $m').join('\n'))
        ..writeln();
    }

    if (context.isEmpty && memories.isEmpty) return question;

    if (context.isEmpty) {
      sb
        ..writeln('The learner remembers the following about themselves. '
            'Answer their question with that in mind, and be honest when the '
            'answer is not covered by their material.\n')
        ..writeln('--- QUESTION ---')
        ..writeln(question);
      return sb.toString();
    }

    sb
      ..writeln('Use the following source material from the user\'s study '
          'documents to answer their question. Cite the relevant source '
          'sections inline like [1], [2]. If the sources do not contain the '
          'answer, say so plainly.\n')
      ..writeln('--- SOURCES ---');
    for (var i = 0; i < context.length; i++) {
      final c = context[i];
      sb
        ..writeln('[${i + 1}] ${c.documentName}:')
        ..writeln(c.text)
        ..writeln();
    }
    sb
      ..writeln('--- QUESTION ---')
      ..writeln(question);
    return sb.toString();
  }

  /// Asks the model to produce flashcards as strict JSON.
  static String flashcardPrompt({
    required String material,
    required int count,
    List<String> memories = const [],
  }) {
    final mem = memories.isNotEmpty
        ? '\nKeep in mind the learner is studying for: ${memories.join('; ')}.\n'
        : '';
    return '''
From the study material below, create exactly $count high-yield flashcards.
Return ONLY a JSON array. Each object must have "question" and "answer" strings.
$mem
Example:
[{"question":"What is a carbonyl group?","answer":"A functional group C=O."}]

MATERIAL:
$material''';
  }

  /// Asks the model for a weekly study plan as strict JSON.
  static String plannerPrompt({
    required List<String> subjects,
    required DateTime examDate,
  }) {
    final days = examDate.difference(DateTime.now()).inDays.clamp(1, 365);
    return '''
Create a focused study plan for the next $days days until the exam
(${examDate.toIso8601String().substring(0, 10)}).
Subjects: ${subjects.join(', ')}.

Return ONLY a JSON array of sessions. Each object needs:
"day" (0-indexed offset from today), "title", "subject", "minutes".

Example:
[{"day":0,"title":"Intro to mechanisms","subject":"Chemistry","minutes":45}]''';
  }

  /// Attempts to parse a model response as JSON, tolerating markdown fences.
  static List<Map<String, dynamic>> parseJsonArray(String raw) {
    var text = raw.trim();
    // Strip ```json ... ``` fences if present.
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final m = fence.firstMatch(text);
    if (m != null) text = m.group(1)!.trim();

    final first = text.indexOf('[');
    final last = text.lastIndexOf(']');
    if (first >= 0 && last > first) {
      text = text.substring(first, last + 1);
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}