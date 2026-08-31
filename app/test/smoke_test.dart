import 'package:flutter_test/flutter_test.dart';
import 'package:llamadart/llamadart.dart';

void main() {
  test('SmolLM2 generation end-to-end', () async {
    final engine = LlamaEngine(LlamaBackend());
    await engine.loadModelSource(
      ModelSource.parse(
        'hf://unsloth/SmolLM2-135M-Instruct-GGUF/SmolLM2-135M-Instruct-Q2_K.gguf',
      ),
      modelParams: const ModelParams(contextSize: 512),
    );

    final session = ChatSession(
      engine,
      systemPrompt: 'You are a helpful, concise tutor.',
    );
    final buffer = StringBuffer();
    await for (final chunk in session.create([
      LlamaTextContent('What is 2+2? Answer in one word.'),
    ])) {
      final delta = chunk.choices.isNotEmpty
          ? chunk.choices.first.delta.content
          : null;
      if (delta != null) buffer.write(delta);
    }

    engine.dispose();
    expect(buffer.toString().trim(), isNotEmpty);
    // ignore: avoid_print
    print('ANSWER: ${buffer.toString().trim()}');
  }, timeout: const Timeout(Duration(minutes: 10)));
}