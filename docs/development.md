# Moonlight Study — Development

Everything runs from the `app/` folder.

## Commands

| Task | Command |
| --- | --- |
| Restore dependencies | `flutter pub get` |
| Run (desktop) | `flutter run -d macos` / `-d windows` / `-d linux` |
| Run (mobile) | `flutter run -d android` / `-d ios` |
| Lint + typecheck | `flutter analyze` (0 issues is the CI requirement) |
| Fast unit tests | `flutter test test/error_handler_test.dart test/model_catalog_test.dart test/app_settings_test.dart test/chunking_test.dart test/rag_keyword_test.dart test/onboarding_test.dart test/shared_widgets_test.dart test/navigation_test.dart test/pomodoro_test.dart test/latex_syntax_test.dart` |
| Drift codegen | `dart run build_runner build --delete-conflicting-outputs` |
| Regenerate app icons | `dart run tool/generate_logo.dart` (writes macOS/iOS/Android/Windows/Linux sets — never hand-edit icon PNGs) |
| Regenerate sample PDF | `dart run tool/generate_sample_pdf.dart` (recreates `assets/docs/getting_started.pdf`) |

> **Slow tests**: `test/smoke_test.dart` and `test/qwen_vl_test.dart` download
> GGUF models from HuggingFace (10–15 min, network-dependent). They are not a
> quick verification and are excluded from CI.

## Drift schema changes

1. Edit `app_database.dart` (bump `schemaVersion`, add an `onUpgrade` branch).
2. Run the codegen command above.
3. Commit both `app_database.dart` and the regenerated `app_database.g.dart`.
   CI has a drift-sync job that fails if the committed codegen drifted.

## Writing tests

- **In-memory DB**: `AppDatabase([QueryExecutor?])` accepts an executor, so
  tests call `openInMemoryDb()` from `test/helpers/test_db.dart`
  (`NativeDatabase.memory()`, no `path_provider`). This powers the settings,
  chunking and RAG keyword tests.
- **Services that need a Riverpod `ref`**: build a `ProviderContainer`, expose
  its own `Ref` via `final _refProvider = Provider<Ref>((ref) => ref);` and read
  it from the container.
- **Avoid mock libraries**: the test suite uses hand-rolled fakes and provider
  overrides (e.g. `appDatabaseProvider.overrideWithValue(db)`) instead of
  mockito/mocktail.
- **Keyword-scoring RAG test**: the default active model has no `embeddings`
  capability, so `retrieve()` exercises the keyword fallback with no AI engine.
- **Widget tests that touch platform channels** (e.g. `path_provider`) should
  stub the channel or scope the assertion to the widget subtree. The onboarding
  tests intentionally stop at the importing spinner rather than awaiting the
  sample-import file I/O.
- Run `flutter analyze` after any test change.

## Model catalog checklist

Adding a model to `lib/core/ai/model_catalog.dart`:

1. **Verify the source is public and the file exists** — request the resolve
   URL and confirm a redirect (e.g. `curl -I`). Qwen3 GGUFs (official
   Qwen/unsloth/bartowski) are **gated (401)** and break unattended in-app
   downloads; prefer verified-public repos. Gated models still work once the
   user adds a read token in Settings → AI (passed as `bearerToken`).
2. Give the entry a unique `id`, clear `name`/`tagline`, honest
   `sizeLabel`/`ramLabel`/`speedLabel`, and the right capabilities.
3. A vision model also needs a `projectorSource` (mmproj GGUF).
4. Update `recommendedFor*` lists if the model changes the default-nudge for
   that class of device.