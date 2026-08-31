import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/music/music_folder.dart';
import '../../core/music/music_library.dart';
import '../../core/memory/memory_service.dart';
import '../../core/settings/settings_storage.dart';
import '../../core/theme/colors.dart';
import '../../shared/widgets/coffee_card.dart';
import '../../study/pomodoro.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Tune the player, reader, and study habits.',
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
            child: settings.when(
              data: (s) => _SettingsBody(settings: s),
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
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
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('PLAYER'),
          CoffeeCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _MusicFolderTile(path: settings.musicFolder),
                const Divider(height: 24),
                _SwitchSetting(
                  title: 'Auto-play on focus',
                  subtitle: 'Start the playlist when a pomodoro begins',
                  value: settings.autoPlayMusic,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .apply((s) => s.copyWith(autoPlayMusic: v)),
                ),
                const SizedBox(height: 8),
                _SliderSetting(
                  title: 'Default volume',
                  display: '${(settings.volume * 100).round()}%',
                  value: settings.volume,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .apply((s) => s.copyWith(volume: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader('READER'),
          CoffeeCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _SliderSetting(
                  title: 'PDF / notes split',
                  display: '${(settings.splitRatio * 100).round()}% / ${100 - (settings.splitRatio * 100).round()}%',
                  value: settings.splitRatio,
                  min: 0.25,
                  max: 0.75,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .apply((s) => s.copyWith(splitRatio: v)),
                ),
                const Divider(height: 24),
                _SegmentedSetting(
                  title: 'Fit mode',
                  value: settings.readerFitMode,
                  options: const {'fitWidth': 'Fit width', 'fitPage': 'Fit page'},
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .apply((s) => s.copyWith(readerFitMode: v)),
                ),
                const SizedBox(height: 16),
                _SegmentedSetting(
                  title: 'Reading theme',
                  value: settings.readingTheme,
                  options: const {
                    'paper': 'Paper',
                    'sepia': 'Sepia',
                    'midnight': 'Midnight',
                  },
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .apply((s) => s.copyWith(readingTheme: v)),
                ),
                const SizedBox(height: 16),
                _SwitchSetting(
                  title: 'Night reading',
                  subtitle: 'Invert white pages for low-light reading',
                  value: settings.readerDarkMode,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .apply((s) => s.copyWith(readerDarkMode: v)),
                ),
                const SizedBox(height: 16),
                _SegmentedSetting(
                  title: 'Highlight color',
                  value: settings.highlightColor,
                  options: const {
                    '#A3BFA6': 'Moss',
                    '#E4A97C': 'Amber',
                    '#C7B9E5': 'Lilac',
                    '#F0C8A0': 'Cream',
                  },
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .apply((s) => s.copyWith(highlightColor: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader('AI'),
          CoffeeCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _SwitchSetting(
                  title: 'Show citations',
                  subtitle: 'Tag answers with source chips',
                  value: settings.showCitations,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .apply((s) => s.copyWith(showCitations: v)),
                ),
                const SizedBox(height: 8),
                _SliderSetting(
                  title: 'Context depth',
                  display: '${settings.contextDepth} chunks',
                  value: settings.contextDepth.toDouble(),
                  min: 2,
                  max: 8,
                  divisions: 6,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .apply((s) => s.copyWith(contextDepth: v.toInt())),
                ),
                _SwitchSetting(
                  title: 'Lite mode',
                  subtitle: 'Stop offer AI generation on every action',
                  value: settings.liteMode,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .apply((s) => s.copyWith(liteMode: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader('MEMORY'),
          _MemoryCard(),
          const SizedBox(height: 24),
          _SectionHeader('STUDY'),
          CoffeeCard(
            padding: const EdgeInsets.all(18),
            child: _SegmentedSetting(
              title: 'Pomodoro length',
              value: settings.pomodoroMinutes.toString(),
              options: const {
                '15': '15 min',
                '25': '25 min',
                '45': '45 min',
                '60': '60 min',
              },
              onChanged: (v) {
                ref.read(settingsProvider.notifier).apply(
                    (s) => s.copyWith(pomodoroMinutes: int.parse(v)));
                ref.read(pomodoroProvider.notifier).reset();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10, top: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: CoffeeColors.caramel,
          fontSize: 11,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MusicFolderTile extends ConsumerWidget {
  const _MusicFolderTile({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: CoffeeColors.caramel.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.folder_rounded, color: CoffeeColors.coffee),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Music folder', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(
                path.isEmpty
                    ? 'No folder chosen'
                    : p.basename(path),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonal(
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () async {
            final folder = await ref.read(musicFolderBridgeProvider).pickFolder();
            if (folder.isNotEmpty) {
              await ref.read(settingsProvider.notifier).setMusicFolder(folder);
              ref.invalidate(libraryTracksProvider);
            }
          },
          child: const Text('Choose'),
        ),
      ],
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: CoffeeColors.moss,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.title,
    required this.display,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
  });

  final String title;
  final String display;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(display, style: const TextStyle(fontSize: 12.5, color: CoffeeColors.caramel)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: CoffeeColors.caramel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SegmentedSetting extends StatelessWidget {
  const _SegmentedSetting({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                selected: entry.key == value,
                selectedColor: CoffeeColors.caramel.withValues(alpha: 0.25),
                side: BorderSide(
                  color: entry.key == value
                      ? CoffeeColors.caramel
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
                onSelected: (_) => onChanged(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

class _MemoryCard extends ConsumerWidget {
  const _MemoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(memoriesEnabledProvider);

    return CoffeeCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SwitchSetting(
            title: 'Remember what I say',
            subtitle: 'AI uses notes about you to personalise answers',
            value: enabled,
            onChanged: (v) =>
                ref.read(memoriesEnabledProvider.notifier).set(v),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                final svc = ref.read(memoryServiceProvider);
                await svc.clear();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Memories cleared')),
                  );
                }
              },
              child: const Text('Clear memories'),
            ),
          ),
        ],
      ),
    );
  }
}