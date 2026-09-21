import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/ai_engine.dart';
import '../ai/model_catalog.dart';
import '../ai/provider_config.dart';
import '../logging/app_logger.dart';
import '../settings/settings_storage.dart';
/// Persists user choices about models and AI.
class ModelStore {
  ModelStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kEnabled = 'ai_enabled';
  static const _kActiveModel = 'active_model_id';

  bool get aiEnabled => _prefs.getBool(_kEnabled) ?? true;

  Future<void> setAiEnabled(bool value) async {
    await _prefs.setBool(_kEnabled, value);
  }

  String get activeModelId =>
      _prefs.getString(_kActiveModel) ?? ModelCatalog.qwenVl.id;

  Future<void> setActiveModelId(String id) async {
    await _prefs.setString(_kActiveModel, id);
  }
}

final modelStoreProvider = FutureProvider<ModelStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return ModelStore(prefs);
});

/// Rehydrates [aiEnabledProvider] and [activeModelProvider] from disk on
/// startup. Called once from the app root before the UI settles.
class SettingsLoader {
  SettingsLoader(this.ref);

  final WidgetRef ref;

  Future<void> load() async {
    final store = await ref.read(modelStoreProvider.future);
    final enabled = store.aiEnabled;
    ref.read(aiEnabledProvider.notifier).set(enabled);

    final entry = ModelCatalog.byId(store.activeModelId);
    ref.read(activeModelProvider.notifier).setFromDisk(entry);

    // Rehydrate external provider settings from SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    ref.read(useExternalProviderProvider.notifier).set(
        prefs.getBool('use_external_provider') ?? false);
    ref.read(externalProviderConfigProvider.notifier).setFromDisk(
        ExternalProviderStore(prefs).load());

    // Touch settings up front so the Drift DB migrates/opens and the music
    // folder's security scope is re-armed before any screen reads them.
    unawaited(ref.read(settingsProvider.future));

    // Defer the active-model load until after the first frame (plus a short
    // grace period) so the window paints instantly and the heavy llama load
    // never stalls launch. Chat/OCR/embedding call sites share the same
    // single-flight ensureModelLoaded() (see ai_engine.dart), so nothing
    // regresses if the model is needed before the timer fires.
    if (enabled) {
      final notifier = ref.read(aiEngineProvider.notifier);
      unawaited(_scheduleDeferredLoad(notifier));
    }
  }

  /// Loads the model after the first frame + a grace delay. Fire-and-forget;
  /// failures are non-fatal and any later model use retries the load.
  Future<void> _scheduleDeferredLoad(AiEngineNotifier notifier) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 2000));
      if (!ref.context.mounted) return;
      await notifier.ensureModelLoaded();
    } catch (e, stackTrace) {
      logger.warning('Deferred model load skipped', error: e, stackTrace: stackTrace);
    }
  }
}