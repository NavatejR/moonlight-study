import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which cloud provider backend to use for the external chat endpoint.
enum ExternalProviderType {
  openai,
  anthropic,
  custom;

  String get label {
    switch (this) {
      case ExternalProviderType.openai:
        return 'OpenAI';
      case ExternalProviderType.anthropic:
        return 'Anthropic';
      case ExternalProviderType.custom:
        return 'Custom';
    }
  }

  String get defaultBaseUrl {
    switch (this) {
      case ExternalProviderType.openai:
        return 'https://api.openai.com/v1';
      case ExternalProviderType.anthropic:
        return 'https://api.anthropic.com';
      case ExternalProviderType.custom:
        return '';
    }
  }

  String get defaultModel {
    switch (this) {
      case ExternalProviderType.openai:
        return 'gpt-4o-mini';
      case ExternalProviderType.anthropic:
        return 'claude-3-haiku-20240307';
      case ExternalProviderType.custom:
        return '';
    }
  }
}

/// Configuration for an external (non-on-device) AI endpoint.
class ExternalProviderConfig {
  const ExternalProviderConfig({
    this.provider = ExternalProviderType.openai,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
  });

  final ExternalProviderType provider;
  final String baseUrl;
  final String apiKey;
  final String model;

  /// Whether this config is ready to use (has at least a URL and model).
  bool get isConfigured => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  ExternalProviderConfig copyWith({
    ExternalProviderType? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) =>
      ExternalProviderConfig(
        provider: provider ?? this.provider,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExternalProviderConfig &&
          runtimeType == other.runtimeType &&
          provider == other.provider &&
          baseUrl == other.baseUrl &&
          apiKey == other.apiKey &&
          model == other.model;

  @override
  int get hashCode => Object.hash(provider, baseUrl, apiKey, model);
}

/// Persists external provider configuration in SharedPreferences.
class ExternalProviderStore {
  ExternalProviderStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kProvider = 'ext_provider';
  static const _kBaseUrl = 'ext_base_url';
  static const _kApiKey = 'ext_api_key';
  static const _kModel = 'ext_model';

  ExternalProviderConfig load() {
    final providerName = _prefs.getString(_kProvider) ?? 'openai';
    final provider = ExternalProviderType.values.firstWhere(
      (p) => p.name == providerName,
      orElse: () => ExternalProviderType.openai,
    );
    return ExternalProviderConfig(
      provider: provider,
      baseUrl: _prefs.getString(_kBaseUrl) ?? '',
      apiKey: _prefs.getString(_kApiKey) ?? '',
      model: _prefs.getString(_kModel) ?? '',
    );
  }

  Future<void> save(ExternalProviderConfig config) async {
    await _prefs.setString(_kProvider, config.provider.name);
    await _prefs.setString(_kBaseUrl, config.baseUrl);
    await _prefs.setString(_kApiKey, config.apiKey);
    await _prefs.setString(_kModel, config.model);
  }
}

final externalProviderStoreProvider =
    FutureProvider<ExternalProviderStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return ExternalProviderStore(prefs);
});

final externalProviderConfigProvider = NotifierProvider<
    ExternalProviderConfigNotifier,
    ExternalProviderConfig>(ExternalProviderConfigNotifier.new);

class ExternalProviderConfigNotifier
    extends Notifier<ExternalProviderConfig> {
  @override
  ExternalProviderConfig build() => const ExternalProviderConfig();

  void setFromDisk(ExternalProviderConfig config) {
    if (state != config) state = config;
  }

  Future<void> update(ExternalProviderConfig config) async {
    state = config;
    final store = await ref.read(externalProviderStoreProvider.future);
    await store.save(config);
  }
}

/// Whether to use the external provider instead of on-device models.
final useExternalProviderProvider =
    NotifierProvider<UseExternalNotifier, bool>(UseExternalNotifier.new);

class UseExternalNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_external_provider', value);
  }
}
