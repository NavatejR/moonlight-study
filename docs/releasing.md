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

Pushing a tag matching `v*` (e.g. `v1.0.1`) triggers
[`.github/workflows/release.yml`](.github/workflows/release.yml), which on a
`macos-latest` runner:

1. Runs the same gates as regular CI — `flutter analyze` and the offline unit
test suite — so a release can never go out broken.
2. Detects whether the five Apple signing secrets are configured.
3. If they are: imports the Developer ID certificate into a per-run keychain,
builds the DMG with `SKIP_NOTARY=0 ./scripts/build_macos_release.sh`
(signed → notarized → stapled), and publishes release notes saying so.
4. If not: builds with `SKIP_NOTARY=1` (ad-hoc signing, no Apple cert
required) and publishes notes with the Gatekeeper workaround.
5. Publishes a GitHub Release on the tag with the DMG attached (the app's
built-in updater keys off the `.dmg` asset, so direct download links work).

Until Developer ID signing secrets are added as repo secrets, artifacts are
**unsigned/ad-hoc** — see the Gatekeeper note in the README's
[Download](README.md#download) section. Once the secrets below are set, the
**next tag-push automatically produces signed, notarized, stapled DMGs**
with no workflow changes.

## One-time repo secrets setup

Configure these in **repo Settings → Secrets and variables → Actions**. When
all five exist, the release workflow switches from ad-hoc to
signed-and-notarized automatically (any missing secret → ad-hoc fallback):

| Secret | Value |
| --- | --- |
| `APPLE_CERTIFICATE_P12` | Base64 of the **Developer ID Application** `.p12` export. Export the cert + private key from Keychain Access, then `base64 -i developerID_application.p12 \| pbcopy` and paste. |
| `APPLE_CERTIFICATE_PASSWORD` | The password you set when exporting the `.p12`. |
| `APPLE_ID` | The Apple ID email that owns the Developer account. |
| `APPLE_APP_SPECIFIC_PASSWORD` | Create at [appleid.apple.com](https://appleid.apple.com/account/manage) → Sign-In and Security → App-Specific Passwords. |
| `APPLE_TEAM_ID` | Your 10-character Team ID ([developer.apple.com/account](https://developer.apple.com/account) → Membership details). |

Optional: `KEYCHAIN_PASSWORD` — the CI keychain password; leave unset and the
workflow generates a random one per run.

Notes on safety:

- The `.p12` is the only high-value secret — it can sign as your team. Never
  commit it, and revoke + re-issue from the Apple Developer portal if it ever
  leaks.
- GitHub masks secret values in logs; the workflow never echoes them.
- The CI keychain is created per-run and dies with the runner.

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
2. **Re-signs every nested framework/bundle innermost-first** (pdfrx's
   PDFium, llamadart's llama frameworks, …). Nested code must never keep a
   foreign Team-ID signature — see the gotchas below.
3. Re-signs the `.app` with the Developer ID identity, **hardened runtime**
   (`--options runtime`) and the `Release.entitlements`, including a secure
   timestamp — all required for notarization. With `SKIP_NOTARY=1` the app is
   signed ad-hoc **without** the hardened runtime instead (see gotchas).
4. `xcrun notarytool submit --wait` then staples the notarization ticket.
5. Builds `dist/Moonlight Study-<version>.dmg` with a drag-to-Applications
   layout (`hdiutil`, no extra brew tools). Set `SKIP_NOTARY=1` to skip steps
   3–4 for a quick unsigned DMG.

Sandbox & network: `macos/Runner/Release.entitlements` keeps
`com.apple.security.app-sandbox`, `network.client` (model downloads), and
`files.user-selected.read-only` (pick-a-PDF / music folder). The Xcode Release
config has `ENABLE_HARDENED_RUNTIME = YES`; keep it that way or notarization
(and Gatekeeper on modern macOS) will reject the build.

## Notarization gotchas

- **Nested code** (PDFium, llamadart/llama frameworks) must be re-signed — a
  single `--deep` pass over the `.app` is NOT enough: codesign treats an
  already-valid nested framework as satisfied and leaves its old signature
  (often the distributor's real Team ID). The script therefore signs every
  nested `.framework` explicitly, innermost-first, before the app itself.
- **Ad-hoc builds must NOT enable the hardened runtime.** `--options runtime`
  turns on library validation, which aborts at launch when a nested binary's
  Team ID differs from the main executable's — and an ad-hoc signature has no
  Team ID at all. That is exactly how the v1.0.0 DMG crashed with
  `Library not loaded: @rpath/PDFium.framework/PDFium … different Team IDs`.
  The hardened runtime is only required on the notarized (Developer ID) path.
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
4. Tag + cut a GitHub Release and upload the DMG — pushing a `v*` tag does
   this automatically (see [CI release pipeline](#ci-release-pipeline) and
   [auto-update](auto-update.md)).