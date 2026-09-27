# AGENTS.md — Schema for LLMs operating this repo

You are operating on a knowledge base built on the LLM Wiki pattern (Karpathy 2026), with four optimizations: an atom layer, topic-branch organization, two-layer Lint, and parallel-compile naming locks.

This file is the formal spec — read it before touching anything. Mental model, operations, file formats, lifecycle rules, and what you must never do.

CLAUDE.md and AGENTS.md carry this same spec for different loaders. Any edit must be applied to both files, keeping them identical apart from the title line and the closing note.

---

## Mental model

Three storage layers, one navigation layer, one log layer:

```
raw/                  sources; read only during Ingest and DeepQuery, never write
atoms/                knowledge atoms, organized by topic-branch
  <branch-1>/         one folder per topic
  <branch-2>/         each contains atoms (source of truth)
  ...
wiki/                 compiled pages from atoms, derived cache
index.md              auto-generated wiki navigation
log.md                append-only change history
```

Atoms are immutable. Wiki is rebuildable from atoms. If a wiki page is wrong, fix the underlying atom and recompile, never patch the wiki.

Each branch folder under `atoms/` holds the atoms for that topic, plus an optional `_archive/` for superseded atoms.

---

## Atom format (spec)

### Frontmatter (YAML, required)

```yaml
---
id: <branch>/<descriptive-slug>
type: explanation | opinion | tutorial | myth-busting | case-study | comparison
depth: beginner | intermediate | advanced
source_type: post | reply | thread | transcript | article | note | screenshot | audio
source_ids: []
reuse_score: high | medium | low
tags: []
created: YYYY-MM-DD
---
```

| Field | Notes |
|-------|-------|
| `id` | Format `<branch>/<slug>`. Slug all lowercase, hyphens only. Must be unique within branch. |
| `type` | What kind of knowledge this atom carries. Pick one. |
| `depth` | Audience level. Used in gap analysis. |
| `source_type` | Where the raw came from. Extend the enum if your sources differ. |
| `source_ids` | Stable identifiers (URLs, paths, post IDs). Atoms without source attribution are not auditable. |
| `reuse_score` | `high` = standalone-publishable, `medium` = needs companions, `low` = niche. |
| `tags` | Cross-cutting concerns. Used to surface related atoms across branches. |
| `created` | ISO date. Used for chronological ordering and stale-detection. |

Optional fields you may add: `confidence` (high/medium/low), `superseded_by` (id of replacement atom), `archived` (boolean).

### Filename

Pattern: `YYYY-MM-DD-<descriptive-slug>.md`

- Date prefix gives natural chronological order in `ls`.
- Slug all lowercase, hyphens only — no underscores, no spaces, no uppercase.
- Slug should be 3–6 words describing the core claim.

### Body

- One core claim per atom. If two independent claims share a paragraph, split into two atoms.
- Refine, don't copy. Strip filler from the source; preserve the author's voice and stance.
- Cite source at the end if you want traceability beyond `source_ids`.

### Lifecycle (immutable)

Atoms are immutable. Do not edit after creation.

When knowledge evolves:
1. Create a new atom with the updated claim.
2. Add `superseded_by: <new-atom-id>` to the old atom's frontmatter.
3. Move the old atom to `atoms/<branch>/_archive/`.
4. Recompile any wiki page that referenced the old atom.

Never delete an atom outright. Use `_archive/`. Final deletion is a separate, conscious decision.

See `atoms/_template.md` for a copyable starter.

---

## Wiki page format (spec)

### Filename

Pattern: `<branch>-<topic-slug>.md`

- Branch prefix lets `gen-index.sh` group pages.
- All lowercase, hyphens only.
- Lives flat in `wiki/`, not in subfolders.

### First line

Must be `# Title`. `gen-index.sh` reads this for the index entry. Lint flags violations.

### Wiki links

Pattern: `[[slug]]` or `[[slug|display text]]`

- The slug must equal an existing wiki filename without `.md`.
- Lint flags ghost links and orphan pages.

### Body structure

