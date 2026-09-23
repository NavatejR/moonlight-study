# Releasing Moonlight Study (macOS)

Production macOS artifacts are signed, notarized, and shipped as a drag-to-
`/Applications` DMG. This page covers the tooling; the background is in
[architecture](architecture.md).

## Prerequisites

- An Apple Developer account (free or paid) with a **Developer ID Application**
  certificate installed in the keychain (`security find-identity -v -p
  codesigning` should list it).
- Xcode 13.2+ for `xcrun notarytool`, and a notarytool credential stored once:

  ```bash
  xcrun notarytool store-credentials "notarytool" \
    --apple-id "you@example.com" \
    --team-id "TEAMID" \
    --password "app-specific-password"
  ```

## CI release pipeline

Pushing a tag matching `v*` (e.g. `v1.0.0`) triggers
[`.github/workflows/release.yml`](.github/workflows/release.yml), which on a
`macos-latest` runner:

1. Runs the same gates as regular CI — `flutter analyze` and the offline unit
test suite — so a release can never go out broken.
2. Builds the DMG with `SKIP_NOTARY=1 ./scripts/build_macos_release.sh`
(ad-hoc signing, no Apple Developer cert required).
3. Publishes a GitHub Release on the tag with the DMG attached (the app's
built-in updater keys off the `.dmg` asset, so direct download links work).

Until Developer ID signing secrets (`APPLE_CERTIFICATE_P12`,
`APPLE_CERTIFICATE_PASSWORD`, notarytool keychain profile) are added as repo
secrets, artifacts are **unsigned/ad-hoc** — see the Gatekeeper note in the
README's [Download](README.md#download) section.

## Local notarized releases

For a signed, notarized DMG built on your own machine, run the script
locally; the background is in [architecture](architecture.md).

```bash
cd app
./scripts/build_macos_release.sh
# or, with a specific cert / profile:
# DEV_ID="Developer ID Application: Name (TEAMID)" \
# APPLE_PROFILE="notarytool" \
# ./scripts/build_macos_release.sh
```

What the script does:

1. `flutter build macos --release`
2. Re-signs the `.app` with the Developer ID identity, **hardened runtime**
   (`--options runtime`) and the `Release.entitlements`, including a secure
   timestamp — all required for notarization.
3. `xcrun notarytool submit --wait` then staples the notarization ticket.
4. Builds `dist/Moonlight Study-<version>.dmg` with a drag-to-Applications
   layout (`hdiutil`, no extra brew tools). Set `SKIP_NOTARY=1` to skip steps
   2–3 for a quick unsigned DMG.

Sandbox & network: `macos/Runner/Release.entitlements` keeps
`com.apple.security.app-sandbox`, `network.client` (model downloads), and
`files.user-selected.read-only` (pick-a-PDF / music folder). The Xcode Release
config has `ENABLE_HARDENED_RUNTIME = YES`; keep it that way or notarization
(and Gatekeeper on modern macOS) will reject the build.

## Notarization gotchas

- **Nested code** (llamadart/llama frameworks) must be signed — the script's
  `--deep` re-sign covers bundled frameworks; if you change how native libs are
  packaged, re-verify with `codesign --verify --deep --strict`.
- Model GGUFs are **downloaded at runtime**, never bundled, so the DMG stays
  small and needs no special entitlement.
- Verify a final gate with:
  `spctl --assess --type execute build/macos/Build/Products/Release/study_companion.app`

## Per-platform releases

iOS/Android/Win/Linux are out of scope for this script (see the README for
`flutter build` per platform). Windows/Linux builds are unsigned by default;
set up signing certs for those platforms separately if distributing broadly.

## Rolling a release

1. Bump `version:` in `app/pubspec.yaml` (and reflect it in the Info.plist via
   Xcode `MARKETING_VERSION`).
2. Build + notarize → `dist/`.
3. Test the DMG from a clean machine profile.
4. Tag + cut a GitHub Release and upload the DMG (see [auto-update](auto-update.md)
   once wired).