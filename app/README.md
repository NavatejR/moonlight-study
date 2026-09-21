# Moonlight Study — app

Flutter client for Moonlight Study, a local-first, offline AI study companion.

Documentation lives one level up and in `../docs`:

- [Architecture](../docs/architecture.md) — layers, state, data flow, AI engine
- [Development](../docs/development.md) — commands, codegen, tests, model checklist
- [User guide](../docs/user-guide.md) — how to use the app day-to-day
- [AGENTS.md](../AGENTS.md) — feature-area notes and cross-cutting gotchas

## Quick start

```bash
flutter pub get
flutter run -d macos        # or windows / linux / android / ios
flutter analyze             # lint gate (0 issues)
```

Fast offline tests (seconds, no model downloads):

```bash
flutter test test/error_handler_test.dart \
  test/model_catalog_test.dart \
  test/app_settings_test.dart \
  test/chunking_test.dart \
  test/rag_keyword_test.dart \
  test/onboarding_test.dart \
  test/shared_widgets_test.dart \
  test/navigation_test.dart \
  test/pomodoro_test.dart \
  test/latex_syntax_test.dart
```

Regenerate drift code after editing a schema table:

```bash
dart run build_runner build --delete-conflicting-outputs
```

> `test/smoke_test.dart` and `test/qwen_vl_test.dart` download GGUF models from
> HuggingFace and take 10–15 minutes; they are not part of the quick loop.