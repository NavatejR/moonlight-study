import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_engine.dart';
import '../../core/db/app_database.dart';
import '../../core/settings/settings_storage.dart';
import '../../core/theme/colors.dart';
import '../../shared/widgets/coffee_card.dart';
import '../../study/study_actions.dart';
import '../notebooks/notebooks_provider.dart';

class FlashcardsScreen extends ConsumerWidget {
  const FlashcardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = ref.watch(flashcardsProvider);
    final groups = ref.watch(flashcardGroupsProvider);

    return Scaffold(
      body: deck.when(
        data: (cards) => groups.when(
          data: (groups) => _FlashcardsBody(cards: cards, groups: groups),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

/// Selected flashcard group on the Flashcards screen. `null` = all cards,
/// `0` = the "Ungrouped" bucket, otherwise a [FlashcardGroup.id].
final _selectedGroupProvider =
    NotifierProvider<_SelectedGroupNotifier, int?>(_SelectedGroupNotifier.new);

class _SelectedGroupNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? value) {
    state = value;
    ref.read(_cardIndexProvider.notifier).reset();
    ref.read(_showAnswerProvider.notifier).reset();
  }
}

/// Whole Flashcards page: header, group bar, actions and the deck/empty state.
class _FlashcardsBody extends ConsumerWidget {
  const _FlashcardsBody({required this.cards, required this.groups});

  final List<Flashcard> cards;
  final List<FlashcardGroup> groups;

  List<Flashcard> _visible(int? selected) {
    if (selected == null) return cards;
    if (selected == 0) return cards.where((c) => c.groupId == null).toList();
    return cards.where((c) => c.groupId == selected).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedGroupProvider);
    final generating = ref.watch(_generatingProvider);
    final aiOn = ref.watch(aiEnabledProvider);
    final visible = _visible(selected);
    // Cards land in the selected group (skip the All/Ungrouped buckets).
    final targetGroupId = (selected != null && selected > 0) ? selected : null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Flashcards',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${cards.length} card${cards.length == 1 ? '' : 's'} · generated from your notes',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 12),
          _GroupBar(
            groups: groups,
            selected: selected,
            onSelect: (v) =>
                ref.read(_selectedGroupProvider.notifier).select(v),
            onCreate: () => _createGroupDialog(context, ref),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: generating
                    ? null
                    : () => _addFlashcardDialog(
                          context,
                          ref,
                          groupId: targetGroupId,
                        ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add flashcard'),
              ),
              if (aiOn) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: generating
                      ? null
                      : () => _generateDeck(
                            context,
                            ref,
                            groupId: targetGroupId,
                          ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Generate more'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _EmptyDeck(generating: generating),
                    ),
                  )
                : visible.isEmpty
                    ? _EmptyGroup(generating: generating)
                    : _DeckView(cards: visible),
          ),
        ],
      ),
    );
  }
}

/// Row of group chips (All / Ungrouped / each group) plus a "+ new" action.
class _GroupBar extends StatelessWidget {
  const _GroupBar({
    required this.groups,
    required this.selected,
    required this.onSelect,
    required this.onCreate,
  });

  final List<FlashcardGroup> groups;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _GroupChip(label: 'All', selected: selected == null, onTap: () => onSelect(null)),
          _GroupChip(
            label: 'Ungrouped',
            selected: selected == 0,
            onTap: () => onSelect(0),
          ),
          for (final g in groups)
            _GroupChip(
              label: g.title,
              selected: selected == g.id,
              onTap: () => onSelect(g.id),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Center(
              child: IconButton(
                tooltip: 'New group',
                onPressed: onCreate,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_chart_rounded, size: 20),
                color: CoffeeColors.cacao,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: ChoiceChip(
          label: Text(label, overflow: TextOverflow.ellipsis),
          selected: selected,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => onTap(),
        ),
      ),
    );
  }
}

/// The active deck (cards already filtered by the selected group).
class _DeckView extends ConsumerWidget {
  const _DeckView({required this.cards});

