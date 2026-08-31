import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llamadart/llamadart.dart';

import 'ai_engine.dart';
import 'external_llm.dart';
import 'provider_config.dart';
import 'soul.dart';

/// The unified chat backend: dispatches to the local on-device engine or
/// an external HTTP provider depending on the user's selection.
///
/// Returns a function that takes a user prompt and yields [ChatDelta] objects.
typedef ChatBackend = Stream<ChatDelta> Function(String userPrompt);

/// Provider that returns the active [ChatBackend] function.
final chatBackendProvider = FutureProvider<ChatBackend>((ref) async {
  final useExternal = ref.watch(useExternalProviderProvider);

  if (!useExternal) {
    return (String userPrompt) {
      final engine = ref.read(aiEngineProvider.notifier);
      return engine.chat([LlamaTextContent(userPrompt)]);
    };
  }

  // External provider path.
  final config = ref.watch(externalProviderConfigProvider);
  if (!config.isConfigured) {
    return (String userPrompt) async* {
      yield const ChatDelta(
          content: 'External provider is not configured. '
              'Go to Models → External API and set a base URL and model.');
    };
  }

  final llm = ExternalLlm(config);
  final soul = ref.read(soulSystemPromptProvider).value ??
      await ref.read(soulSystemPromptProvider.future) ??
      'You are Moonlight, a warm, patient study companion.';

  return (String userPrompt) {
    return llm.chat(systemPrompt: soul, userPrompt: userPrompt);
  };
});
