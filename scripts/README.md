# scripts/

Three scripts for maintaining the wiki layer. All shell, no dependencies beyond `bash`, `grep`, `sed`, `awk`, `sort`, `wc`.

---

## `gen-index.sh`

Rebuilds `index.md` at the repo root from `wiki/` filenames and first-line titles.

**Usage:**
```bash
./scripts/gen-index.sh
```

**What it does:**
1. Scans `wiki/*.md`
2. Groups pages by branch prefix (the part of the filename before the first hyphen)
3. Reads the first line of each page (must be `# Title`) for display
4. Writes the grouped, alphabetically-sorted index to `index.md`

**Configuration:**

By default, branches are auto-discovered from filename prefixes and display names are capitalized automatically. If you want to control order and display names (e.g., custom capitalization like "MCP" instead of "Mcp"), edit the `BRANCHES` override array at the top of the script:

```bash
declare -a BRANCHES=(
  "harness-engineering|Harness Engineering"
  "mcp|MCP"
  "ai-skills|AI Skills"
  ...
)
```

Leave empty (`declare -a BRANCHES=()`) for auto-discovery.

---

## `lint.sh`

Programmatic health check — four deterministic checks, no LLM needed.

**Usage:**
```bash
./scripts/lint.sh
```

**Checks:**

1. **Ghost links** — `[[slug]]` pointing to non-existent wiki pages (→ error)
2. **Orphan pages** — wiki pages with zero incoming `[[ ]]` links (→ warning)
3. **Format violations** — first line not `# title`, filename contains uppercase or underscore (→ error)
4. **Outdated markers** — temporal patterns that need verification (→ warning)

**Output:** `lint-report.md` at the repo root, with counts summary and per-page findings.

**Tuning the outdated-marker regex:**

The default pattern is intentionally tight:

```
最新版|目前最新|currently v|latest v|just released|剛出|剛推出|截至 [0-9]{4}
```

Loose patterns (`現在|目前|currently`) produce too many false positives from rhetorical usage. Tight patterns catch actual version/date claims.

If your knowledge base uses different temporal conventions, edit the `PATTERNS` variable in `lint.sh`.

**After programmatic lint passes:** run an LLM Lint pass for semantic checks (contradictions, concept gaps, expired claims). The LLM reads `index.md` + all wiki pages, then appends findings to `lint-report.md`. See `METHODOLOGY.md` for the LLM Lint procedure.

---

## `log-append.sh`

Appends an entry to `log.md` at the repo root.

**Usage:**
```bash
./scripts/log-append.sh "description of what changed"
```

**Example:**
```bash
./scripts/log-append.sh "added wiki/harness-engineering-security.md, regenerated index"
```

**Output format:**

```markdown
## 2026-04-17

- description of what changed
```

Newest entries go on top (insert after the `# Wiki Change Log` header). The file is append-only — do not edit past entries.

---

## Run order after any change

```bash
./scripts/gen-index.sh                    # rebuild index
./scripts/lint.sh                         # programmatic health check
./scripts/log-append.sh "what you did"    # record the change
```

If `lint.sh` reports errors, fix them before the log-append. Warnings can be deferred to an LLM Lint pass.

---

## Making scripts executable

On first clone:

```bash
chmod +x scripts/*.sh
```

Windows users: run under Git Bash, WSL, or adapt the scripts to PowerShell.
