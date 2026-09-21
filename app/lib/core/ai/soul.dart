import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../logging/app_logger.dart';

/// The Moonlight personality (bundled `assets/soul.md`), used as the base
/// system prompt for every AI surface (Study Chat, notebook assistant,
/// flashcards). Falls back to the catalog prompt if the asset can't be read.
final soulSystemPromptProvider = FutureProvider<String>((ref) async {
  try {
    final text = await rootBundle.loadString('assets/soul.md');
    if (text.trim().isNotEmpty) return text;
  } catch (e, stackTrace) {
    logger.warning('Failed to read soul.md; using fallback', error: e, stackTrace: stackTrace);
  }
  return _fallbackSoul;
});

const _fallbackSoul = '''
You are Moonlight, a warm, patient study companion that helps learners
understand their material deeply. Be concise but thorough. When answering
from provided notes or documents, cite the source sections you used. Use
markdown when it helps (headings, lists, formulas).''';
