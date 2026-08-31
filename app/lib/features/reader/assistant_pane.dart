import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_engine.dart';
import '../../core/ai/chat_backend.dart';
import '../../core/memory/memory_capture.dart';
import '../../core/memory/memory_service.dart';
import '../../core/theme/colors.dart';
import '../../docs/prompt_builder.dart';
import '../../docs/rag_service.dart';
import '../../shared/widgets/latex_extension.dart';
import '../../shared/widgets/reasoning_block.dart';
import '../notebooks/notebooks_provider.dart';
import 'notes_pane.dart';

/// Right-hand panel for the reader: a tabbed surface with the notebook's
/// grounded AI assistant and the notes list.
class ReaderRightPanel extends ConsumerWidget {
  const ReaderRightPanel({
    super.key,
    required this.notebookId,
    required this.tabController,
    this.documentId,
  });

  final int notebookId;
  final TabController tabController;
  final int? documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final aiOn = ref.watch(aiEnabledProvider);

    return Column(
      children: [
        Material(
          color: scheme.surface,
          child: TabBar(
            controller: tabController,
            labelStyle: const TextStyle(
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              const Tab(text: 'Notes'),
              Tab(text: aiOn ? 'AI assistant' : 'AI (off)'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              NotesPane(notebookId: notebookId, documentId: documentId),
              if (aiOn)
                _AssistantPane(
                  notebookId: notebookId,
                  documentId: documentId,
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'AI is off — enable it in Models to use the assistant.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One message in the reader's AI assistant conversation. Lives in a provider
/// so reader actions (Summarize/Explain) can push copyable results into the
/// assistant tab without the pane holding the state itself.
class AssistantEntry {
  const AssistantEntry({
    required this.role,
    required this.text,
    this.thinking = '',
    this.citations = const [],
  });

  final String role; // 'user' | 'assistant'
  final String text;
  final String thinking;
  final List<String> citations;

  bool get isUser => role == 'user';

  AssistantEntry copyWith({
    String? text,
    String? thinking,
    List<String>? citations,
  }) =>
      AssistantEntry(
        role: role,
        text: text ?? this.text,
        thinking: thinking ?? this.thinking,
        citations: citations ?? this.citations,
      );
}

/// The active assistant conversation for one notebook. Also owns the answer
/// flow, so both typing here and reader actions (Summarize/Explain) send the
/// query and stream the grounded answer through the same path.
class ReaderAssistantNotifier extends FamilyNotifier<List<AssistantEntry>, int> {
  late int _notebookId;

  @override
  List<AssistantEntry> build(int notebookId) {
    _notebookId = notebookId;
    return const [];
  }

  void addUser(String text) {
    state = [...state, AssistantEntry(role: 'user', text: text)];
  }

  void addAssistant(String text, {List<String> citations = const []}) {
    state = [
      ...state,
      AssistantEntry(role: 'assistant', text: text, citations: citations),
    ];
  }

  /// Sends [text] as a user query and actively streams the model's grounded
  /// answer into the conversation.
  ///
  /// [documentId] scopes retrieval to that PDF when provided (the reader uses
  /// it); otherwise questions fall back to every document in the notebook.
        Future<void> ask(String text, {int? documentId}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    addUser(trimmed);

    if (!ref.read(aiEnabledProvider)) {
      addAssistant('AI is off — enable it in Models.');
      return;
    }

    if (ref.read(aiEngineProvider).status != AiStatus.ready) {
      addAssistant('Load a model in Models first.');
      return;
    }

    try {
      final rag = ref.read(ragServiceProvider);
      final Set<int> docIds;
      if (documentId != null) {
        docIds = {documentId};
      } else {
        final docs = ref.read(notebookDocumentsProvider(_notebookId)).value ??
            const [];
        docIds = docs.map((d) => d.id).toSet();
      }
      final hits = await rag.retrieve(trimmed, k: 4, documentIds: docIds);
      final citationNames
 = hits
          .where((c) => c.score > 0.1)
          .map((c) => c.documentName)
          .toSet()
          .take(3)
          .toList();

      final memory = ref.read(memoryServiceProvider);
      final memoryOn = ref.read(memoriesEnabledProvider);
      final recall =
          memoryOn ? await memory.retrieve(trimmed, k: 3) : const [];
      final prompt = PromptBuilder.groundedQuestion(
        question: trimmed,
        context: hits,
        memories: recall.map<String>((m) => m.content).toList(),
      );

      addAssistant('', citations: citationNames);

      final buffer = StringBuffer();
      final thinkBuffer = StringBuffer();
      final backend = await ref.read(chatBackendProvider.future);
      await for (final delta in backend(prompt)) {
        buffer.write(delta.content);
        thinkBuffer.write(delta.thinking);
        updateLast(buffer.toString(), thinking: thinkBuffer.toString());
      }

      if (ref.read(memoriesEnabledProvider)) {
        await MemoryCapture.capture(
          memory,
          user: trimmed,
          assistant: buffer.toString(),
        );
      }
    } catch (e) {
      addAssistant('Error: $e');
    }
  }

  /// Replaces the last assistant message with [text] (streaming progress).
  void updateLast(String text, {String? thinking, List<String>? citations}) {
    if (state.isEmpty) return;
    final last = state.last;
    state = [
      ...state.sublist(0, state.length - 1),
      last.copyWith(
        text: text,
        thinking: thinking ?? last.thinking,
        citations: citations ?? last.citations,
      ),
    ];
  }
}

/// Deliberately NOT autoDispose: reader actions (Summarize/Explain) push a
/// query into this conversation while the AI tab may be hidden behind Notes;
/// an autoDisposed provider would be dropped and the streamed answer lost
/// (messages never appear until the query is re-sent on the active tab).
final readerAssistantProvider =
    NotifierProvider.family<ReaderAssistantNotifier, List<AssistantEntry>, int>(
  ReaderAssistantNotifier.new,
);

/// A compact, notebook-scoped chat surface. Retrieves context from the
/// notebook's documents (if indexed) and streams the model's answer.
class _AssistantPane extends ConsumerStatefulWidget {
  const _AssistantPane({required this.notebookId, this.documentId});

  final int notebookId;
  final int? documentId;

  @override
  ConsumerState<_AssistantPane> createState() => _AssistantPaneState();
}

class _AssistantPaneState extends ConsumerState<_AssistantPane> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ReaderAssistantNotifier get _conv =>
      ref.read(readerAssistantProvider(widget.notebookId).notifier);

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _busy) return;
    _controller.clear();
    setState(() => _busy = true);
    try {
      await _conv.ask(trimmed, documentId: widget.documentId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final messages = ref.watch(readerAssistantProvider(widget.notebookId));
    final docs =
        ref.watch(notebookDocumentsProvider(widget.notebookId)).value ?? const [];
    var docName = '';
    if (widget.documentId != null) {
      for (final d in docs) {
        if (d.id == widget.documentId) {
          docName = d.name;
          break;
        }
      }
    }
    return Column(
      children: [
        if (widget.documentId != null && docName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded,
                    size: 13, color: CoffeeColors.cacao),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Reading: $docName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: CoffeeColors.cacao,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: messages.isEmpty
              ? _EmptyAssistant(onAsk: _send)
              : SelectionArea(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) =>
                        _MessageBubble(message: messages[i]),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: _send,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Ask about this notebook…',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _busy ? null : () => _send(_controller.text),
                style: IconButton.styleFrom(
                  backgroundColor: CoffeeColors.caramel,
                  foregroundColor: CoffeeColors.espresso,
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyAssistant extends StatelessWidget {
  const _EmptyAssistant({required this.onAsk});

  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: CoffeeColors.cacao,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              'Ask anything about this notebook',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Answers are grounded in the PDFs in this notebook, with citations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  label: 'Summarize this chapter',
                  onTap: () => onAsk('Summarize this chapter'),
                ),
                _SuggestionChip(
                  label: 'Key terms',
                  onTap: () => onAsk('List the key terms and definitions.'),
                ),
                _SuggestionChip(
                  label: 'Explain a concept',
                  onTap: () => onAsk('Explain the main concepts simply.'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surfaceContainerLow,
      onPressed: onTap,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AssistantEntry message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isUser
              ? CoffeeColors.caramel.withValues(alpha: 0.85)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUser)
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: CoffeeColors.espresso,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReasoningBlock(text: message.thinking),
                  MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                      p: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: scheme.onSurface,
                      ),
                    ),
                    blockSyntaxes: latexBlockSyntaxes,
                    inlineSyntaxes: latexInlineSyntaxes,
                    builders: latexBuilders(
                      textStyle: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            if (message.citations.isNotEmpty)
              ...message.citations.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Source: $c',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isUser
                          ? CoffeeColors.espresso.withValues(alpha: 0.6)
                          : scheme.onSurfaceVariant,
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