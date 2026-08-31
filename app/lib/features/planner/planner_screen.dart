import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/audio/ambience.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/colors.dart';
import '../../shared/widgets/coffee_card.dart';
import '../../study/pomodoro.dart';
import '../../study/study_actions.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final pomo = ref.watch(pomodoroProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSession(context, ref),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Add session'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Study Planner',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sessions, decks, and exam countdowns in one place.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _FocusCard(pomo: pomo),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          sessions.when(
            data: (rows) => rows.isEmpty
                ? const SliverToBoxAdapter(child: _EmptyPlanner())
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _SessionRow(session: rows[i]),
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: $e'),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  void _addSession(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            date: DateTime.now(),
            title: 'Focus session',
          ),
        );
  }
}

class _FocusCard extends ConsumerWidget {
  const _FocusCard({required this.pomo});

  final PomodoroState pomo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
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
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: CoffeeColors.sage,
                        shape: BoxShape.circle,
                      ),
                    ),
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
                            pomo.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                    IconButton(
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      onPressed: () => ref.read(pomodoroProvider.notifier).reset(),
                      icon: const Icon(Icons.replay_rounded),
                      tooltip: 'Reset',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlanner extends StatelessWidget {
  const _EmptyPlanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: CoffeeCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.event_note_rounded, color: CoffeeColors.sage, size: 40),
            const SizedBox(height: 12),
            Text('No sessions yet', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Add a focus session to start planning your week.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.session});

  final StudySession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CoffeeCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: session.done
                  ? CoffeeColors.sage.withValues(alpha: 0.18)
                  : CoffeeColors.caramel.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              DateFormat('HH:mm').format(session.date),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: session.done ? CoffeeColors.moss : CoffeeColors.coffee,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                Text(
                  '${session.minutes} min',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: session.done,
            activeColor: CoffeeColors.moss,
            onChanged: (v) async {
              final db = ref.read(appDatabaseProvider);
              await (db.update(db.studySessions)..where((t) => t.id.equals(session.id)))
                  .write(StudySessionsCompanion(done: Value(v ?? false)));
            },
          ),
        ],
      ),
    );
  }
}