import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../core/music/music_folder.dart';
import '../../core/music/music_library.dart';
import '../../core/memory/memory_service.dart';
import '../../core/settings/settings_storage.dart';
import '../../core/theme/colors.dart';
import '../../core/updates/update_service.dart';
import '../../shared/widgets/coffee_card.dart';
import '../../study/pomodoro.dart';
import '../onboarding/onboarding_screen.dart';
import 'logs_screen.dart';

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
                const Divider(height: 24),
                _HuggingFaceTokenField(settings: settings),
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
          const SizedBox(height: 24),
          _SectionHeader('SUPPORT'),
          CoffeeCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.touch_app_outlined),
                  title: const Text('Replay tutorial'),
                  subtitle: const Text('See the welcome tour again'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OnboardingScreen(),
                    ),
                  ),
                ),
                const Divider(height: 16),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('View logs'),
                  subtitle: const Text('Inspect app logs for troubleshooting'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LogsScreen()),
                  ),
                ),
                const Divider(height: 16),
                const _UpdateCheckTile(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateCheckTile extends ConsumerWidget {
  const _UpdateCheckTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(updateCheckProvider);

    String subtitle;
    Widget trailing = const Icon(Icons.chevron_right);
    VoidCallback? onTap;

    if (async.isLoading) {
      subtitle = 'Checking for updates…';
      trailing = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (async.hasError || async.value?.status == UpdateStatus.checkFailed) {
      subtitle = async.value?.error ??
          'Could not reach the update feed. Tap to retry.';
      onTap = () async {
        await ref.read(updateCheckProvider.notifier).runCheck();
        if (!context.mounted) return;
        _showUpdateResult(context, ref.read(updateCheckProvider).value);
      };
    } else if (async.value?.hasUpdate ?? false) {
      final result = async.value!;
      subtitle = 'Version ${result.latestVersion} is available';
      trailing = const Icon(Icons.download_outlined);
      onTap = () => _openDownload(context, result.downloadUrl);
    } else {
      subtitle = 'You\u2019re on the latest version';
    }

    return ListTile(
      leading: const Icon(Icons.system_update_alt_outlined),
      title: const Text('Check for updates'),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _showUpdateResult(BuildContext context, UpdateCheckResult? result) {
    if (result == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.hasUpdate
            ? 'Update ${result.latestVersion} is available.'
            : 'You\u2019re on the latest version.'),
        duration: const Duration(seconds: 4),
      ),
    );
    if (result.hasUpdate) _openDownload(context, result.downloadUrl);
  }

  Future<void> _openDownload(BuildContext context, String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return;
    }
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open the link.')));
    }
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

/// Hugging Face access token field. Some popular models live behind gated
/// repositories (e.g. Llama, Qwen3); entering a read token here lets those
/// downloads authenticate. Optional for all public catalog models.
class _HuggingFaceTokenField extends ConsumerStatefulWidget {
  const _HuggingFaceTokenField({required this.settings});

  final AppSettings settings;

  @override
  ConsumerState<_HuggingFaceTokenField> createState() =>
      _HuggingFaceTokenFieldState();
}

class _HuggingFaceTokenFieldState
    extends ConsumerState<_HuggingFaceTokenField> {
  late final TextEditingController _controller;
  bool _obscured = true;
  bool _saved = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.settings.huggingFaceToken);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(settingsProvider.notifier).apply(
          (s) => s.copyWith(huggingFaceToken: _controller.text.trim()),
        );
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hugging Face token saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Hugging Face token (optional)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (!_saved) ...[
              const SizedBox(width: 8),
              Text(
                'unsaved',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'For gated model repositories. Get a read token from '
          'huggingface.co/settings/tokens — never shares data; stays on your machine.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                obscureText: _obscured,
                onChanged: (_) => setState(() => _saved = false),
                decoration: InputDecoration(
                  hintText: 'hf_...',
                  isDense: true,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _saved ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: CoffeeColors.caramel,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}