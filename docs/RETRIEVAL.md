# RETRIEVAL — row-granularity search over the pack corpus

`scripts/pack-search.py` answers one question: **"where is the thing I need?"** — which file,
which line, which section. It does not answer the question itself.

The repo carries 178,204 lines of markdown under `templates/`, of which 114,622 lines are pack
corpus. Almost none of that is a catalog; it is *argument* — personas, discipline catalogues,
ordered procedures, ❌/✅ pairs with consequence-reasoning. A query cannot replace reading it.
What a query *can* do is stop you from loading 100 KB of prose to find the four lines that
govern the change you are about to make.

Measured on this tree: a typical lookup returns ~2.2 KB against ~48 KB of source files it cites
— **22x** across the seven probe queries in the table below, with an honest low end of 3.3x when
every hit lives in one file. Claim the 22x on targeted lookups. Do **not** claim the 114k lines
became free; no session ever loaded them all.

---

## What is indexed — and what is deliberately not

The knowledge itself is not stored as rows. What is stored is the **row-shaped metadata about
the prose**: ~5,150 rows extracted from ~717 source files, each carrying `path` (with `:line`
wherever the source is line-addressable) so the next step is a `Read`, not a guess.

### Indexed (8 extractors)

Row counts below are a snapshot taken on 2026-08-20 (5,152 rows / 717 source files); they move
whenever a pack file is added. `python3 scripts/gen-pack-catalog.py --stats` prints the live
numbers, and `pack-search.py --kinds` prints them per kind with the owner list. Every kind in this
table carries its own floor in `scripts/test-pack-search.sh`, so a single extractor going dark is a
FAIL rather than a rounding error in the total — see **Maintenance** for why that check exists.

| Kind | Rows | Source | Why it is genuinely row-shaped |
|---|---:|---|---|
| `rule-directive` | 2,135 | `templates/{packs,domains}/*/rules/*.md`, bullets under a Must / Must-not / Should / Never / Checklist / Enforcement heading | One atomic assertion per bullet; complete standing alone |
| `domain-checklist` | 1,730 | `templates/business-domains/*/*.md`, `- [ ]` items with their section anchor | Designed as an enumerable capability list |
| `command` / `agent` / `skill` / `ai-pattern` / `rule` / `reference` | 583 | artifact frontmatter in `templates/packs/*/`, `templates/domains/*/`, `commands/*.md` — skills are `skills/<name>/SKILL.md` | Declarative `name` / `description` / `kind` / `applies-to` |
| `topic-*` | 389 | `templates/packs/*/_topics.md` YAML blocks | Already declarative YAML; zero loss |
| `stack-subst` | 77 | `templates/packs/*/STACK.md` substitution tables | Abstract concept → per-stack idiom; the `--stack` flag's native data |
| `closure-verb` | 72 | `### <n>. <kebab-case>` headings in `templates/packs/*/{skills/<name>/SKILL.md,commands/*.md,rules/*.md}` | Self-contained fingerprint → procedure → verify unit, from a closed set |
| `catalog-row` | 105 | the four `_registry.md` files | Already hand-maintained catalogs consumed by multiple phases |
| `trigger` | 55 | `templates/packs/_trigger-vocabulary.md` | Name + one-line semantics |

### Not indexed — on purpose

- **`templates/packs/*/_examples/` — 267 files, 32,724 lines.** AUTHOR-mode fallbacks: whole
  finished artifacts. A row of one is useless; the point is the complete shape. The topic
  spec's `fallback:` **pointer** is indexed, so the example is reached by path.
- **Agent personas.** `## The Premise (read first, do not deviate)` is a stance delivered by
  cumulative argument. The file-level frontmatter row points at it; the body stays whole.
- **The discipline catalogues** (`templates/packs/{align,migration}/references/*-discipline-catalogue.md`).
  They teach by ❌/✅ pairs with four to five lines of consequence-reasoning each. Row-splitting
  keeps the verdict and drops the reasoning — the exact opposite of what those files are for.
  Each contributes exactly one file-level pointer row, and `scripts/test-pack-search.sh` asserts
  it stays that way.
