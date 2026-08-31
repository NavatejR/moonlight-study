import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'ai_engine.dart';
import 'provider_config.dart';

/// Streams a chat completion from an external HTTP provider (OpenAI /
/// Anthropic / custom OpenAI-compatible endpoint), yielding [ChatDelta]
/// objects compatible with the on-device engine.
class ExternalLlm {
  ExternalLlm(this._config);

  final ExternalProviderConfig _config;
  final Dio _dio = Dio();

  /// Streams a single-turn chat completion (system + user message).
  Stream<ChatDelta> chat({
    required String systemPrompt,
    required String userPrompt,
  }) async* {
    if (_config.provider == ExternalProviderType.anthropic) {
      yield* _chatAnthropic(systemPrompt: systemPrompt, userPrompt: userPrompt);
    } else {
      yield* _chatOpenAICompatible(
          systemPrompt: systemPrompt, userPrompt: userPrompt);
    }
  }

  Stream<ChatDelta> _chatOpenAICompatible({
    required String systemPrompt,
    required String userPrompt,
  }) async* {
    final baseUrl = _config.baseUrl.trim();
    final url = '$baseUrl/chat/completions';
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_config.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${_config.apiKey}';
    }

    final body = jsonEncode({
      'model': _config.model,
      'stream': true,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
    });

    final response = await _dio.post<ResponseBody>(
      url,
      data: body,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
      ),
    );

    final stream = response.data!.stream;
    String buffer = '';

    await for (final raw in stream) {
      buffer += String.fromCharCodes(raw);
      while (buffer.contains('\n')) {
        final idx = buffer.indexOf('\n');
        final line = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 1);
        if (line.isEmpty || line == 'data: [DONE]') continue;
        if (!line.startsWith('data: ')) continue;

        final jsonStr = line.substring(6);
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final delta = choices[0]['delta'] as Map?;
          if (delta == null) continue;
          final content = delta['content'] as String? ?? '';
          final thinking =
              delta['reasoning_content'] as String? ?? '';
          if (content.isNotEmpty || thinking.isNotEmpty) {
            yield ChatDelta(content: content, thinking: thinking);
          }
        } catch (_) {
          // Skip malformed lines.
        }
      }
    }
  }

  Stream<ChatDelta> _chatAnthropic({
    required String systemPrompt,
    required String userPrompt,
  }) async* {
    final baseUrl = _config.baseUrl.trim();
    final url = '$baseUrl/v1/messages';
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
      'x-api-key': _config.apiKey,
    };

    final body = jsonEncode({
      'model': _config.model,
      'max_tokens': 4096,
      'stream': true,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': userPrompt},
      ],
    });

    final response = await _dio.post<ResponseBody>(
      url,
      data: body,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
      ),
    );

    final stream = response.data!.stream;
    String buffer = '';

    await for (final raw in stream) {
      buffer += String.fromCharCodes(raw);
      while (buffer.contains('\n')) {
        final idx = buffer.indexOf('\n');
        final line = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 1);
        if (line.isEmpty || !line.startsWith('data: ')) continue;
        if (line == 'data: [DONE]') continue;

        final jsonStr = line.substring(6);
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final type = data['type'] as String?;
          if (type == 'content_block_delta') {
            final delta = data['delta'] as Map?;
            if (delta == null) continue;
            final text = delta['text'] as String? ?? '';
            if (text.isNotEmpty) {
              yield ChatDelta(content: text);
            }
          }
        } catch (_) {
          // Skip malformed lines.
        }
      }
    }
  }
}
