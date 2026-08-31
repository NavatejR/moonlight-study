import 'package:flutter_test/flutter_test.dart';
import 'package:llamadart/llamadart.dart';

void main() {
  test('Qwen2.5-VL generation with mmproj end-to-end', () async {
    final engine = LlamaEngine(LlamaBackend());
    await engine.loadModelSource(
      ModelSource.parse(
        'hf://llmware/qwen2.5-vl-3b-instruct-gguf/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf',
      ),
      modelParams: const ModelParams(contextSize: 2048, gpuLayers: 0),
    );
    await engine.loadMultimodalProjectorSource(
      ModelSource.parse(
        'hf://llmware/qwen2.5-vl-3b-instruct-gguf/mmproj-F16.gguf',
      ),
    );

    final session = ChatSession(
      engine,
      systemPrompt: 'You are a helpful, concise tutor.',
    );
    final buffer = StringBuffer();
    await for (final chunk in session.create([
      LlamaTextContent('Say the word "ready" and nothing else.'),
    ])) {
      final delta = chunk.choices.isNotEmpty
          ? chunk.choices.first.delta.content
          : null;
      if (delta != null) buffer.write(delta);
    }

    engine.dispose();
    expect(buffer.toString().trim(), isNotEmpty);
    // ignore: avoid_print
    print('QA: ${buffer.toString().trim()}');
  }, timeout: const Timeout(Duration(minutes: 15)));
}