- **Ordered procedure steps.** `### 1. Generate current spec` → `### 5. Update baseline` is a
  sequence; order *is* the content. The extractor takes `### <n>. <kebab-case>` (an unordered set
  member) and rejects `### <n>. <Sentence case>` (a step). This repo already distinguishes the two
  by naming convention, which makes it a clean mechanical discriminator.
- **`_version.json` changelogs.** Release narrative, not catalog.
- **Prose bodies generally.** Bullets under a non-directive heading are argument, not assertions.

**The discriminator:** if the unit's meaning survives being read alone, out of order, it is a
row. If it needs its neighbours or its order, it is prose and the catalog holds only a pointer.

---

## How it works

```
source markdown ──► gen-pack-catalog.py ──► ~5,150 rows ──► BM25 index ──► filters ──► ranked pointers
  (~717 files)         8 extractors            9 columns      in memory      pack/domain/kind/scope/stack
```

**No committed index.** Extraction runs in ~300 ms cold, so a committed catalog would buy nothing
and add a tenth drift surface to police alongside the nine CI gates. The source markdown stays the
single source of truth.

**Cache, not artifact.** The built index is written to `tmp/pack-search/index.json` (`tmp/` is
already gitignored). The cache key is a SHA-256 fingerprint over every source file's size and
mtime, plus both script files, plus an `INDEX_FORMAT` constant — so editing any pack file
invalidates it automatically. There is no "regenerate before commit" chore, and there is nothing
that can go stale. `--rebuild` forces a rebuild; `--no-cache` skips it entirely.

Measured on this tree (min/mean/max over 5 runs):

| | Latency |
|---|---|
| Cold (`--rebuild --no-cache`) — extract ~5,150 rows from ~717 files, build BM25, query | 289 / 301 / 319 ms |
| Warm (cache hit) | 71 / 72 / 74 ms |

Both are inside the "callable inline by a command" budget.

**Ranking.** Okapi BM25, `k1=1.5`, `b=0.75`, with the non-negative IDF form
`log(1 + (N − df + 0.5)/(df + 0.5))` — some terms appear in more than half the rows. Field
weights: `name ×3`, `owner ×2`, `kind`/`anchor`/`text` ×1. The tokenizer lowercases, drops a
37-word stoplist, and **also emits kebab/snake sub-tokens**, which is what makes
`prefers-reduced-motion` reach `skills/motion-audit/SKILL.md`. Field values are deduped before term
frequencies are counted, so a row whose `description` repeats its H1 does not get triple credit.

**Row schema (9 columns).**

| Column | Meaning |
|---|---|
| `id` | stable key, e.g. `rule-directive:ui-ux:ui-principles:14` |
| `kind` | what the row *is* |
| `scope` | where its owner *lives* — `pack` / `domain` / `business-domain` / `registry` / `core` |
| `owner` | pack key, technical-signal key, or business-domain key — what `--pack` / `--domain` filter on |
| `name` | human label |
| `path` | repo-relative, with `:line` where line-addressable — **the payload** |
| `anchor` | the section heading the row sits under |
| `stack` | comma-joined stack keys this row is specific to (else empty) |
| `text` | searchable body, deduped across fields |

---

## CLI

```
python3 scripts/pack-search.py "<query>" [flags]

  --pack=<key>[,<key>]     restrict to pack owners            (templates/packs/_registry.md)
  --domain=<key>[,<key>]   restrict to technical-signal OR business-domain owners
  --owner=<key>[,<key>]    restrict to any owner key, whatever its scope
  --kind=<kind>[,<kind>]   rule-directive | closure-verb | topic-agent | command | ...
  --scope=<scope>          pack | domain | business-domain | registry | core
  --stack=<name>           bias toward a stack (nestjs, react, postgres, flutter, ...)
  --limit=N / --top=N      default 8, hard cap 25
  --format=text|json|paths default text; `paths` emits bare path:line for piping into Read
  --json                   alias for --format=json
  --rebuild / --no-cache   force re-extraction / never touch the cache
  --cache=<path>           repo-relative cache path (default tmp/pack-search/index.json)
  --kinds                  list available kinds / scopes / owners with counts
  --check                  catalog integrity + determinism + retrieval smoke test (exit 1 on fail)
  --repo-root=<dir>        matches every other script in scripts/
```

