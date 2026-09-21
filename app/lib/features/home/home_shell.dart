import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/ai/ai_engine.dart';
import '../../core/state/navigation.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/vinyldisc.dart';
import '../../core/window/desktop_window.dart';
import '../chat/chat_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../models/models_screen.dart';
import '../music/music_screen.dart';
import '../notebooks/notebooks_screen.dart';
import '../planner/planner_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(appSectionProvider);
    final aiOn = ref.watch(aiEnabledProvider);
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 960;

    // Redirect away from the chat section when AI is disabled. Done via a
    // listener so we don't write provider state during build: the mutation
    // happens in a separate microtask/notification, letting Riverpod settle
    // its own state before the next frame.
    ref.listen(appSectionProvider, (previous, next) {
      if (!ref.context.mounted) return;
      if (!aiOn && next == AppSection.chat && previous != AppSection.dashboard) {
        ref.read(appSectionProvider.notifier).select(AppSection.dashboard);
      }
    });

    // Same guard as the listener, computed purely so the first frame already
    // shows the fallback instead of a blank chat panel.
    final effectiveSection =
        effectiveSectionFor(section, aiEnabled: aiOn);

    if (useRail) {
      return Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (DesktopWindow.isDesktop) const _WindowTitleBar(),
            Expanded(
              child: Row(
                children: [
                  _SideRail(section: effectiveSection),
                  Expanded(child: _screenFor(effectiveSection)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: _screenFor(effectiveSection),
      bottomNavigationBar: _CompactNav(section: effectiveSection),
    );
  }
}

/// The app's own window chrome: a full-width, theme-matched title bar above
/// the main UI. Entire strip is draggable; double-click toggles maximize.
class _WindowTitleBar extends StatelessWidget {
  const _WindowTitleBar();

  void _toggleMaximize() async {
    final manager = windowManager;
    if (await manager.isMaximized()) {
      await manager.unmaximize();
    } else {
      await manager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? CoffeeColors.warmDark : CoffeeColors.crema;
    final ink = isDark ? CoffeeColors.foam : CoffeeColors.espresso;

    return GestureDetector(
      onDoubleTap: _toggleMaximize,
      child: DragToMoveArea(
        child: Container(
          height: DesktopWindow.titleBarHeight,
          color: barColor,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              SizedBox(width: DesktopWindow.trafficLightInset),
              const Spacer(),
              if (!DesktopWindow.usesNativeWindowControls)
                _WindowControls(inkColor: ink, barColor: barColor),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowControls extends StatelessWidget {
  const _WindowControls({required this.inkColor, required this.barColor});

  final Color inkColor;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tooltip, VoidCallback onTap,
        {bool close = false}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Icon(
            icon,
            size: 15,
            color: close ? const Color(0xFFB03A2E) : inkColor,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.remove_rounded, 'Minimize', () => windowManager.minimize()),
        button(
          Icons.crop_square_rounded,
          'Maximize',
          () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        button(Icons.close_rounded, 'Close', () => windowManager.destroy(),
            close: true),
      ],
    );
  }
}

Widget _screenFor(AppSection section) => switch (section) {
      AppSection.dashboard => const DashboardScreen(),
      AppSection.notebooks => const NotebooksScreen(),
      AppSection.chat => const ChatScreen(),
      AppSection.flashcards => const FlashcardsScreen(),
      AppSection.planner => const PlannerScreen(),
      AppSection.music => const MusicScreen(),
      AppSection.models => const ModelsScreen(),
      AppSection.settings => const SettingsScreen(),
    };

class _SideRail extends ConsumerWidget {
  const _SideRail({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiOn = ref.watch(aiEnabledProvider);
    final items =
        aiOn ? _navItems : _navItems.where((i) => i.section != AppSection.chat).toList();
    return Container(
      width: 232,
      color: CoffeeColors.espresso,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RailHeader(),
          const SizedBox(height: 8),
          for (final item in items)
            _RailItem(
              item: item,
              selected: item.section == section,
              onTap: () =>
                  ref.read(appSectionProvider.notifier).select(item.section),
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: NowPlayingTile(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      child: Row(
        children: [
          const VinylDisc(size: 40, spinning: false),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Moonlight',
                style: TextStyle(
                  color: CoffeeColors.foam,
                  fontFamily: 'Fraunces',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'study',
                style: TextStyle(
                  color: CoffeeColors.caramel,
                  fontFamily: 'Fraunces',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.section, this.icon, this.label);
  final AppSection section;
  final IconData icon;
  final String label;
}

const _navItems = <_NavItem>[
  _NavItem(AppSection.dashboard, Icons.coffee_rounded, 'Dashboard'),
  _NavItem(AppSection.notebooks, Icons.menu_book_rounded, 'Notebooks'),
  _NavItem(AppSection.chat, Icons.forum_rounded, 'Study Chat'),
  _NavItem(AppSection.flashcards, Icons.style_rounded, 'Flashcards'),
  _NavItem(AppSection.planner, Icons.event_note_rounded, 'Planner'),
  _NavItem(AppSection.music, Icons.library_music_rounded, 'Music'),
  _NavItem(AppSection.models, Icons.memory_rounded, 'Models'),
  _NavItem(AppSection.settings, Icons.tune_rounded, 'Settings'),
];

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected
                  ? CoffeeColors.caramel.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? CoffeeColors.caramel : Colors.white54,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? CoffeeColors.foam : Colors.white60,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactNav extends ConsumerWidget {
  const _CompactNav({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiOn = ref.watch(aiEnabledProvider);
    const baseVisible = {
      AppSection.dashboard,
      AppSection.notebooks,
      AppSection.chat,
      AppSection.planner,
      AppSection.music,
    };
    final visible =
        aiOn ? baseVisible : baseVisible.difference({AppSection.chat});

    return Container(
      decoration: BoxDecoration(
        color: CoffeeColors.paper.withValues(alpha: 0.96),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in _navItems)
                if (visible.contains(item.section))
                  _CompactItem(
                    item: item,
                    selected: item.section == section,
                    onTap: () => ref
                        .read(appSectionProvider.notifier)
                        .select(item.section),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactItem extends StatelessWidget {
  const _CompactItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 22,
              color: selected ? CoffeeColors.caramel : CoffeeColors.cacao,
            ),
            const SizedBox(height: 2),
            Text(
              item.label.split(' ').first,
              style: TextStyle(
                fontSize: 10,
                color: selected ? CoffeeColors.espresso : CoffeeColors.cacao,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}