```markdown
# Page Title

Opening paragraph: why this matters, common misconception, what you'll get.

## Section
Integrated content from multiple atoms, written as coherent prose.
First mention of a related concept gets a [[wiki-link]]; subsequent
mentions in the same page don't repeat it.

## Section
Continue.

---

**See also**
- [[related-page]] — one-line description

---
*Compiled from atoms: branch/atom-slug-1, branch/atom-slug-2, ...*
```

### Length

- Target 1500–2500 words per page.
- Past 2500 words: consider splitting.
- Below 800 words: consider merging or staying at atom level.

### Temporal markers

In time-sensitive claims, use one of:
- Specific date: `as of 2026-04`, `截至 2026-04`
- Version number: `v3.5`, `Claude 3.5 Sonnet`

Avoid bare `currently` / `latest` / `now` / `目前` / `現在` in time-sensitive contexts. Lint regex flags only `<temporal word> <version/date>` combinations to avoid false-positive flooding from rhetorical use.

See `wiki/_template.md` for a copyable starter.

---

## Branch design (spec)

### When to add a branch (all four required)

1. **Independence** — the topic doesn't fit cleanly under any existing branch.
2. **Scale** — you expect 5+ atoms in this branch.
3. **Clear boundary** — you can write a one-paragraph rule for "what belongs, what doesn't".
4. **Teaching independence** — the branch could anchor a 30-minute talk on its own.

If only 1–2 atoms fit a candidate topic, use tags instead.

### When to merge or remove

- **Hollow** — branch holds <3 atoms with no growth trajectory.
- **Overlap** — >50% of atoms also tagged with another branch → merge or redefine.
- **Subset** — branch A's content is essentially a subset of branch B → merge.

### When to split

- **Bloat** — single branch exceeds 30 atoms and content naturally clusters.
- **Teaching need** — preparing a course reveals the branch needs to split.

### One atom, one branch

If an atom spans two branches, pick the one matching the core claim. Use `tags` for the secondary topic.

### Operations checklist

When adding/merging/splitting:
1. Document the rationale (one-paragraph note in `log.md`).
2. Update branch lists in any docs that enumerate them.
3. Move affected atoms (update their frontmatter `id`).
4. Confirm no orphan tags or broken `[[ ]]` references remain.

---

## Operations

You execute five operations on demand:

## Operation Selection

Choose the operation before responding.

- Between Query and DeepQuery, use the one the user specifies. If the user does not specify, default to Query.
- Never switch from Query to DeepQuery automatically. If Query cannot produce a well-supported answer, stop, report what was found, and recommend that the user rerun the question as DeepQuery.
- Do not explain the Query or DeepQuery procedure unless the user explicitly asks how they work.
- Once an operation has been selected, execute it instead of describing it.

Both Query and DeepQuery measure retrieval in lookup rounds. A lookup round means one iterative retrieval cycle: within one round, multiple related files may be read before deciding whether another retrieval round is needed. The initial `index.md` read does not count as a round.

### Ingest

User adds new material to `raw/` (or any source location). You read it, classify each segment ("extract" / "skip" / "deferred"), then extract the "extract" segments into atoms under the matching `atoms/<branch>/` folder.

#### Inputs to confirm before starting

- **Source path** — the `raw/...` folder or file to ingest.
- **Target branch** — the `atoms/<branch>/` folder. If the branch does not yet exist, surface candidate branches to the user and get approval before creating one (see "Branch design" rules above).
- **Scope** — full source vs. pilot subset. For large corpora (50+ files) prefer a pilot of 1 branch first, then expand after the user reviews atom style.

#### Procedure

1. **Read all source files in scope.** If a file has structured headers (`doc_meta`, summary, keywords), use them as a high-level map before reading bodies. For files too large to fully read, the structured summary plus a body sample is acceptable — note this in your report.
2. **Classify each segment** as one of:
   - `extract` — contains a claim, decision, rule, principle, or non-obvious fact worth preserving.
   - `skip` — pure reference data (lookup tables, ID lists, raw form fields). Reference data belongs in the source, not in atoms.
   - `deferred` — claim is real but ambiguous (cross-branch, unclear scope, possibly duplicates an existing atom). List for user confirmation.