`--domain` resolves against **both** `templates/domains/_registry.md` (technical signals like
`payment`, `webhook`, `multi-tenant`) and `templates/business-domains/_registry.md` (product
domains like `ecommerce`, `fintech`, `lms`) — nobody remembers which registry a key lives in, and
the `scope` column labels which one answered.

`--stack` is a **bias, not a filter**: it adds the stack name to the query and multiplies the
score of rows whose `stack` column names it by 1.5. A hard filter would cut the corpus to 104
rows and destroy recall.

### The catalog generator

```
python3 scripts/gen-pack-catalog.py            # write tmp/pack-search/catalog.csv
python3 scripts/gen-pack-catalog.py --stats    # row counts by kind, write nothing
python3 scripts/gen-pack-catalog.py --stdout   # CSV to stdout (pipe it, diff it)
python3 scripts/gen-pack-catalog.py --format=jsonl --out=<path>
python3 scripts/gen-pack-catalog.py --check    # determinism + pointer integrity + freshness
```

`--check` is the CI-friendly gate. It (1) builds twice and byte-compares, (2) confirms every
emitted `path:line` resolves to a real file and a real line, (3) confirms ids are unique,
(4) FAILs on a `_topics.md` `kind:` outside the known vocabulary, and (5) regenerates and diffs
any on-disk catalog. That last check WARNs at the default `tmp/` path — a leftover scratch dump
going stale is not a defect — and FAILs when `--out=<path>` is passed explicitly, which is the
form to use if a catalog is ever written somewhere that is expected to stay fresh. Today it reports **9 WARNs** — real vocabulary drift the build
surfaced: seven topic specs across three packs use `kind: ai-pattern` where sixteen packs use `kind: pattern`, and
two use `kind: reference-pair`. Those are WARNs rather than FAILs because the drift predates this
tool; tightening them to FAIL is a one-line change once the vocabulary is unified.

---

## How a command invokes it

Follow the existing script-invocation idiom (`~/.claude/scripts/<name>` after
`sync-to-global.sh`), with the same **agent-side discipline** framing the repo uses for
validators — nothing halts a run automatically.

```bash
# Phase 4.0 preflight — instead of reading a whole _topics.md (backend's is 444 lines;
# all 20 packs total 3,103) to find which topics a feature touches.
python3 ~/.claude/scripts/pack-search.py "$FEATURE_DESCRIPTION" \
  --pack="$SELECTED_PACKS" --kind=topic-agent,topic-command,topic-skill --top=12
```

```bash
# Locate the governing rule directive without loading 25 rule files.
python3 ~/.claude/scripts/pack-search.py "$AXIS" --kind=rule-directive --top=6 --format=paths
```

```bash
# Resolve a closure verb from a finding, instead of inlining the verb list into a command.
python3 ~/.claude/scripts/pack-search.py "$FINDING" --kind=closure-verb --pack=ui-ux --top=3
```

`--format=paths` emits bare `path:line` lines, one per result, deduped — meant to be piped
straight into a `Read`.

### Three highest-leverage call sites, in order

1. **Phase 4.0 / 4.2 topic lookup.** "Read the topic spec" today means reading a whole
   `_topics.md`. A `--kind=topic-*` query returns the dozen specs that matter with their line
   numbers.
2. **`templates/repo-baseline/.claude/hooks/inject-path-rules.sh`.** The hook already computes an
   injection point and dedupes per `session_id`. Feeding it BM25-ranked `rule-directive` rows for
   the edited file upgrades it from glob-matched *files* to relevance-ranked *rows*, with no new
   plumbing. (Not wired today — the hook still injects whole rule files.)
