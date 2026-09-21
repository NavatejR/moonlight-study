import 'package:flutter_test/flutter_test.dart';
import 'package:study_companion/core/updates/update_service.dart';

void main() {
  group('compareVersions', () {
    test('equal versions compare equal', () {
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('2.3.4', '2.3.4'), 0);
    });

    test('newer version returns 1', () {
      expect(compareVersions('1.0.1', '1.0.0'), 1);
      expect(compareVersions('1.1.0', '1.0.9'), 1);
      expect(compareVersions('2.0.0', '1.9.9'), 1);
    });

    test('older version returns -1', () {
      expect(compareVersions('1.0.0', '1.0.1'), -1);
      expect(compareVersions('0.9.0', '1.0.0'), -1);
    });

    test('leading v prefix is ignored', () {
      expect(compareVersions('v1.0.1', '1.0.0'), 1);
      expect(compareVersions('V1.0.0', 'v1.0.0'), 0);
    });

    test('+build suffix is ignored', () {
      expect(compareVersions('1.0.0+3', '1.0.0+1'), 0);
      expect(compareVersions('2.0.0+1', '1.9.9+99'), 1);
    });

    test('pre-release suffix is ignored for ordering', () {
      expect(compareVersions('1.1.0-beta.1', '1.0.0'), 1);
    });

    test('unparseable strings compare equal', () {
      expect(compareVersions('banana', '1.0.0'), 0);
      expect(compareVersions('', '1.0.0'), 0);
      expect(compareVersions('1.0', '1.0.0'), 0);
    });
  });

  group('UpdateChecker', () {
    UpdateChecker checker({
      String current = '1.0.0',
      Map<String, dynamic>? release,
      Future<Map<String, dynamic>> Function()? fetchLatest,
    }) {
      return UpdateChecker(
        currentVersion: () async => current,
        fetchLatest: fetchLatest ??
            (() async => release ?? <String, dynamic>{}),
      );
    }

    test('flags update when latest is newer and picks the DMG asset', () async {
      final c = checker(
        current: '1.0.0',
        release: {
          'tag_name': 'v1.1.0',
          'html_url': 'https://github.com/NavatejR/moonlight-study/releases/tag/v1.1.0',
          'assets': [
            {
              'name': 'Moonlight Study-1.1.0.dmg',
              'browser_download_url':
                  'https://github.com/NavatejR/moonlight-study/releases/download/v1.1.0/Moonlight%20Study-1.1.0.dmg',
            },
            {
              'name': 'checksums.txt',
              'browser_download_url': 'https://github.com/.../checksums.txt',
            },
          ],
        },
      );

      final result = await c.check();

      expect(result.hasUpdate, isTrue);
      expect(result.latestVersion, '1.1.0');
      expect(result.currentVersion, '1.0.0');
      expect(result.downloadUrl, contains('Moonlight%20Study-1.1.0.dmg'));
      expect(result.releaseUrl, contains('/releases/tag/v1.1.0'));
    });

    test('falls back to the release page when no assets are attached', () async {
      final c = checker(
        release: {
          'tag_name': '1.2.0',
          'html_url': 'https://github.com/NavatejR/moonlight-study/releases/tag/1.2.0',
          'assets': [],
        },
      );

      final result = await c.check();

      expect(result.hasUpdate, isTrue);
      expect(result.downloadUrl, result.releaseUrl);
    });

    test('up to date when versions match', () async {
      final c = checker(current: '1.0.0', release: {'tag_name': 'v1.0.0'});
      final result = await c.check();
      expect(result.status, UpdateStatus.upToDate);
      expect(result.hasUpdate, isFalse);
    });

    test('up to date when installed is newer', () async {
      final c = checker(current: '1.3.0', release: {'tag_name': 'v1.2.1'});
      final result = await c.check();
      expect(result.status, UpdateStatus.upToDate);
    });

    test('empty feed body reports checkFailed', () async {
      final c = checker(release: <String, dynamic>{});
      final result = await c.check();
      expect(result.status, UpdateStatus.checkFailed);
    });

    test('network failure reports checkFailed, not an exception', () async {
      final c = checker(
        fetchLatest: () async => throw Exception('no network'),
      );
      final result = await c.check();
      expect(result.status, UpdateStatus.checkFailed);
      expect(result.error, isNotNull);
    });
  });
}