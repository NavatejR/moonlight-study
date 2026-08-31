import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_engine.dart';
import '../../core/ai/chat_backend.dart';
import '../../core/memory/memory_capture.dart';
import '../../core/memory/memory_service.dart';
import '../../docs/prompt_builder.dart';
import '../../docs/rag_service.dart';
import '../reader/reading_context.dart';

/// A single rendered chat message with optional source citations.
class ChatViewMessage {
  const ChatViewMessage({
    required this.role,
    required this.content,
    this.thinking = '',
    this.citations = const [],
  });

  final String role;
  final String content;
  final String thinking;
  final List<String> citations;
}

final chatMessagesProvider =
    NotifierProvider<ChatMessagesNotifier, List<ChatViewMessage>>(
        ChatMessagesNotifier.new);

class ChatMessagesNotifier extends Notifier<List<ChatViewMessage>> {
  @override
  List<ChatViewMessage> build() => const [];

  void add(ChatViewMessage message) => state = [...state, message];

  void updateLast(String content, {String thinking = ''}) {
    if (state.isEmpty) return;
    state = [
      ...state.sublist(0, state.length - 1),
      ChatViewMessage(
        role: state.last.role,
        content: content,
        thinking: thinking,
      ),
    ];
  }

  void updateLastWithCitations(List<String> citations) {
    if (state.isEmpty) return;
    final last = state.last;
    state = [
      ...state.sublist(0, state.length - 1),
      ChatViewMessage(
        role: last.role,
        content: last.content,
        thinking: last.thinking,
        citations: citations,
      ),
    ];
  }
}

final chatBusyProvider =
    NotifierProvider<ChatBusyNotifier, bool>(ChatBusyNotifier.new);

class ChatBusyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final chatControllerProvider =
    NotifierProvider<ChatController, bool>(ChatController.new);

class ChatController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Sends a user message; retrieves context, streams the answer and tags
  /// it with citations to the source chunks used.
  Future<void> send(String text) async {
    final messages = ref.read(chatMessagesProvider.notifier);
    final busy = ref.read(chatBusyProvider.notifier);
    final rag = ref.read(ragServiceProvider);
    final memory = ref.read(memoryServiceProvider);

    if (!ref.read(aiEnabledProvider)) return;

    messages.add(ChatViewMessage(role: 'user', content: text));
    busy.set(true);

    try {
      // Ground the answer on the PDF currently open in the reader when there
      // is one; otherwise fall back to the whole library.
      final reading = ref.read(readingContextProvider);
      final hits = reading != null
          ? await rag.retrieve(text, k: 4, documentIds: {reading.documentId})
          : await rag.retrieve(text, k: 4);
      final citations = hits
          .where((c) => c.score > 0.1)
          .map((c) => c.documentName)
          .toSet()
          .take(3)
          .toList();

      // Recall what we know about the learner so responses match their intent.
      final memoryOn = ref.read(memoriesEnabledProvider);
      final recall = memoryOn ? await memory.retrieve(text, k: 3) : const [];
      final prompt = PromptBuilder.groundedQuestion(
        question: text,
        context: hits,
        memories: recall.map<String>((m) => m.content).toList(),
      );

      messages.add(ChatViewMessage(role: 'assistant', content: ''));
      final buffer = StringBuffer();
      final thinkBuffer = StringBuffer();
      final backend = await ref.read(chatBackendProvider.future);
      await for (final delta in backend(prompt)) {
        buffer.write(delta.content);
        thinkBuffer.write(delta.thinking);
        messages.updateLast(buffer.toString(), thinking: thinkBuffer.toString());
      }

      // Learn from this exchange so future answers improve.
      final answer = buffer.toString();
      if (ref.read(memoriesEnabledProvider)) {
        await MemoryCapture.capture(memory, user: text, assistant: answer);
      }

      if (citations.isNotEmpty) {
        messages.updateLast(buffer.toString());
        ref.read(chatMessagesProvider.notifier).updateLastWithCitations(citations);
      }
    } finally {
      busy.set(false);
    }
  }
}