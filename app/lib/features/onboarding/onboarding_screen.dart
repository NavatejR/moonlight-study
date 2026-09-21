import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/model_catalog.dart';
import '../../core/db/app_database.dart';
import '../../core/settings/settings_storage.dart';
import '../../core/theme/colors.dart';
import '../../shared/widgets/coffee_card.dart';
import 'sample_import.dart';

/// First-run welcome wizard.
///
/// Introduces what Moonlight Study does, offers a model recommendation based
/// on the user's device, and lets them skip the tutorial entirely (it stays
/// available later from Settings → Replay tutorial).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _importing = false;

  static const _maxPages = 3;

  Future<void> _finish() async {
    setState(() => _importing = true);
    
    final db = ref.read(appDatabaseProvider);
    await importSampleDocument(db, ref);
    
    await ref
        .read(settingsProvider.notifier)
        .apply((s) => s.copyWith(onboardingComplete: true));
    
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _skip() => _finish();

  void _next() {
    if (_page < _maxPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? CoffeeColors.vinyl : CoffeeColors.crema;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const _Brand(),
                  const Spacer(),
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip tutorial',
                      style: TextStyle(
                        color: isDark ? CoffeeColors.foam : CoffeeColors.mocha,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _WelcomePage(),
                  _ModelsPage(),
                  _ReadingPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
              child: Row(
                children: [
                  _Dots(current: _page, count: _maxPages),
                  const Spacer(),
                  FilledButton(
                    onPressed: _importing ? null : _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: CoffeeColors.caramel,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _importing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_page == _maxPages - 1 ? 'Get started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.coffee_outlined, color: CoffeeColors.caramel, size: 20),
        const SizedBox(width: 8),
        Text(
          'Moonlight Study',
          style: TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: CoffeeColors.caramel.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.nightlight_round,
              size: 36,
              color: CoffeeColors.caramel,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'A calm place to study.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Moonlight Study turns the documents you already own into a '
            'private, on-device study companion. Read, highlight, take notes, '
            'generate flashcards, and ask questions grounded in your material '
            '— no accounts, no uploads, no internet required.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FeatureChip(
                icon: Icons.offline_bolt_outlined,
                label: '100% on-device',
              ),
              _FeatureChip(
                icon: Icons.privacy_tip_outlined,
                label: 'Private',
              ),
              _FeatureChip(
                icon: Icons.auto_stories_outlined,
                label: 'RAG answers',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModelsPage extends StatelessWidget {
  const _ModelsPage();

  @override
  Widget build(BuildContext context) {
    final recommended = ModelCatalog.recommendedForTypicalDevice;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pick a study buddy.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Moonlight Study runs small, efficient language models directly '
            'on your machine. Start with the recommended model — you can switch '
            'anytime from the Models screen.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24),
          CoffeeCard(
            padding: const EdgeInsets.all(18),
            child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: CoffeeColors.caramel),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommended: ${recommended.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${recommended.tagline} · ${recommended.sizeLabel} '
                          '· ${recommended.ramLabel}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'The first chat may take a few minutes to download a model. '
            'After that, everything works offline.',
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingPage extends StatelessWidget {
  const _ReadingPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ready when you are.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'A sample guide will be imported so you can try everything '
            'immediately. If you ever want to see this tour again, it lives '
            'under Settings → Replay tutorial.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FeatureChip(
                icon: Icons.sticky_note_2_outlined,
                label: 'Notes',
              ),
              _FeatureChip(
                icon: Icons.highlight_alt_outlined,
                label: 'Highlights',
              ),
              _FeatureChip(
                icon: Icons.style_outlined,
                label: 'Flashcards',
              ),
              _FeatureChip(
                icon: Icons.timer_outlined,
                label: 'Pomodoro',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CoffeeColors.caramel.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CoffeeColors.caramel.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: CoffeeColors.caramel),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? CoffeeColors.caramel : CoffeeColors.latte,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}