import 'package:study_companion/core/settings/settings_storage.dart';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_db.dart';

void main() {
  group('AppSettings', () {
    test('defaults are sensible', () {
      const s = AppSettings();
      expect(s.musicFolder, '');
      expect(s.autoPlayMusic, false);
      expect(s.volume, 0.65);
      expect(s.splitRatio, 0.55);
      expect(s.readingTheme, 'paper');
      expect(s.showCitations, true);
      expect(s.contextDepth, 4);
      expect(s.pomodoroMinutes, 25);
      expect(s.liteMode, false);
      expect(s.readerDarkMode, false);
      expect(s.onboardingComplete, false);
      expect(s.huggingFaceToken, '');
    });

    test('copyWith updates only the given fields', () {
      const s = AppSettings();
      final changed = s.copyWith(
        volume: 0.8,
        onboardingComplete: true,
        huggingFaceToken: 'hf_test',
      );
      expect(changed.volume, 0.8);
      expect(changed.onboardingComplete, true);
      expect(changed.huggingFaceToken, 'hf_test');
      // untouched
      expect(changed.splitRatio, 0.55);
      expect(changed.contextDepth, 4);
    });

    test('roundtrip through SettingsStorage', () async {
      final db = await openInMemoryDb();
      final storage = SettingsStorage(db);

      await storage.save(
        AppSettings(
          readerDarkMode: true,
          readingTheme: 'sepia',
          huggingFaceToken: 'hf_token_abc',
          onboardingComplete: true,
          pomodoroMinutes: 50,
        ),
      );

      final loaded = await storage.load();
      expect(loaded.readerDarkMode, true);
      expect(loaded.readingTheme, 'sepia');
      expect(loaded.huggingFaceToken, 'hf_token_abc');
      expect(loaded.onboardingComplete, true);
      expect(loaded.pomodoroMinutes, 50);

      await db.close();
    });

    test('load returns defaults for empty table', () async {
      final db = await openInMemoryDb();
      final storage = SettingsStorage(db);

      final loaded = await storage.load();
      expect(loaded.musicFolder, '');
      expect(loaded.huggingFaceToken, '');
      expect(loaded.onboardingComplete, false);

      await db.close();
    });

    test('arbitrary pref get/set', () async {
      final db = await openInMemoryDb();
      final storage = SettingsStorage(db);

      expect(await storage.getPref('customKey'), isNull);
      await storage.setPref('customKey', 'hello');
      expect(await storage.getPref('customKey'), 'hello');

      await db.close();
    });
  });
}