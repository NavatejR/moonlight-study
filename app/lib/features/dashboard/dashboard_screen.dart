import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ai/ai_engine.dart';
import '../../core/audio/ambience.dart';
import '../../core/state/navigation.dart';
import '../../core/state/theme_mode.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/vinyldisc.dart';
import '../../shared/widgets/coffee_card.dart';
import '../../study/pomodoro.dart';
import '../../study/study_actions.dart';
import '../notebooks/notebooks_provider.dart';
import '../reader/notes_library.dart';
import '../reader/reader_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final greeting = switch (now.hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };
    final date = DateFormat('EEEE · MMMM d').format(now);

    final notebooks = ref.watch(notebooksProvider).value ?? const [];
    final recent = ref.watch(recentNotesProvider).value ?? const [];
    final notesCount = ref.watch(notesCountProvider).value;
    final flashcards = ref.watch(flashcardsProvider).value ?? const [];
    final sessions = ref.watch(sessionsProvider).value ?? const [];

    final today = DateTime(now.year, now.month, now.day);
    final studiedToday = sessions
        .where((s) => s.done &&
            DateTime(s.date.year, s.date.month, s.date.day) == today)
        .fold<int>(0, (sum, s) => sum + s.minutes);

    final amb = ref.watch(ambienceProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: _Header(
                greeting: greeting,
                date: date,
                onToggleDark: () =>
                    ref.read(themeModeProvider.notifier).toggle(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _HeroFocusCard(amb: amb),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _QuickActions(recentNotebooks: notebooks)),
          SliverToBoxAdapter(
            child: _StatsStrip(
              notebookCount: notebooks.length,
              noteCount: notesCount ?? 0,
              flashcardCount: flashcards.length,
              minutesToday: studiedToday,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Recent notebooks',
              onViewAll: () =>
                  ref.read(appSectionProvider.notifier).select(AppSection.notebooks),
            ),
          ),
          if (notebooks.isEmpty)
            const SliverToBoxAdapter(child: _EmptyNotebooksCard())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _NotebookRow(
                  notebook: notebooks[i],
                  onTap: () => _openNotebook(context, notebooks[i].id),
                ),
                childCount: notebooks.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Continue studying',
              onViewAll: () =>
                  ref.read(appSectionProvider.notifier).select(AppSection.notebooks),
            ),
          ),
          if (recent.isEmpty)
            const SliverToBoxAdapter(child: _EmptyNotesCard())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _RecentNoteRow(
                  recent: recent[i],
                  onTap: () => _openNotebook(context, recent[i].notebookId),
                ),
                childCount: recent.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  void _openNotebook(BuildContext context, int notebookId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(notebookId: notebookId),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.date,
    required this.onToggleDark,
  });

  final String greeting;
  final String date;
  final VoidCallback onToggleDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting ☕',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        IconButton.filled(
          onPressed: onToggleDark,
          icon: const Icon(Icons.dark_mode_rounded),
          tooltip: 'Midnight espresso',
        ),
      ],
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.recentNotebooks});

  final List<NotebookView> recentNotebooks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> importPdf() async {
      final message = await ref.read(studyActionsProvider).importDocument();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(message ?? 'No file selected.')),
          );
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actions = <({IconData icon, String label, Color color, VoidCallback onTap})>[
      (
        icon: Icons.picture_as_pdf_rounded,
        label: 'Import PDF',
        color: const Color(0xFFC97B4A),
        onTap: importPdf,
      ),
      (
        icon: Icons.auto_awesome_rounded,
        label: 'Ask AI',
        color: CoffeeColors.sage,
        onTap: () =>
            ref.read(appSectionProvider.notifier).select(AppSection.chat),
      ),
      (
        icon: Icons.style_rounded,
        label: 'Flashcards',
        color: CoffeeColors.moss,
        onTap: () =>
            ref.read(appSectionProvider.notifier).select(AppSection.flashcards),
      ),
      (
        icon: Icons.library_music_rounded,
        label: 'Music',
        color: CoffeeColors.caramel,
        onTap: () =>
            ref.read(appSectionProvider.notifier).select(AppSection.music),
      ),
      (
        icon: Icons.menu_book_rounded,
        label: 'Notebooks',
        color: CoffeeColors.espresso,
        onTap: () =>
            ref.read(appSectionProvider.notifier).select(AppSection.notebooks),
      ),
      (
        icon: Icons.event_note_rounded,
        label: 'Planner',
        color: CoffeeColors.coffee,
        onTap: () =>
            ref.read(appSectionProvider.notifier).select(AppSection.planner),
      ),
      (
        icon: Icons.memory_rounded,
        label: 'Models',
        color: const Color(0xFF8B7BA8),
        onTap: () =>
            ref.read(appSectionProvider.notifier).select(AppSection.models),
      ),
      (
        icon: Icons.tune_rounded,
        label: 'Settings',
        color: const Color(0xFF7E8A99),
        onTap: () =>
            ref.read(appSectionProvider.notifier).select(AppSection.settings),
      ),
      (
        icon: Icons.queue_music_rounded,
        label: 'Ambience',
        color: const Color(0xFFD6A05C),
        onTap: () => ref.read(ambienceProvider.notifier).toggle(),
      ),
    ];

    if (!ref.watch(aiEnabledProvider)) {
      actions.removeWhere((a) => a.label == 'Ask AI');
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final a = actions[i];
          return _QuickActionTile(
            icon: a.icon,
            label: a.label,
            color: _adaptive(a.color, isDark),
            onTap: a.onTap,
          );
        },
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: CoffeeCard(
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.notebookCount,
    required this.noteCount,
    required this.flashcardCount,
    required this.minutesToday,
  });

  final int notebookCount;
  final int noteCount;
  final int flashcardCount;
  final int minutesToday;

  @override
  Widget build(BuildContext context) {
    final minutes = minutesToday < 60
        ? '$minutesToday min'
        : '${(minutesToday / 60).toStringAsFixed(1)} h';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.menu_book_rounded,
              value: '$notebookCount',
              label: 'Notebooks',
              iconColor: _adaptive(CoffeeColors.caramel, isDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.edit_note_rounded,
              value: '$noteCount',
              label: 'Notes',
              iconColor: _adaptive(CoffeeColors.moss, isDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.style_rounded,
              value: '$flashcardCount',
              label: 'Flashcards',
              iconColor: _adaptive(CoffeeColors.sage, isDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.timer_rounded,
              value: minutes,
              label: 'Today',
              iconColor: _adaptive(CoffeeColors.coffee, isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('View all'),
          ),
        ],
      ),
    );
  }
}

