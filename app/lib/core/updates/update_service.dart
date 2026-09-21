import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../logging/app_logger.dart';

/// GitHub owner/repo used for release lookups. Releases are created on
/// `https://github.com/NavatejR/moonlight-study/releases`.
const kUpdateRepoOwner = 'NavatejR';
const kUpdateRepoName = 'moonlight-study';

/// Outcome of an update check.
enum UpdateStatus { upToDate, updateAvailable, checkFailed }

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    this.currentVersion,
    this.latestVersion,
    this.releaseUrl,
    this.downloadUrl,
    this.error,
  });

  final UpdateStatus status;
  final String? currentVersion;
  final String? latestVersion;

  /// GitHub release page URL (for notes / manually upgrading).
  final String? releaseUrl;

  /// Direct download URL of the newest artifact when one is attached.
  final String? downloadUrl;

  /// Human-friendly message for the [UpdateStatus.checkFailed] case.
  final String? error;

  bool get hasUpdate => status == UpdateStatus.updateAvailable;
}

/// Compares two `x.y.z` (optionally `+build`) version strings.
///
/// Returns 1 when [a] is newer than [b], -1 when older, 0 when equal or
/// neither parses. A leading `v`/`V` is ignored.
int compareVersions(String a, String b) {
  int? parse(String input) {
    final match =
        RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$', caseSensitive: false)
            .firstMatch(input.trim());
    if (match == null) return null;
    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    final patch = int.parse(match.group(3)!);
    return (major << 20) | (minor << 10) | patch;
  }

  final aN = parse(a);
  final bN = parse(b);
  if (aN == null || bN == null) return 0;
  return aN.compareTo(bN);
}

/// Checks GitHub Releases for a newer build of Moonlight Study.
///
/// Offline-friendly: a failed fetch is a [UpdateStatus.checkFailed], never an
/// unhandled exception. Runs over `dio`, which is already used for model
/// downloads (macOS sandbox grants `network.client`).
///
/// The version reader and release fetcher are injectable so tests can stub
/// both sides without network access.
class UpdateChecker {
  UpdateChecker({
    Future<String?> Function()? currentVersion,
    Future<Map<String, dynamic>> Function()? fetchLatest,
    Dio? client,
  })  : _currentVersion = currentVersion ??
            (() async => (await PackageInfo.fromPlatform()).version),
        _fetchLatest =
            fetchLatest ?? (() => _fetchGitHubLatest(client ?? Dio()));

  final Future<String?> Function() _currentVersion;
  final Future<Map<String, dynamic>> Function() _fetchLatest;

  static Future<Map<String, dynamic>> _fetchGitHubLatest(Dio client) async {
    final response = await client.get<Map<String, dynamic>>(
      'https://api.github.com/repos/$kUpdateRepoOwner/$kUpdateRepoName'
      '/releases/latest',
      options: Options(
        responseType: ResponseType.json,
        headers: {
          'User-Agent': 'moonlight-study',
          'Accept': 'application/vnd.github+json',
        },
      ),
    );
    return response.data ?? const {};
  }

  Future<UpdateCheckResult> check() async {
    final log = AppLogger();
    try {
      // GitHub API rejects requests without a User-Agent.
      final current = await _currentVersion();
      final response = await _fetchLatest()
          .timeout(const Duration(seconds: 10));

      final latestTag = (response['tag_name'] as String?)?.trim() ?? '';
      final latestVersion = latestTag.startsWith('v')
          ? latestTag.substring(1)
          : latestTag;
      if (latestVersion.isEmpty) {
        log.warning('Update feed returned no tag_name');
        return const UpdateCheckResult(
          status: UpdateStatus.checkFailed,
          error: 'The release feed returned an empty response.',
        );
      }

      final releaseUrl = response['html_url'] as String?;

      // Prefer a packaged artifact (.dmg / .exe / .AppImage / .apk) over the
      // release page when one exists.
      String? downloadUrl;
      final assets = response['assets'] as List<dynamic>?;
      dynamic firstAsset;
      dynamic dmgAsset;
      if (assets != null) {
        for (final a in assets) {
          firstAsset ??= a;
          if (a is Map &&
              ((a['name'] as String?)?.endsWith('.dmg') ?? false)) {
            dmgAsset = a;
            break;
          }
        }
      }
      final downloadAsset = dmgAsset ?? firstAsset;
      if (downloadAsset is Map) {
        downloadUrl = downloadAsset['browser_download_url'] as String?;
      }
      downloadUrl ??= response['browser_download_url'] as String?;

      log.info(
        'Update check: installed=$current latest=$latestVersion',
      );

      return UpdateCheckResult(
        status: compareVersions(latestVersion, current ?? '') > 0
            ? UpdateStatus.updateAvailable
            : UpdateStatus.upToDate,
        currentVersion: current,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
        downloadUrl: downloadUrl ?? releaseUrl,
      );
    } catch (e, stackTrace) {
      log.warning(
        'Update check failed (offline or feed unreachable)',
        error: e,
        stackTrace: stackTrace,
      );
      return UpdateCheckResult(
        status: UpdateStatus.checkFailed,
        error: 'Could not reach the update feed. Check your connection.',
      );
    }
  }
}

/// Single-flight update check: keeps the last result and lets the Settings
/// screen poll it without re-running the fetch every rebuild.
class UpdateCheckNotifier extends AsyncNotifier<UpdateCheckResult?> {
  @override
  Future<UpdateCheckResult?> build() async => null;

  /// Runs a check now and stores the result. Safe to call repeatedly; the
  /// in-flight request is shared.
  Future<UpdateCheckResult?> runCheck() async {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = ref.read(updateCheckerProvider).check();
    _inFlight = future;
    state = AsyncLoading<UpdateCheckResult?>().copyWithPrevious(state);
    try {
      final result = await future;
      state = AsyncData<UpdateCheckResult?>(result);
      return result;
    } catch (e, stackTrace) {
      state = AsyncError<UpdateCheckResult?>(e, stackTrace);
      return null;
    } finally {
      _inFlight = null;
    }
  }

  Future<UpdateCheckResult?>? _inFlight;
}

final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  return UpdateChecker();
});

final updateCheckProvider =
    AsyncNotifierProvider<UpdateCheckNotifier, UpdateCheckResult?>(
        UpdateCheckNotifier.new);