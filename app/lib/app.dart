import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ai/model_store.dart';
import 'core/db/app_database.dart';
import 'core/logging/app_logger.dart';
import 'core/memory/memory_service.dart';
import 'core/settings/settings_storage.dart';
import 'core/state/theme_mode.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';
import 'core/updates/update_service.dart';
import 'core/window/desktop_window.dart';
import 'docs/data_repair.dart';
import 'docs/rag_service.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';

/// Root app. Wraps everything in a [ProviderScope] for state management.
class StudyCompanionApp extends ConsumerWidget {
  const StudyCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Restore persisted settings (AI on/off + active model) once.
    _bootstrap(ref);

    final settings = ref.watch(settingsProvider);
    final isDark = ref.watch(themeModeProvider);

    // Keep the native macOS title-bar strip matched to the theme. Side-effect
    // only (a platform channel push, no rebuild dependency), so it lives in a
    // post-frame callback instead of the build tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DesktopWindow.setWindowBackgroundColor(
          isDark ? CoffeeColors.warmDark : CoffeeColors.crema);
    });

    return MaterialApp(
      title: 'Moonlight Study',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider)
          ? ThemeMode.dark
          : ThemeMode.light,
      home: settings.maybeWhen(
        data: (s) =>
            s.onboardingComplete ? const HomeShell() : const OnboardingScreen(),
        orElse: () => const HomeShell(),
      ),
    );
  }

  void _bootstrap(WidgetRef ref) {
    if (_bootstrapped) return;
    _bootstrapped = true;

    logger.info('App bootstrapping started');

    final loader = SettingsLoader(ref);
    loader.load();
    _restoreMemoryToggle(ref);

    // One-time startup repair: dedupe document rows and re-index any PDF that
    // has no chunks (adding OCR'd text when the embedded text is missing).
    Future<void>(() async {
      try {
        final db = ref.read(appDatabaseProvider);
        final rag = ref.read(ragServiceProvider);
        await repairLibrary(db, rag);
        logger.info('Library repair completed successfully');
      } catch (e, stackTrace) {
        logger.error('Library repair failed (best-effort, non-fatal)', error: e, stackTrace: stackTrace);
        // Repair is best-effort; the per-document Re-index action covers it.
      }
    });

    // One-time background update check (non-fatal; surfaced in Settings).
    // Deliberately quiet on startup — a banner/nag can come later.
    Future<void>(() async {
      try {
        await ref.read(updateCheckProvider.notifier).runCheck();
      } catch (e, stackTrace) {
        // Offline or feed unreachable; Settings retry covers it.
        logger.warning('Background update check failed', error: e, stackTrace: stackTrace);
      }
    });
  }

  static bool _bootstrapped = false;
}

/// Restores the memory-system toggle from the Drift settings KV table.
Future<void> _restoreMemoryToggle(WidgetRef ref) async {
  try {
    final storage = ref.read(settingsStorageProvider);
    final stored = await storage.getPref('memories_enabled');
    if (stored != null) {
      ref.read(memoriesEnabledProvider.notifier).set(stored == 'true');
    }
  } catch (e, stackTrace) {
    // Best-effort; default stays on.
    logger.warning('Failed to restore memory toggle', error: e, stackTrace: stackTrace);
  }
}