# Performance audit

Snapshot of the Phase 9 audit (what was measured, what changed, what's fine as
is and why). Nightly run target: keep startup snappy, reader smooth, and
retrieval off the hot path.

## Changes shipped in this phase

### 1. RAG chunk writes are batched
`RagService.indexDocumentContent` inserted each chunk with its own awaited
`insert` (N statements, N autocommit transactions). Now one `db.batch(...)`:
single transaction, single round-trip to the background SQLite isolate.

Applies to first import (onboarding sample, flashcards), and re-index.

### 2. Retrieval scoping moved into SQL
`RagService.retrieve` loaded **every** row of `chunks ⋈ documents`, then
filtered `documentIds` in Dart. Now, when `documentIds` is non-empty
(notebook / reader-scoped chat), the WHERE clause is pushed down:
`WHERE chunks.document_id IN (...)` — unrelated documents' chunks are never
materialized. The whole-library call (Study Chat with no reader open) is
unchanged.

### 3. Indexes on the two hot join/delete columns
- `Chunks.documentId` — every re-index does `DELETE FROM chunks WHERE
  document_id = ?` and now retrieval filters on the same column.
- `NotebookDocuments.documentId` — used by notebook-scoped lookups and the
  startup `repairLibrary` pass.

Declared as `@TableIndex` in `app_database.dart` (fresh DBs get them via
`createAll`) plus a `schemaVersion 4 → 5` migration that `CREATE INDEX IF NOT
EXISTS` for existing installations. Run `dart run build_runner build
--delete-conflicting-outputs` after touching indexes.

## Verified already off the main isolate (no action needed)

- **SQLite I/O** runs on a background isolate
  (`NativeDatabase.createInBackground`, `app_database.dart:192`) — including
  the big RAG joins.
- **PDF text extraction / rasterization** is pdfrx's async worker path.
- **Model inference** (`llamadart`) runs on its own thread; `chat()` streams
  deltas instead of blocking.
- **OCR** is page-by-page with `AiStatus` progress and is rate-limited by the
  vision model itself.

## Left as-is by design

- **Dart-side scoring loops** (`retrieve` cosine/keyword, `MemoryService`
  recency) run on the UI isolate after the await. For a study library of
  hundreds of chunks this is sub-millisecond to a few ms; `Isolate.run` would
  add send-copy overhead for no measurable win at this scale. Revisit if a
  single library grows past ~50k chunks.
- **`chunkText`** regex-whitespace-clean is O(n) on the indexing path, which is
  already user-paced behind a progress UI.
- **Logging** is synchronous but low-volume (a few lines per action); the
  rotator caps at 5 MB × 3 files.

## Revisit when introducing vector search

If an embedding-capable model becomes the default, every chat query performs
one query-embedding pass + a cosine over all chunks. Options for a future
phase: SQLite FTS5 for keyword ranking, a `.sqlite`-resident vector index, or
precomputed per-query candidates. See the P1 optimization note in the roadmap.