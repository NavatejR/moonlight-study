# Auto-update

Moonlight Study checks for new versions against **GitHub Releases** for
[`NavatejR/moonlight-study`](https://github.com/NavatejR/moonlight-study)
at `https://api.github.com/repos/NavatejR/moonlight-study/releases/latest`.

## How the check works

- **On startup** the app fires one quiet, background check. If it fails
  (offline, feed unreachable, new repo before first release) nothing is shown;
  the result just rests in `updateCheckProvider`.
- **Settings → Support → "Check for updates"** lets the user check on demand,
  shows the outcome inline, and opens the download on tap.
- Every check is **single-flight** (`UpdateCheckNotifier`): repeated taps reuse
  an in-progress request, then show a SnackBar with the outcome.

### Version comparison

The installed version comes from `package_info_plus`; the latest comes from
the release `tag_name`. Both are compared with `compareVersions` in
`lib/core/updates/update_service.dart` (`x.y.z`, leading `v` and `+build`
suffixes ignored). A tag of `v1.1.0` beats an installed `1.0.0`.

### Download target

When the release has assets, the download button prefers a `.dmg` (or, in
future, `.exe` / `.AppImage` / `.apk`). If a release ships no assets, the
button falls back to the release page.

## Making a release show up

1. Bump `version:` in `app/pubspec.yaml` (e.g. `1.1.0+2`).
2. Build the artifact: `SKIP_NOTARY=... ./scripts/build_macos_release.sh` from
   `app/` (see `docs/releasing.md`).
3. Create the GitHub release with tag `v1.1.0` and attach the DMG from
   `app/dist/` **with a filename ending in `.dmg`** — the checker keys off that
   suffix.
4. Users on `<= 1.0.0` will see "Version 1.1.0 is available" after their next
   background check.

## Notes & limits

- **No silent self-update yet.** The checker notifies and opens the download;
  installing still means dragging the new `.dmg` over the old app. A managed
  installer or Sparkle-style replacement (auto-update in-app) is a future phase.
- **Rate limits:** the GitHub API allows unauthenticated release lookups easily
  within normal single-user usage. The 10-second timeout keeps checks from
  blocking startup.
- The pre-1.0 releases used the plain DMG page; going forward keep the DMG as a
  release asset so the direct download link works.

## Future: full Sparkle integration

If true in-app auto-update is wanted, the path is
[`package:auto_updater`](https://pub.dev/packages/auto_updater) (Sparkle) with
an appcast hosted as a GitHub Pages / raw release. That requires every signed
build to be enrolled with the same Developer ID and the sparkle key kept in
CI secrets — see `docs/releasing.md` for the signing prerequisites.