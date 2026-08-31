# AGENTS.md

Moonlight Study — a local, offline AI study companion (Flutter). Runs on-device llama.cpp via `llamadart`. Git repo initialized on branch `main` but **no commits yet** (everything untracked). `models/` and `toolchains/` at the root are empty placeholders and are gitignored (GGUF models are downloaded/cached by llamadart at runtime, never committed).

## Commands

All commands run from `app/`.

- `flutter pub get` — restore dependencies
- `flutter run -d macos` — dev (also windows/linux/android/ios)
- `flutter analyze` — lint/typecheck (flutter_lints)
- `flutter test test/pomodoro_test.dart` — fast unit test
- `flutter test` — NOTE: `test/smoke_test.dart` and `test/qwen_vl_test.dart` download GGUF models from HuggingFace (10–15 min, network-dependent); don't treat them as quick verification
- After changing `lib/core/db/app_database.dart`, run `dart run build_runner build --delete-conflicting-outputs` to regenerate `app_database.g.dart` (drift codegen)

## Architecture

- Riverpod 2 (`flutter_riverpod`). State via `NotifierProvider` / `StreamProvider` (usually `autoDispose` families).
- DB: drift/SQLite, schema in `lib/core/db/app_database.dart`. Tables: `Documents`, `Chunks`, `Notebooks`, `NotebookDocuments`, `Flashcards`, `Notes`, `PDFAnnotations` (`pdfAnnotations`), `AppSettings` (drift key/value). Regenerate code after any schema edit.
- Desktop uses a frameless `window_manager` window (`lib/main.dart`); sidebar rail at ≥960px, bottom nav below (`lib/features/home/home_shell.dart`); screens switched by `appSectionProvider`.
- Design system: `CoffeeColors` palette + Fraunces serif / WorkSans, under `lib/core/theme`.

## Layout

- `lib/core/` — theme, ai, db, settings, state, window, music, audio
- `lib/features/` — dashboard, notebooks, reader, chat, flashcards, planner, models, settings, music
- `lib/docs/` — `document_service` (import/copy files into app docs dir, pdfrx text extraction, chunking 700/overlap 100), `rag_service` (chunks + embeddings, keyword-score fallback; `indexDocument` now creates the single document row and returns its id), `ocr_service` (vision-LLM OCR: renders PDF pages and asks the active vision model to transcribe them), `prompt_builder`, `data_repair` (startup dedupe + re-index of chunk-less docs)
- `lib/study/` — pomodoro + study actions
- `lib/shared/` — reusable coffee-style widgets

## AI / models

- `lib/core/ai/ai_engine.dart` — LlamaDart engine lifecycle (`aiEngineProvider` notifier). `chat()` streams `ChatDelta {content, thinking}` — `thinking` carries chain-of-thought from reasoning models (llamadart surfaces it on `delta.thinking`); non-reasoning models yield empty strings. `embed`/`embedBatch` return null unless the active model supports embeddings. `AiStatus`: idle → loading/downloading → ready/working/error (state carries download progress). All models load CPU-only at `contextSize: 4096, gpuLayers: 0`.
- `lib/core/ai/model_catalog.dart` — `hf://` GGUF sources. Default `qwen2.5-vl-3b` (vision; also needs `mmproj-F16.gguf`), plus `qwen2.5-1.5b` (text), `smolLM2-135m` (tiny smoke-test), and a STEM trio for <8GB devices: `deepseek-r1-1.5b` (reasoning/CoT, `hf://unsloth/...`, verified public), `qwen2.5-3b` (`qwen2.5-3b-instruct-q4_k_m.gguf`), `phi-3-mini`. GOTCHA: Qwen3 GGUFs (official Qwen/unsloth/bartowski) are **gated (401)** — they break unattended in-app downloads; prefer verified-public repos (request a `curl -I` on the resolve URL before adding new models). Capabilities: `AiCapability {chat, vision, embeddings, reasoning}`; only `vision` is special-cased in the Models screen.
- Reasoning output is rendered as a collapsible **Reasoning block** in Study Chat (`chat_screen.dart`) and the reader assistant (`assistant_pane.dart`) via the shared `shared/widgets/reasoning_block.dart` whenever a message's `thinking` is non-empty.
- `lib/core/ai/model_store.dart` — SharedPreferences holds `ai_enabled` + `active_model_id`; `SettingsLoader` rehydrates providers at startup. Embeddings need a model with the `embeddings` capability, otherwise RAG falls back to keyword scoring.