3. **De-duplicating the closure-verb vocabularies.** The 19-verb phrasing appears in 23 files and
   the 21-verb phrasing in 28; `commands/polish.md:42` inlines the 16-axis list verbatim from
   `ui-principles.md § Axis catalog`, and lines 44-50 inline all 19 verbs. One query replaces every
   copy — and `scripts/audit-command-dry.sh` already exists to police exactly that class of
   duplication.

Adoption is the real work, not the script. Ship it standalone with `--check` first; wire the call
sites second; only then treat it as infrastructure.

---

## How this complements the import tiers

`templates/import-tiers.md` is the contract for what the orchestrator loads. It is honest about
its own limit: *"Tier annotation is a HINT to the agent… Today, agents may still load all imports
if the prose references them indirectly."* Its stated M5+ goal is a loader script that strips
non-active-tier imports.

Search does not replace that, and it must never be proposed as a way to shrink HOT. The two solve
orthogonal problems:

| | Import tiers | `inject-path-rules.sh` | `pack-search.py` |
|---|---|---|---|
| Granularity | file | file | **row** |
| Keyed by | active phase | the edited file's glob | **query relevance** |
| Governs | the orchestrator's own imports (HOT / WARM / COLD) | project rules at edit time | **the 114,622-line pack corpus** |
| Enforcement | honor system | mechanical (PreToolUse hook) | mechanical (a query returns N rows or it does not) |
| Answers | "what does this phase need?" | "what governs this file?" | **"where is the thing I need?"** |

Three specific complements:

1. **Tiers govern a corpus search never touches.** HOT is cross-cutting invariants —
   critical-execution-rules, hard-rules, the decision engine, idempotency. Those must be
   *resident*, not retrieved: they gate every phase and no query would surface them at the right
   moment. Search is irrelevant to HOT by construction.
2. **Search makes COLD genuinely cold.** COLD is "unbounded, load on explicit demand" — but demand
   requires knowing the file exists. A query surfaces `templates/appendices.md:<line>` without
   loading the file, which turns COLD from an aspiration into a real state.
3. **Search covers what tiers never classified.** The pack corpus is not HOT, WARM, or COLD — it
   is copied to disk in Phase 4.2 and read ad hoc afterward. That 114,622-line body is where the
   whole win sits.

**The contract in one line: tiers decide what is RESIDENT; search decides what is REACHABLE.**
A row is never a substitute for its file — it is the *address* of its file. Every result cites
`path:line` precisely so the next step is a `Read`.

---

## Honest limits

1. **BM25 is lexical, not semantic.** There is no embedding model in a stdlib script. A query
   phrased in vocabulary the corpus does not use will miss. The mitigations are the kebab/snake
   sub-token split and a small hand-curated synonym map in `pack-search.py` (`a11y` ↔
   `accessibility`, `n+1` ↔ `eager`/`batch`, `authz` ↔ `authorization` — 32 entries in all, scored at
   0.6 of a literal hit). That map is not exhaustive and is not a substitute for recall you can
   rely on.
2. **The index finds the *file*; it cannot answer from the *prose*.** Body text is deliberately
   unindexed, so a passage that lives only inside a Halt-conditions block will not be quoted back
   to you — at best the query lands on the file that contains it. This is why the text output
   carries a mandatory footer saying so, and why `--json` carries the same `disclaimer` field.
3. **Filters are load-bearing, not convenience.** Unfiltered domain queries misfire: *"checkout
   guest cart abandoned"* returns `marketplace` rows and zero `ecommerce` rows, because
   marketplace's checklist happens to use more of those words. `--domain=ecommerce` returns
   exactly the right rows. Scope alone does not fix it — the filter must key on `owner`.