3. **Decompose `extract` segments into atoms.** One atom = one claim. If a paragraph carries two independent points, split.
4. **Write each atom** as `atoms/<branch>/YYYY-MM-DD-<slug>.md` with the frontmatter spec above. Body structure:
   - First line: a single sentence stating the core claim.
   - Then: background, rationale ("why"), supporting facts, edge cases — in the author's voice.
   - End with `> 出典:` (or equivalent) pointing to the source section if traceability beyond `source_ids` is useful.
5. **Run the post-change scripts** (see "After every change" below): `gen-index.sh` then `log-append.sh "ingest: <branch> from <source-path>, N atoms"`.
6. **Report to the user**: atom count, topic distribution, judgment calls made (e.g. how reference-heavy files were handled), and the deferred list. Wait for review before continuing to the next branch or compiling.

#### Constraints

- One atom equals one claim.
- Use the frontmatter format above. Do not invent fields.
- Place atoms in the matching topic-branch. If no branch fits, list as deferred candidate; do not invent branches without user approval.
- Preserve the author's voice. Personal knowledge base, not neutral encyclopedia.
- Atoms are immutable once created.

#### Anti-patterns

- **One row = one atom.** Tables of jobs, IDs, or config rows are reference data — don't atomize them. Extract the *design rule* behind the table instead.
- **Topic-as-title atoms.** A title like "About session-crossing conditions" is a chapter heading, not a claim. Rephrase as the actual assertion ("Session-crossing trigger requires 361-min gap from prior-day ending").
- **Splitting one claim across multiple atoms** because the source had multiple paragraphs about it. Merge into a single atom; the body can carry the nuance.
- **Bulk-extracting at uniform depth.** Some sources yield 1 atom; others yield 15. Vary based on claim density, not file count.

### Compile

Take a set of related atoms and produce a wiki page synthesizing them.

Constraints:
- Group by topic, not one atom per page. Typical wiki page = 3–8 atoms.
- Filename `<branch>-<topic-slug>.md`, all lowercase, hyphens only.
- First line must be `# title`.
- Use `[[wiki-link]]` for cross-references. Slug inside `[[ ]]` must equal an existing wiki filename without `.md`.
- For temporal claims, use specific dates or version numbers.
- Footer lists source atoms by id.

If multiple agents compile in parallel: a coordinator pre-locks the slug list. Each agent fills assigned slugs, never names files.

### Query Workflow

The following workflow is called "Query".

Objective:
Answer from wiki pages and their referenced atoms only, favoring speed over completeness. Query is a lightweight retrieval mode.

Retrieval boundary:

- Allowed file reads, exhaustively: `index.md`, pages under `wiki/`, and atoms under `atoms/` referenced by the selected wiki pages. Listing a single `atoms/<branch>/` directory to resolve an atom id to its filename is allowed and does not count as a lookup round.
- Everything else is out of bounds — in particular anything under `raw/`, and any search tool (grep, glob, semantic or repository-wide search, whatever the tool is named). Out of bounds is a rule, not a technical limitation: the files are readable, and you must still not read them.
- In Query, the traceability chain terminates at the atom layer. `source_ids` and `> 出典:` paths inside an atom are attribution metadata to quote in the answer, never links to follow. If confirming a claim would require opening anything under `raw/`, that claim is outside Query's boundary: answer at the level already verified and recommend DeepQuery.
- `index.md`: read exactly once, at the start, to select candidate wiki pages.
- Lookup rounds: at most 2. Round 2 is allowed only to close a specific evidence gap identified in round 1, not for general exploration.
- Wiki pages: at most 3 per round, at most 6 in total.
- Do not re-read a page already read in the current query.

Constraints:

- Read only the minimum number of wiki pages required to answer; do not read all "directly relevant" pages, and do not fan out across multiple branches.
- Answer as soon as sufficient evidence is found. Do not continue retrieval to increase confidence or completeness.
- If multiple interpretations exist, return the best-supported one instead of exhaustively resolving all.
- If the required information is unavailable within this boundary, stop, report what was found, and recommend that the user switch to DeepQuery. Do not switch automatically.
- Always include source references, at the deepest level actually verified:
  - `[[page-slug]] > atom-id` — only when you have read that atom (or the page attributes the claim to it unambiguously) and confirmed it supports the claim.
  - `[[page-slug]]` — when the claim comes from a wiki page and the supporting atom was not identified. A page footer listing its compiled atoms does not establish which atom supports which sentence; do not copy atom ids from the footer.
  - Never guess or fabricate an atom-id. A page-level reference is correct; an unverified atom-id is an error. If the user needs atom-level attribution, recommend DeepQuery.
