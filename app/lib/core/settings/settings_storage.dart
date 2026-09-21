import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../music/music_folder.dart';

/// Typed app settings, backed by the Drift [Settings] table.
class AppSettings {
  const AppSettings({
    this.musicFolder = '',
    this.autoPlayMusic = false,
    this.volume = 0.65,
    this.splitRatio = 0.55,
    this.readerFitMode = 'fitWidth',
    this.readingTheme = 'paper',
    this.highlightColor = '#A3BFA6',
    this.showCitations = true,
    this.contextDepth = 4,
    this.pomodoroMinutes = 25,
    this.liteMode = false,
    this.readerDarkMode = false,
    this.onboardingComplete = false,
    this.huggingFaceToken = '',
  });

  final String musicFolder;
  final bool autoPlayMusic;
  final double volume;
  final double splitRatio;
  final String readerFitMode; // 'fitWidth' | 'fitPage'
  final String readingTheme; // 'paper' | 'sepia' | 'midnight'
  final String highlightColor;
  final bool showCitations;
  final int contextDepth;
  final int pomodoroMinutes;
  final bool liteMode;
  final bool readerDarkMode;
  final bool onboardingComplete;
  final String huggingFaceToken;

  AppSettings copyWith({
    String? musicFolder,
    bool? autoPlayMusic,
    double? volume,
    double? splitRatio,
    String? readerFitMode,
    String? readingTheme,
    String? highlightColor,
    bool? showCitations,
    int? contextDepth,
    int? pomodoroMinutes,
    bool? liteMode,
    bool? readerDarkMode,
    bool? onboardingComplete,
    String? huggingFaceToken,
  }) =>
      AppSettings(
        musicFolder: musicFolder ?? this.musicFolder,
        autoPlayMusic: autoPlayMusic ?? this.autoPlayMusic,
        volume: volume ?? this.volume,
        splitRatio: splitRatio ?? this.splitRatio,
        readerFitMode: readerFitMode ??
            this.readerFitMode,
        readingTheme: readingTheme ?? this.readingTheme,
        highlightColor: highlightColor ?? this.highlightColor,
        showCitations: showCitations ?? this.showCitations,
        contextDepth: contextDepth ?? this.contextDepth,
        pomodoroMinutes: pomodoroMinutes ?? this.pomodoroMinutes,
        liteMode: liteMode ?? this.liteMode,
        readerDarkMode: readerDarkMode ?? this.readerDarkMode,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        huggingFaceToken: huggingFaceToken ?? this.huggingFaceToken,
      );
}

/// Loads and persists [AppSettings] rows from Drift.
class SettingsStorage {
  SettingsStorage(this._db);

  final AppDatabase _db;

  Future<AppSettings> load() async {
    final rows = await _db.select(_db.settings).get();
    final map = <String, String>{
      for (final row in rows) row.key: row.value,
    };
    return AppSettings(
      musicFolder: map['musicFolder'] ?? '',
      autoPlayMusic: map['autoPlayMusic'] == 'true',
      volume: double.tryParse(map['volume'] ?? '') ?? 0.65,
      splitRatio: double.tryParse(map['splitRatio'] ?? '') ?? 0.55,
      readerFitMode: map['readerFitMode'] ?? 'fitWidth',
      readingTheme: map['readingTheme'] ?? 'paper',
      highlightColor: map['highlightColor'] ?? '#A3BFA6',
      showCitations: map['showCitations'] != 'false',
      contextDepth: int.tryParse(map['contextDepth'] ?? '') ?? 4,
      pomodoroMinutes: int.tryParse(map['pomodoroMinutes'] ?? '') ?? 25,
      liteMode: map['liteMode'] == 'true',
      readerDarkMode: map['readerDarkMode'] == 'true',
      onboardingComplete: map['onboardingComplete'] == 'true',
      huggingFaceToken: map['huggingFaceToken'] ?? '',
    );
  }

  Future<void> _set(String key, String value) async {
    await _db.into(_db.settings).insert(
          SettingsCompanion.insert(key: key, value: value),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> save(AppSettings s) async {
    await _set('musicFolder', s.musicFolder);
    await _set('autoPlayMusic', s.autoPlayMusic.toString());
    await _set('volume', s.volume.toString());
    await _set('splitRatio', s.splitRatio.toString());
    await _set('readerFitMode', s.readerFitMode);
    await _set('readingTheme', s.readingTheme);
    await _set('highlightColor', s.highlightColor);
    await _set('showCitations', s.showCitations.toString());
    await _set('contextDepth', s.contextDepth.toString());
    await _set('pomodoroMinutes', s.pomodoroMinutes.toString());
    await _set('liteMode', s.liteMode.toString());
    await _set('readerDarkMode', s.readerDarkMode.toString());
    await _set('onboardingComplete', s.onboardingComplete.toString());
    await _set('huggingFaceToken', s.huggingFaceToken);
  }

  /// Reads an arbitrary key/value preference from the settings table (keys
  /// that are not part of [AppSettings]).
  Future<String?> getPref(String key) async {
    final rows =
        await (_db.select(_db.settings)..where((t) => t.key.equals(key))).get();
    return rows.isEmpty ? null : rows.first.value;
  }

  /// Persists an arbitrary key/value preference to the settings table.
  Future<void> setPref(String key, String value) => _set(key, value);
}

/// Single app-wide settings provider.
final settingsStorageProvider = Provider<SettingsStorage>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SettingsStorage(db);
});

/// Live settings state, initialized lazily from storage.
final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final storage = ref.watch(settingsStorageProvider);
    final loaded = await storage.load();
    // Re-arm the music folder's security-scoped access if one is saved.
    if (loaded.musicFolder.isNotEmpty) {
      final resolved = await ref.read(musicFolderProvider.future);
      if (resolved.isNotEmpty) {
        return loaded.copyWith(musicFolder: resolved);
      }
    }
    return loaded;
  }

  Future<void> apply(AppSettings Function(AppSettings) transform) async {
    final storage = ref.read(settingsStorageProvider);
    final current = await future;
    final next = transform(current);
    state = AsyncData(next);
    await storage.save(next);
  }

  Future<void> setMusicFolder(String path) async {
    await apply((s) => s.copyWith(musicFolder: path));
  }
}