4. **A row is not a rule.** `ui-principles.md`'s axis catalog is row-shaped, but the paragraph
   above it ("this catalog plays a DUAL role… re-scoping this section silently breaks the
   delegation") is a load-bearing invariant that no row carries. Index the rows, point at the
   section, never substitute for reading it.
5. **The corpus is argument, not catalog.** This is not "the knowledge is now queryable." The
   competitor shape it superficially resembles — a component catalog where a row *is* a complete
   answer — does not transfer. Here rows are addresses.
6. **Coverage is bounded by the eight extractors.** `templates/repo-baseline/` and
   `templates/workspace-baseline/` commands, `templates/phases/`, `templates/governance/`, and
   `templates/tool-adapters/*/adapter.md` are **not** indexed today. `--kinds` prints exactly what
   is in the index; do not assume anything else is reachable.
7. **The measurements above are from this tree on one machine.** Re-measure before quoting them
   elsewhere: `scripts/test-pack-search.sh` prints its own cold/warm timings (it runs the whole
   fixture, so its cold number includes more than one query), and
   `gen-pack-catalog.py --stats` prints the live row counts. The probe-query byte table is not
   reproduced by any script — it was measured by hand on 2026-08-20 with `--limit=8`, taking
   "output" as the byte length of the text result and "source bytes" as the total on-disk size of
   the distinct files it cited.

### Measured context saving (7 probe queries, `--limit=8`)

| Query | Output | Files cited | Source bytes | Ratio |
|---|---:|---:|---:|---:|
| `multi-tenant isolation cross-tenant leak` | 2,378 B | 7 | 51,247 B | 21.6x |
| `focus ring keyboard accessibility contrast` | 2,166 B | 5 | 81,178 B | 37.5x |
| `n+1 query eager loading` | 2,401 B | 8 | 104,889 B | 43.7x |
| `webhook signature verification replay` | 2,075 B | 2 | 21,451 B | 10.3x |
| `idempotency key retry payment` | 2,236 B | 2 | 12,922 B | 5.8x |
| `guest checkout cart merging --domain=ecommerce` | 1,896 B | 1 | 6,244 B | 3.3x |
| `repository pattern dependency injection --stack=nestjs` | 2,255 B | 7 | 61,507 B | 27.3x |
| **total** | **15,407 B** | | **339,438 B** | **22.0x** |

Bytes, not tokens — bytes are what was actually measured. The ratio is the saving *only if you
would otherwise have read those files whole*; when the answer is one line in one file, the
saving is small, and the 3.3x row is there to keep that visible.

---

## Maintenance

`scripts/test-pack-search.sh` is the regression fixture. It asserts, in order: the catalog builds
deterministically and every pointer resolves; two independent runs are byte-identical; the JSONL
export parses; total row count clears a floor of 4,500 **and each of the 17 stable kinds clears its
own floor**; `_examples/` and the discipline catalogues stay unindexed; ordered procedure steps are
never captured as closure verbs; twelve known queries still surface the right rows; `--pack` /
`--domain` / `--kind` actually constrain; the hard cap holds; the disclosure footer is present; a
no-match query says so instead of fabricating a hit; the cache is written, reused, and invalidated
by touching a source file; and ranking is identical across a cache hit and a rebuild.

```bash
bash scripts/test-pack-search.sh
```

**Why the per-kind floors exist.** They were added after this exact failure: `skills/` migrated from
one flat `skills/<name>.md` per skill to a directory per skill holding `SKILL.md`, and
`gen-pack-catalog.py` kept globbing the flat path. All 98 `skill` rows and all 72 `closure-verb`
rows left the index silently. The total was still 4,982 — clear of the 4,500 floor — so the only
check that could have caught it did not, and this doc advertised two kinds and one worked example
that returned nothing. A total-row floor cannot see one extractor go dark; a per-kind floor can.
The three vocabulary-drift kinds (`pattern`, `topic-ai-pattern`, `topic-reference-pair`) are
deliberately left without a floor, because unifying the `kind:` vocabulary is *supposed* to drive
them to zero.

It is not wired into `.github/workflows/quality-gates.yml`. Wiring it is a one-line addition to
that file once the retrieval layer has call sites depending on it; until then it runs on demand.

When you add an extractor, add a row-count line to the table above, an assertion to
`test-pack-search.sh`, and bump `INDEX_FORMAT` in `pack-search.py` so existing caches are
rejected rather than silently reused.