- Before answering, audit your own reads: every file read during this query must be `index.md`, a wiki page, or a referenced atom. If anything else was read, discard the evidence taken from it and report the boundary violation in the answer.



### DeepQuery Workflow

The following executable workflow is called **DeepQuery**.

DeepQuery traces evidence through wiki → atom → raw sources. It runs only when the user explicitly requests it (see "Operation Selection"); never enter it automatically.

Reading files under `raw/` is not only allowed but expected in DeepQuery: following `source_ids` from atoms into `raw/` is the core of this workflow. The prohibition on reading `raw/` belongs to Query only — never carry it into DeepQuery. Do not abandon a question at the atom layer while its `source_ids` point to unread raw files. (`raw/` remains read-only: read it freely, never write to it.)

Once invoked, execute the workflow immediately.

Objective:
Verify every answer-relevant claim through the repository's traceability chain rather than simply finding supporting evidence. Unlike Query, DeepQuery prioritizes verified, fully traceable answers over response speed.


Autonomous Execution:

- DeepQuery is autonomous.
- Execute the next retrieval step immediately whenever it is uniquely determined by the current evidence chain.
- Do not stop to ask the user which file, wiki page, atom, or raw source to inspect when the workflow already determines the next step.
- Request user guidance only when:
  - the current traceability chain has been exhausted,
  - required evidence is outside the repository,
  - or multiple equally valid evidence paths would lead to materially different answers.

Procedure:

1. Read `index.md` once to identify candidate wiki pages.
   Do not rescan `index.md` during the same DeepQuery session.

2. Read every wiki page that is directly relevant to the current evidence gap.
   Do not expand to indirectly related topics.

3. Identify the referenced atom IDs from the selected wiki pages.

4. Before each additional lookup round, explicitly identify the evidence gap to be closed
   (for example: an unverified claim, an unread source, or a contradiction).

5. Perform additional lookup rounds only to close the identified evidence gap.
   Do not expand retrieval merely to improve confidence or general coverage.

6. Use at most five lookup rounds.
   If evidence gaps remain after five rounds, report the unresolved gaps instead of continuing retrieval.

7. Read the referenced atoms.
   Read the frontmatter to obtain `source_ids`.
   When competing or overlapping claims exist, read the relevant atom bodies before selecting the evidence.

8. Follow the referenced `source_ids` to the corresponding raw source files.
   Read only the raw sources necessary to verify the claims used in the final answer.

9. Verify every answer-relevant claim by tracing

   wiki → atom → raw

   If any level disagrees with the level below it, report the discrepancy.
   The raw source is treated as the ground truth.

10. A claim is complete only after its traceability chain has been:
   - verified against the raw source,
   - explicitly marked as unverified,
   - or marked as having no attributed source.

11. Produce the final answer together with the complete traceability chain.

12. Continue retrieval only by following the repository's traceability chain.
    Grep, glob, and repository-wide search are prohibited throughout DeepQuery; the only exception is when the current traceability chain cannot proceed.


Evidence Validation:

Do not stop at the first supporting evidence. A claim is verified only when the raw source satisfies every explicit constraint in the user's question — time period, version, scope, and applicability conditions. Reject evidence that only partially matches.

Count only atoms that are part of the answer's actual traceability chain: referenced by a consulted wiki page, or reached through `source_ids`. Exclude superseded atoms (`superseded_by` set) and atoms under `_archive/`, unless the question is explicitly about the history of a claim.

If every candidate chain is rejected, conclude that no verified answer exists rather than returning the closest match. When evidence is inconclusive, state explicitly that no claim satisfying all constraints could be verified.

Output:

The final answer MUST explicitly list every evidence chain used.

Each verified claim MUST appear as one row in the following table:

| 項目 | 回答 | wiki | atom | raw | 検証 |
|------|------|------|------|------|------|
| ... | ... | [[page-slug]] | branch/atom | raw/path | 確認済 / 未確認 / 出典なし |