## Reader / notebook (high-traffic area — known gaps below)

- `lib/features/reader/` — left `pdfrx.PdfViewer.file` pane, right tabbed panel (**Notes first**, then AI assistant). The AppBar has a refresh button that re-indexes the open PDF (`_reindexCurrent`, `reader_screen.dart`) — re-runs extraction and OCR (for scanned pages) and rebuilds chunks.
- The Notes tab (`notes_pane.dart`) is a point-style list scoped to the PDF open in the reader: each row is a bullet note in a rounded box (auto-growing `TextField`) with an "Add note" button in the header (top-right) that appends a new note for the current `documentId`; rows autosave (debounced) via `updateNote` and each has a delete button. Source: `documentNotesProvider` (`notes_library.dart`), keyed by `(notebookId, documentId)`. Notes attached to a document are independent per PDF.
- Right-click on a text selection opens a Highlight / Summarize / Explain / Copy menu (`_buildSelectionMenu`, `pdf_pane.dart:254`) routed through `ReaderScreen._handleSelection` (`reader_screen.dart:160`); right-click elsewhere offers Select All / Copy. When the Highlight tool is armed, selecting text auto-highlights and the tool automatically returns to Select. `SelectionRequest.pageNumber` carries the real page from `PdfViewerController.pageNumber`.
- Notebook CRUD in `lib/features/notebooks/`: each card already has a `⋮` PopupMenuButton wiring **Duplicate** and **Delete** → `duplicateNotebook()` / `deleteNotebook()` (`notebook_library.dart`). Delete only removes doc rows/annotations/chunks when no other notebook references them; source files on disk are never touched.
- Annotations are stored as page-normalized rects (`PdfRectNorm`); highlight/sticky tools are armed from the PDF pane toolbar.
- **Night reading** toggle in the PDF toolbar (`_Toolbar`, `pdf_pane.dart`) sets `AppSettings.readerDarkMode` (also exposed in Settings → Reader). When on, `_AnnotatedPdfViewer` wraps `PdfViewer.file` in a `ColorFiltered` invert matrix + midnight `backgroundColor` (pages genuinely dark, not just the gutter). Overlays compensate via `_ToolOverlay._annotationColor` so highlights/stickies keep their hue under the filter; photos invert too. `readingTheme` (`paper|sepia|midnight`) only affects the page background — invert is separate.
- `readerAssistantProvider` (`assistant_pane.dart`) is **deliberately NOT autoDispose** (a `NotifierProvider.family`): reader selection actions (`_handleSelection`) push Summarize/Explain queries while the Notes tab may be active, and an autoDisposed conversation would be dropped — the answer would stream into a dead notifier and never appear. Keep it non-autoDispose.
- Platform app icons are **generated** by `app/tool/generate_logo.dart` (draws the vinyl + crescent logo with `package:image`, writes macOS/iOS/Android/Windows/Linux sets). Do not hand-edit icon PNGs; edit the script and re-run `dart run tool/generate_logo.dart` from `app/`.

### Cross-feature gotchas (all previously implemented; note the caveats)

- **Flashcards** — `StudyActions.generateFlashcards` (`study_actions.dart:30`) balances chunks across the user-selected `documentIds` and persists cards to the **first** selected document. Manual "Add flashcard" cards attach to the doc in `lastDeckDocumentId` setting. Source pickers live in `flashcards_screen.dart` (`_EmptyDeck._generate`, `_DeckView` "Generate more", `_DeckSourcePicker`).
- **Reading context / RAG scoping** — `ReaderScreen` publishes the open PDF to `readingContextProvider` (`lib/features/reader/reading_context.dart`); the Study Chat (`chat_provider.dart:92`) scopes RAG to it, **falling back to the whole library when no reader is open**, and shows a "Reading: <name>" chip. Caveats: chunks carry `pageIndex: 0` (chunking is **not** page-aware), and OCR of scanned PDFs (`ocr_service.dart` → `rag_service.indexDocumentContent`) requires a vision model loaded.
- **Legacy notes** — old merged markdown note rows (`documentId = null`) are retained in the DB but deliberately not shown.
- **Highlights** — text-selection highlights store per-line normalized rects in one annotation (`AnnotationPayload.highlightRects`, `annotations.dart`); legacy single-rect highlights still render via `AnnotationPayload.rects`.