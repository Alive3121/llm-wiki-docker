# raw/

Drop your source materials here.

## What goes in

Anything text-based that you want to extract knowledge from:

- PDFs (after text extraction)
- Markdown notes
- Lecture / podcast transcripts
- Social media post dumps (Threads, X, etc.)
- Articles, papers
- Screenshots (after OCR)
- Audio (after transcription)
- Email exports
- Slack / Discord history

Format-wise: prefer plain text or markdown. Binary files (raw PDFs, audio) should be converted to text before landing here, so the LLM can actually read them.

## Folder layout (suggested)

```
raw/
├── threads/
│   ├── 2026-01-posts.md
│   └── 2026-01-replies.md
├── lectures/
│   └── 2026-03-15-skill-design.md
├── articles/
│   └── 2026-02-mcp-deep-dive.md
└── notes/
    └── ...
```

Subfolders by source type help during Ingest — the LLM can target one source at a time.

## Rules

- **Read-only from the LLM's perspective.** The LLM extracts atoms from raw but never writes back. If raw needs correction or redaction, do it manually and re-run Ingest.
- **Stable identifiers.** Each file should have a stable name/path. `source_ids` in atoms reference these.
- **Whole-content gitignored.** Only this README and `.gitkeep` are tracked. Your raw materials never go to the public repo — that's the whole point.

## Why this layer exists

Karpathy's original LLM Wiki is `raw → wiki` — the LLM reads raw and emits wiki directly. This repo splits that into `raw → atoms → wiki`, with atoms as an intermediate immutable source-of-truth layer.

But raw is still where everything starts. It's the layer the human owns; the LLM just reads from it.
