# atoms/

Knowledge atoms, organized by topic-branch. **Source of truth.**

## Layout

```
atoms/
├── README.md                ← you are here
├── _template.md             ← copy this when creating a new atom
│
├── <branch-1>/              ← one folder per topic-branch
│   ├── 2026-01-15-some-claim.md
│   ├── 2026-02-03-another-claim.md
│   ├── _archive/            ← superseded atoms live here
│   └── ...
│
├── <branch-2>/
│   └── ...
│
└── ...
```

One folder per topic-branch. One file per atom. One claim per file.

See `_template.md` for the frontmatter and body format. See `CLAUDE.md` at the repo root for the full spec.

## Why atoms exist

Karpathy's original LLM Wiki goes `raw → wiki` directly. The atom layer is this repo's main addition — it solves three problems:

1. **Loss of information.** Wiki compilation is lossy. Without atoms, you can't recover what got dropped without re-reading raw.
2. **False sense of source of truth.** Wiki looks authoritative, but it's a derived artifact. Atoms are the truth; wiki is a cache.
3. **Provenance.** Every wiki claim should be traceable to atoms, and every atom traceable to raw. Without an atom layer, the chain breaks at the wiki.

When a wiki page is wrong, you fix the underlying atom and recompile. You never patch the wiki directly.

## What's gitignored

Everything in this folder except `README.md`, `_template.md`, and `.gitkeep` is gitignored. Your atoms are personal content; the framework is what gets shared.