`検証` records whether the claim was confirmed against the raw source (`確認済`), left unverified because the chain was incomplete (`未確認`), or rests on an atom with no `source_ids` (`出典なし`).

Record `確認済` only after the raw source file itself was read during this DeepQuery session and found to support the claim, including every explicit constraint in the question. Agreement at the wiki or atom layer never justifies `確認済`. If the raw source was not read, or was read and does not support the claim, record `未確認` and report the discrepancy — a false `確認済` is worse than an honest `未確認`.


Constraints (rules not already covered by the Procedure above):

- Treat only answer-relevant factual assertions as claims requiring verification.
- Reuse evidence already verified during the current DeepQuery session; do not reopen a verified traceability chain merely to increase confidence.
- Never conclude that a capability is absent until the directly relevant traceability chain has been exhausted.


### Lint

Two layers, run in order:

**Programmatic Lint** (`scripts/lint.sh`) — runs first, no LLM needed. Checks ghost links, orphan pages, format violations, outdated markers. Output: `lint-report.md`.

**LLM Lint** — runs after programmatic Lint passes. Read `index.md` plus all wiki pages and check:
- **Contradictions** — page A says "X is best practice", page B says "X is deprecated". Flag both with paths and quoted segments.
- **Concept gaps** — multiple pages reference a concept that has no dedicated page. Propose as candidate.
- **Expired claims** — version numbers, dates, temporal markers in time-sensitive contexts. Verify or flag.
- **Weak orphans** — pages with weak conceptual link to the rest, even if technically linked.

Append findings to `lint-report.md` under an `## LLM Lint` section, sorted by severity (contradictions > concept gaps > expired claims > weak orphans).

---

## After every change

Run these in order:

```bash
./scripts/gen-index.sh                    # rebuild index
./scripts/log-append.sh "what you did"    # record change
```

Then if you compiled or modified wiki pages:

```bash
./scripts/lint.sh                         # programmatic Lint
```

If `lint.sh` reports errors (not just warnings), fix them before declaring done.

---

## Source attribution patterns

Three options for `source_ids`:

```yaml
# URL-based (public content)
source_ids: ["https://example.com/post/12345"]

# File-based (private materials)
source_ids: ["lectures/2026-04-12-skill-design.md"]

# Hash-based (when source stability matters)
source_ids: ["sha256:abc123..."]
```

Use hash IDs when you need to detect that a source was modified after extraction.

---

## What you must not do

- **Edit atoms after creation.** They are immutable. Create a new atom, archive the old one.
- **Write to `raw/`.** It is read-only from your perspective.
- **Invent branches without user approval.** Branch design has independence/scale/boundary criteria.
- **Use bold/italic to compensate for unclear writing.** If a sentence needs emphasis to be understood, rewrite the sentence.
- **Patch wiki pages to hide atom-layer problems.** If the wiki is wrong because an atom is wrong, fix the atom.
- **Compile in parallel without a slug lock.** You will produce naming collisions.
- **Treat the wiki as source of truth.** It is a derived cache. The atoms are truth.
- **Silently delete atoms or wiki pages.** Move to `_archive/`, never `rm`.

---

## Customizing for your domain

The defaults ship with reasonable opinionated choices. To adapt:

- **Add `source_type` values** for your sources (e.g. `email`, `slack`, `obsidian`).
- **Add `type` values** if your knowledge has categories beyond the seven defaults.
- **Adjust temporal regex** in `scripts/lint.sh` to match your conventions.
- **Define your own branch boundary table** in your fork's `STORY.md` or methodology notes.
- **Tune length thresholds** if your wiki style is denser or looser than 1500–2500 words.

Document any deviation — rules and scripts are coupled, divergence without documentation will confuse future contributors (including future-you).

---

## When in doubt

Defer to the user. This repo represents their knowledge, organized to their standards. Your job is to operate the pipeline reliably, not to make judgment calls about what their knowledge should look like. If something feels ambiguous, surface it instead of guessing.

---

*This schema corresponds to the AGENTS.md role in the LLM Wiki pattern (Karpathy 2026), extended with the four optimizations this repo adds (atom layer, topic-branches, two-layer Lint, parallel-compile naming locks).*
