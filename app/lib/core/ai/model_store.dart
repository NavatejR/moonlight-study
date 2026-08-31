import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/ai_engine.dart';
import '../ai/model_catalog.dart';
import '../ai/provider_config.dart';
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

    // Eagerly load the active model so chat/study features are ready.
    if (enabled) {
      ref.read(aiEngineProvider.notifier).loadActiveModel();
    }
  }
}