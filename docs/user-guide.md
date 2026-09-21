# Moonlight Study — User Guide

Moonlight Study is a local, offline study companion: read PDFs, take notes,
highlight, generate flashcards, and ask questions that are answered from *your*
documents — all on-device. Nothing is uploaded; models download once and then
everything works offline.

## First run

- A three-page tutorial greets you. It auto-imports a small **Getting Started**
  sample guide so you can try everything immediately.
- You can skip it — Settings → Support → **Replay tutorial** brings it back
  any time.

## Getting documents in

1. Open **Notebooks** → create a notebook (or use the sample "Welcome" one).
2. Choose **Import a document** and pick a PDF. It is copied into the app
   and indexed for search and AI.
3. Scanned pages are OCR'd automatically when a vision model is loaded.

## Reading

Open a PDF from a notebook. The reader has:

- **Notes** tab — point-style bullet notes scoped to the open PDF (autosaved,
  delete anytime). Add one from the top-right.
- **AI assistant** tab — ask questions grounded in the open document.
- Right-click a selection for **Highlight / Summarize / Explain / Copy**.
  Highlight with the toolbar tool to auto-highlight on select.
- The PDF toolbar toggle enables **Night reading** (true dark pages); the same
  option lives under Settings → Reader.

## Study Chat

Chat with Moonlight. When a reader is open the chat scopes its answers to that
document (a "Reading: <name>" chip shows this); otherwise it searches the whole
library. Reasoning models show a collapsible **Reasoning** block above their
answers.

## Flashcards

Generate cards from one or more documents (Study Actions balances the source
chunks across them) or add cards manually. Cards persist to the first selected
document.

## Planner & Pomodoro

Plan study sessions and run the pomodoro timer from the Study tab.

## Music

Point the app at a folder of music (Settings → Music) for ambient lo-fi while
studying. On macOS the folder is granted once via a security-scoped bookmark —
nothing is copied or uploaded.

## Models & AI

- **Models** screen lists the catalog with honest size/RAM/speed labels and a
  recommendation for your device. Downloads show progress with a Retry button.
- Settings → AI: enable/disable AI, pick the active model, and — if you use
  models from **gated** HuggingFace repos — paste a read token.
- Embedding-capable models unlock semantic search in RAG; otherwise the app
  falls back to keyword scoring (same results flow, just simpler matching).

## Settings → Support

- **Replay tutorial** — re-show the first-run wizard.
- **View logs** — the last session's rotating file log for troubleshooting.
- **Check for updates** — checks GitHub Releases for a newer build (runs once
  quietly on startup; tap to re-check and download).
- Paste an issue/README snippet that includes any error message verbatim.

## Privacy

Every database, note, highlight, flashcard, and model lives on your machine.
The only network calls are model downloads, the version check against GitHub
Releases (`docs/auto-update.md`), and an optional external model endpoint you
configure yourself.