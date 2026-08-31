import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_engine.dart';
import '../../core/theme/colors.dart';
import '../../shared/widgets/coffee_card.dart';
import '../../shared/widgets/latex_extension.dart';
import '../../shared/widgets/reasoning_block.dart';
import '../reader/reading_context.dart';
import 'chat_provider.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatMessagesProvider);
    final busy = ref.watch(chatBusyProvider);
    final engine = ref.watch(aiEngineProvider);
    final reading = ref.watch(readingContextProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study Chat',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Local model · answers with citations from your notes',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _ModelChip(state: engine),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              children: [
                if (messages.isEmpty)
                  const _WelcomeMessage()
                else
                  for (final m in messages) _MessageBubble(message: m),
                if (busy) _TypingBubble(),
              ],
            ),
          ),
          if (reading != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book_rounded,
                      size: 14, color: CoffeeColors.cacao),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Reading: ${reading.documentName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CoffeeColors.cacao,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _ChatInputBar(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({required this.state});

  final AiEngineState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state.status) {
      AiStatus.ready => CoffeeColors.moss,
      AiStatus.error => const Color(0xFFB3261E),
      AiStatus.idle => CoffeeColors.cacao,
      _ => CoffeeColors.caramel,
    };
    final label = switch (state.status) {
      AiStatus.ready => 'Local · ready',
      AiStatus.loading => 'Loading…',
      AiStatus.downloading => 'Downloading…',
      AiStatus.working => 'Thinking…',
      AiStatus.error => 'Model error',
      AiStatus.idle => 'Model not loaded',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _WelcomeMessage extends StatelessWidget {
  const _WelcomeMessage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: CoffeeColors.paper,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: CoffeeColors.caramel, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Pour a cup, let\'s study.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Ask questions about any notebook, image, or PDF.\nEverything runs on your device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _SuggestionChip('Explain the carbonyl group'),
              _SuggestionChip('Summarize my note'),
              _SuggestionChip('Make flashcards'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: () {});
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatViewMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: CoffeeColors.caramel,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(message.content, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    return CoffeeCard(
      margin: const EdgeInsets.only(top: 10, bottom: 2),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReasoningBlock(text: message.thinking),
          MarkdownBody(
            data: message.content,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
            blockSyntaxes: latexBlockSyntaxes,
            inlineSyntaxes: latexInlineSyntaxes,
            builders: latexBuilders(
              textStyle: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (message.citations.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final c in message.citations)
                  _CitationChip(label: c),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: CoffeeColors.sage.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_rounded, size: 13, color: CoffeeColors.moss),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: CoffeeColors.moss,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CoffeeCard(
      margin: const EdgeInsets.only(top: 10, bottom: 2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 600 + i * 200),
                  builder: (context, t, _) => Opacity(
                    opacity: 0.3 + t * 0.7,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: CoffeeColors.caramel,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<_ChatInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(aiEngineProvider);
    final busy = ref.watch(chatBusyProvider);
    final enabled = ref.watch(aiEnabledProvider) &&
        engine.status == AiStatus.ready &&
        !busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: !ref.watch(aiEnabledProvider)
                    ? 'AI is off — enable it in Models'
                    : engine.status != AiStatus.ready
                        ? 'Waiting for a local model…'
                        : 'Ask anything about your studies…',
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: enabled ? _send : null,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward_rounded),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(chatControllerProvider.notifier).send(text);
  }
}