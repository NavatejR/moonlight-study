# Security Policy

## Supported versions

Only the latest `main` branch and tagged releases are supported for security
fixes.

## Reporting a vulnerability

Moonlight Study runs **fully offline** — your documents, notes, memory, and AI
inference never leave your device except when you explicitly set up an external
API provider or download a model.

Please **do not** open a public issue for security vulnerabilities. Instead,
report privately to the repository maintainers (email is preferred). You should
receive a response within a few business days.

Please include:

- The affected version / commit
- A description of the vulnerability and its impact
- Steps to reproduce
- Any suggested fix (if you have one)

## Security considerations & the on-device model supply chain

This app downloads GGUF model files from Hugging Face at runtime via `llamadart`
when you pick a model. We only ship models whose sources are **verified public**
repos, because gated or frequently-revoked repos can be swapped by an upstream
maintainer. If you discover a shipped model source that has been replaced,
unauthenticated, or otherwise tampered with, report it as a vulnerability above.

## Data handling

- Everything runs on-device: documents, notes, memory, flashcards, and the LLM.
- The only network calls are: (1) downloading GGUF models, and (2) the optional
  external OpenAI/Anthropic-compatible endpoint you configure yourself in
  Settings → Models → External API. The API key is stored in local
  platform preferences.
