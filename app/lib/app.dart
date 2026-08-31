import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ai/model_store.dart';
import 'core/db/app_database.dart';
import 'core/memory/memory_service.dart';
import 'core/settings/settings_storage.dart';
import 'core/state/theme_mode.dart';
import 'core/theme/app_theme.dart';
import 'docs/data_repair.dart';
import 'docs/rag_service.dart';
import 'features/home/home_shell.dart';

/// Root app. Wraps everything in a [ProviderScope] for state management.
class StudyCompanionApp extends ConsumerWidget {
  const StudyCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Restore persisted settings (AI on/off + active model) once.
    _bootstrap(ref);

    return MaterialApp(
      title: 'Moonlight Study',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider)
          ? ThemeMode.dark
          : ThemeMode.light,
      home: const HomeShell(),
    );
  }

    void _bootstrap(WidgetRef ref) {
    if (_bootstrapped) return;
    _bootstrapped = true;
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
      } catch (_) {
        // Repair is best-effort; the per-document Re-index action covers it.
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
  } catch (_) {
    // Best-effort; default stays on.
  }
}