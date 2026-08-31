# Contributing to Moonlight Study

Thanks for your interest in Moonlight Study! This is a local-first, offline AI
study companion built with Flutter. Contributions of all kinds are welcome —
code, docs, bug reports, and feedback.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md). By
participating, you agree to keep the community professional, respectful, and
welcoming.

## Getting started

Prerequisites:

- **Flutter 3.x** (stable channel) — install via
  [flutter.dev](https://flutter.dev) or `fvm`
- Platform toolchains for the target(s) you want to run (Xcode for macOS/iOS,
  Android Studio/NDK for Android, Visual Studio for Windows, etc.)

Set up:

```bash
cd app
flutter pub get
```

### Running

```bash
cd app
flutter run -d macos        # or windows / linux / android / ios
```

### Model downloads

The on-device models are large GGUF files downloaded at runtime by `llamadart`
(never committed). The first chat / OCR / flashcard run will trigger a download.
See the [Models screen](../README.md#model-catalog) section of the README.

## Project layout

- `lib/core/` — theme, AI engine, database, settings, state, window, music, audio
- `lib/features/` — dashboard, notebooks, reader, chat, flashcards, planner,
  models, settings, music
- `lib/docs/` — document import, RAG indexing, OCR, prompt building, data repair
- `lib/study/` — pomodoro + study actions
- `lib/shared/` — reusable coffee-style widgets

A fuller architecture description lives in [AGENTS.md](../../AGENTS.md).

## Development workflow

1. **Fork** the repo and create a feature branch.
2. Make your change. Keep it focused; one logical change per PR.
3. If you changed `lib/core/db/app_database.dart`, regenerate the drift
   codegen:
   ```bash
   cd app
   dart run build_runner build --delete-conflicting-outputs
   ```
   Commit the updated `app_database.g.dart` too.
4. Run the checks (all must pass):
   ```bash
   cd app
   flutter analyze
   flutter test test/navigation_test.dart test/pomodoro_test.dart test/latex_syntax_test.dart
   ```
   > The remaining tests (`smoke_test.dart`, `qwen_vl_test.dart`) download
   > multi-hundred-MB GGUF models from HuggingFace and are intentionally
   > excluded from normal verification.
5. Update docs (README, etc.) if your change affects user-facing behaviour.
6. Open a pull request against `main`.

## Testing

Fast, offline unit tests live in `app/test/` (`*_test.dart`). Prefer to add a
small, fast test alongside a bug fix so regressions are caught by CI. For pure
logic (routing, pomodoro transitions, latex parsing), use `flutter test`.

## Adding models

See the "Model catalog & gating" notes in the README. Only add models whose
GGUF source is **verified public** — official Qwen3 GGUFs are gated and will
404 in unattended in-app downloads.

## Style

- Dart code follows `flutter_lints` (see `analysis_options.yaml`).
- Everything is styled with the `CoffeeColors` palette and the Fraunces /
  WorkSans type system — keep new UI on-theme.
- No secrets or keys in code; the app is designed to run fully offline.

## Questions?

Open an issue or start a discussion. We're friendly.