  final List<Flashcard> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_cardIndexProvider);
    final showAnswer = ref.watch(_showAnswerProvider);
    final generating = ref.watch(_generatingProvider);
    final safeIndex = index.clamp(0, cards.length - 1);

    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _CardFace(
                card: cards[safeIndex],
                showAnswer: showAnswer,
                onFlip: () => ref.read(_showAnswerProvider.notifier).toggle(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DeckProgress(cards: cards),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Delete card',
              onPressed: generating
                  ? null
                  : () => _deleteCardDialog(context, ref, cards[safeIndex]),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: CoffeeColors.cacao,
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    required this.showAnswer,
    required this.onFlip,
  });

  final Flashcard card;
  final bool showAnswer;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onFlip,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: showAnswer ? 1 : 0),
        duration: const Duration(milliseconds: 350),
        builder: (context, t, _) {
          final angle = t * 3.14159;
          final flip = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle);
          return Transform(
            alignment: Alignment.center,
            transform: flip,
            child: angle > 1.57
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.14159),
                    child: _CardBack(card: card),
                  )
                : _CardFront(card: card),
          );
        },
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    return CoffeeCard(
      padding: const EdgeInsets.all(32),
      child: SizedBox(
        height: 300,
        width: double.infinity,
        child: Column(
          children: [
            const Text(
              'QUESTION · tap to flip',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                color: CoffeeColors.coffee,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              card.question,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            const Icon(Icons.autorenew_rounded, color: CoffeeColors.caramel, size: 22),
          ],
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    return CoffeeCard(
      padding: const EdgeInsets.all(32),
      color: CoffeeColors.espresso,
      child: SizedBox(
        height: 300,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ANSWER',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                color: CoffeeColors.caramel,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              card.answer,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: CoffeeColors.foam,
                  ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _SelfRatingChip(
                  icon: Icons.replay_rounded,
                  label: 'Again',
                  color: CoffeeColors.caramel,
                ),
                _SelfRatingChip(
                  icon: Icons.check_rounded,
                  label: 'Good',
                  color: CoffeeColors.moss,
                ),
                _SelfRatingChip(
                  icon: Icons.done_all_rounded,
                  label: 'Easy',
                  color: CoffeeColors.sage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelfRatingChip extends StatelessWidget {
  const _SelfRatingChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: color),
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _DeckProgress extends ConsumerWidget {
  const _DeckProgress({required this.cards});

  final List<Flashcard> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_cardIndexProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => ref.read(_cardIndexProvider.notifier).previous(),
          icon: const Icon(Icons.chevron_left_rounded),
          color: CoffeeColors.cacao,
        ),
        const SizedBox(width: 8),
        Text(
          '${index + 1} / ${cards.length}',
          style: const TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            ref.read(_cardIndexProvider.notifier).next(cards.length);
            ref.read(_showAnswerProvider.notifier).reset();
          },
          icon: const Icon(Icons.chevron_right_rounded),
          color: CoffeeColors.cacao,
        ),
      ],
    );
  }
}

/// Shown when the selected group has no cards yet.
class _EmptyGroup extends ConsumerWidget {
  const _EmptyGroup({required this.generating});

  final bool generating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiOn = ref.watch(aiEnabledProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: CoffeeCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: CoffeeColors.sage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: generating
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.folder_copy_outlined,
                          size: 30,
                          color: CoffeeColors.moss,
                        ),
                ),
                const SizedBox(height: 18),
                Text(
                  generating ? 'Brewing cards…' : 'No cards in this group yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  generating
                      ? 'The local model is turning your notes into flashcards.'
                      : !aiOn
                          ? 'Add flashcards to this group manually, or enable AI to generate them.'
                          : 'Generate more cards or add a flashcard to fill '
                              'this group out.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!generating && aiOn)
                  TextButton.icon(
                    onPressed: () => _generateDeck(context, ref),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Generate into group'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyDeck extends ConsumerWidget {
  const _EmptyDeck({required this.generating});

  final bool generating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiOn = ref.watch(aiEnabledProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: CoffeeCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: CoffeeColors.sage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: generating
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.style_rounded, size: 30, color: CoffeeColors.moss),
                ),
                const SizedBox(height: 18),
                Text(
                  generating ? 'Brewing cards…' : 'Deck is empty',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  generating
                      ? 'The local model is turning your notes into flashcards.'
                      : !aiOn
                          ? 'Add flashcards manually, or enable AI to generate them from your notes.'
                          : 'Add flashcards manually, or pick a notebook to brew some.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!generating && aiOn)
                  FilledButton.icon(
                    onPressed: () => _generate(context, ref),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Generate deck'),
                    style: FilledButton.styleFrom(
                      backgroundColor: CoffeeColors.moss,
                    ),
                  ),
                if (!generating && !aiOn)
                  FilledButton.icon(
                    onPressed: () => _addFlashcardDialog(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add flashcard'),
                    style: FilledButton.styleFrom(
                      backgroundColor: CoffeeColors.moss,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _generate(BuildContext context, WidgetRef ref) =>
      _generateDeck(context, ref);
}

/// Shared deck-generation flow: pick a notebook + PDFs, generate and persist.
/// New cards land in [groupId] when given (e.g. the selected chapter).
Future<void> _generateDeck(
  BuildContext context,
  WidgetRef ref, {
  int? groupId,
}) async {
  final source = await showDialog<_DeckSource>(
    context: context,
    builder: (context) => const _DeckSourcePicker(),
  );
  if (source == null || !context.mounted) return;

  ref.read(_generatingProvider.notifier).set(true);
  try {
    final actions = ref.read(studyActionsProvider);
    final cards = await actions.generateFlashcards(
      count: 6,
      documentIds: source.documentIds,
    );
    if (cards.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No indexed text found for the selected PDFs — add them to a '
              'notebook and re-import, then retry.',
            ),
          ),
        );
      }
      return;
    }
    await actions.saveFlashcards(source.documentIds.first, cards,
        groupId: groupId);
    final storage = ref.read(settingsStorageProvider);
    await storage.setPref(
      'lastDeckDocumentId',
      '${source.documentIds.first}',
    );
  } finally {
    ref.read(_generatingProvider.notifier).set(false);
  }
}

/// Dialog to manually author a new flashcard (question + answer).
Future<void> _addFlashcardDialog(
  BuildContext context,
  WidgetRef ref, {
  int? groupId,
}) async {
  final questionCtrl = TextEditingController();
  final answerCtrl = TextEditingController();
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: const Text(
        'New flashcard',
        style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: questionCtrl,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answerCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Answer',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final q = questionCtrl.text.trim();
            final a = answerCtrl.text.trim();
            if (q.isNotEmpty && a.isNotEmpty) {
              Navigator.of(context).pop((q, a));
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (result == null || !context.mounted) return;

  final storage = ref.read(settingsStorageProvider);
  final saved = await storage.getPref('lastDeckDocumentId');
  await ref.read(studyActionsProvider).addFlashcard(
        question: result.$1,
        answer: result.$2,
        documentId: int.tryParse(saved ?? ''),
        groupId: groupId,
      );
}

/// The notebook + PDFs a generated deck should be built from.
class _DeckSource {
  const _DeckSource({required this.notebookTitle, required this.documentIds});

  final String notebookTitle;
  final Set<int> documentIds;
}

/// Asks for a name for a new flashcard group (e.g. "Chapter 4").
Future<void> _createGroupDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final title = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: const Text(
        'New group',
        style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Group name',
            hintText: 'e.g. Chapter 4',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.of(context).pop(controller.text.trim());
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
  if (title == null || title.isEmpty || !context.mounted) return;
  final id = await ref.read(studyActionsProvider).createFlashcardGroup(title);
  if (context.mounted) {
    ref.read(_selectedGroupProvider.notifier).select(id);
  }
}

/// Confirms and removes a flashcard.
Future<void> _deleteCardDialog(
  BuildContext context,
  WidgetRef ref,
  Flashcard card,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: const Text(
        'Delete card?',
        style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w600),
      ),
      content: const Text('This removes the flashcard permanently.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await ref.read(studyActionsProvider).deleteFlashcard(card.id);
  ref.read(_cardIndexProvider.notifier).reset();
}

/// Asks which notebook and which of its PDFs to generate a deck from.
class _DeckSourcePicker extends ConsumerStatefulWidget {
  const _DeckSourcePicker();

  @override
  ConsumerState<_DeckSourcePicker> createState() => _DeckSourcePickerState();
}

class _DeckSourcePickerState extends ConsumerState<_DeckSourcePicker> {
  int? _notebookId;
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final notebooks = ref.watch(notebooksProvider);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: scheme.surface,
      title: const Text(
        'Generate deck from',
        style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 430,
        child: notebooks.when(
          loading: () => const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (list) {
            if (list.isEmpty) {
              return const Text(
                'No notebooks yet — create one and add PDFs to it first.',
              );
            }
            final notebookId = _notebookId ?? list.first.id;
            final docs = ref.watch(notebookDocumentsProvider(notebookId));

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notebook', style: textTheme.labelLarge),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: notebookId,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final n in list)
                      DropdownMenuItem(
                        value: n.id,
                        child: Text(
                          n.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() {
                      _notebookId = id;
                      _selected.clear();
                    });
                  },
                ),
                const SizedBox(height: 14),
                Text('PDFs', style: textTheme.labelLarge),
                const SizedBox(height: 6),
                Flexible(
                  child: docs.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('Error: $e'),
                    data: (docList) {
                      if (docList.isEmpty) {
                        return const Text('This notebook has no PDFs yet.');
                      }
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final doc in docList)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                value: _selected.contains(doc.id),
                                title: Text(
                                  doc.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked ?? false) {
                                      _selected.add(doc.id);
                                    } else {
                                      _selected.remove(doc.id);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _canGenerate(),
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('Generate'),
        ),
      ],
    );
  }

  VoidCallback? _canGenerate() {
    final notebooks = ref.read(notebooksProvider).value ?? const [];
    if (notebooks.isEmpty) return null;
    final notebookId = _notebookId ?? notebooks.first.id;
    final docs = ref.read(notebookDocumentsProvider(notebookId)).value ?? const [];
    if (docs.isEmpty) return null;
    // When no notebook was explicitly chosen we default to every PDF in it.
    if (_notebookId == null) {
      return () => Navigator.of(context).pop(
            _DeckSource(
              notebookTitle: notebooks.first.title,
              documentIds: {for (final d in docs) d.id},
            ),
          );
    }
    if (_selected.isEmpty) return null;
    return () => Navigator.of(context).pop(
          _DeckSource(notebookTitle: '', documentIds: Set.of(_selected)),
        );
  }
}

final _cardIndexProvider =
    NotifierProvider<_CardIndexNotifier, int>(_CardIndexNotifier.new);
final _showAnswerProvider =
    NotifierProvider<_ShowAnswerNotifier, bool>(_ShowAnswerNotifier.new);
final _generatingProvider =
    NotifierProvider<_GeneratingNotifier, bool>(_GeneratingNotifier.new);

class _CardIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void next(int length) {
    if (state + 1 < length) state += 1;
  }

  void previous() {
    if (state > 0) state -= 1;
  }

  void reset() => state = 0;
}

class _ShowAnswerNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void reset() => state = false;
}

class _GeneratingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}