class _NotebookRow extends StatelessWidget {
  const _NotebookRow({required this.notebook, required this.onTap});

  final NotebookView notebook;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = notebook.documents.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: CoffeeCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: CoffeeGradients.espressoDusk,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notebook.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0
                        ? 'No PDFs yet'
                        : '$count PDF${count == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentNoteRow extends StatelessWidget {
  const _RecentNoteRow({required this.recent, required this.onTap});

  final RecentNote recent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d · h:mm a').format(recent.note.updatedAt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: CoffeeCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
                Icons.edit_note_rounded,
                size: 20,
                color: CoffeeColors.caramel),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recent.notebookTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _snippet(recent.note.content),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

String _snippet(String content) {
  final plain = content
      .replaceAll(RegExp(r'[#>*`_\[\]\-]'), ' ')
      .replaceAll('\n', ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  if (plain.isEmpty) return 'No text yet';
  return plain.length > 90 ? '${plain.substring(0, 90)}…' : plain;
}

class _EmptyNotebooksCard extends StatelessWidget {
  const _EmptyNotebooksCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: CoffeeColors.caramel),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No notebooks yet. Create one to start reading.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotesCard extends StatelessWidget {
  const _EmptyNotesCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: CoffeeColors.caramel),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your latest notes will appear here.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Brightens dark accent colors in dark mode so tiles stay legible.
Color _adaptive(Color color, bool dark) =>
    dark ? Color.lerp(color, Colors.white, 0.6)! : color;

// ---------------------------------------------------------------------------
// Pomodoro hero card (the original focus timer, kept as-is)
// ---------------------------------------------------------------------------

class _HeroFocusCard extends ConsumerWidget {
  const _HeroFocusCard({required this.amb});

  final AmbiState amb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomo = ref.watch(pomodoroProvider);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: CoffeeGradients.espressoDusk,
        boxShadow: [
          BoxShadow(
            color: CoffeeColors.espresso.withValues(alpha: 0.3),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _FocusDot(),
                    const SizedBox(width: 8),
                    Text(
                      pomo.isFocus ? 'FOCUS SESSION' : 'BREAK',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  pomo.label,
                  style: const TextStyle(
                    color: CoffeeColors.foam,
                    fontFamily: 'Fraunces',
                    fontSize: 52,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  pomo.running
                      ? '${pomo.phaseLabel} in progress'
                      : 'Pomodoro · one deep cup',
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: CoffeeColors.foam,
                        foregroundColor: CoffeeColors.espresso,
                      ),
                      onPressed: () {
                        ref.read(pomodoroProvider.notifier).toggle();
                        ref.read(ambienceProvider.notifier).toggle();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            pomo.running
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            pomo.running
                                ? 'Pause'
                                : pomo.isFocus
                                    ? 'Start focus'
                                    : 'Start break',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SkipButton(phase: pomo.phase),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (MediaQuery.sizeOf(context).width >= 520)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: VinylDisc(size: 108, spinning: amb.isPlaying),
            ),
        ],
      ),
    );
  }
}

class _FocusDot extends StatelessWidget {
  const _FocusDot();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (context, t, _) => Opacity(
        opacity: 0.4 + t * 0.6,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: CoffeeColors.sage,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends ConsumerWidget {
  const _SkipButton({required this.phase});

  final PomodoroPhase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skipTo =
        phase == PomodoroPhase.focus ? 'Skip to break' : 'Skip to focus';
    return IconButton(
      onPressed: () => ref.read(pomodoroProvider.notifier).skip(),
      style: IconButton.styleFrom(
        foregroundColor: Colors.white54,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      tooltip: skipTo,
      icon: Icon(
        phase == PomodoroPhase.focus
            ? Icons.skip_next_rounded
            : Icons.fast_rewind_rounded,
      ),
    );
  }
}