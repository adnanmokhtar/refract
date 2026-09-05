---
description: Search this project's existing ai/ memory — the dynamic sinks, the don't-retry failure catalog, ADRs, patterns, runbooks, conventions, and the archives — with the same stdlib BM25 that indexes the pack corpus. Returns ranked POINTERS (path:line), never a paraphrase. Read-only; stores nothing, adds no sink.
kind: command
pack: learning
allowed-tools: [Read, Grep, Glob, Bash]
---

# /recall <query> [--kind=] [--owner=] [--since=] [--limit=] [--format=]

**The memory already exists; this finds it.** `/learn-from-task` writes the `ai/dynamic/` sinks and `knowledge-curator` promotes them into the formal layer. Until now the only ways back in were `session-start.sh`'s `tail -10` and grepping by hand — so `ai/failures/_index.md`, whose entire value lands at the moment someone is about to retry a failed approach, was effectively write-only.

This command adds **retrieval and nothing else**. No new sink, no new file format, no second place to write. The corpus is the `ai/` tree that is already there.

## When to use / NOT to use

- USE: before planning an approach in an area this project has worked in before ("have we tried this?").
- USE: when a correction feels familiar — `/recall "raw query in service"` finds the `feedback-learned.md` entry rather than earning the same correction twice.
- USE: to reach an archive. The curator archives interaction-log entries past 90 days and prunes the changelog past 200 lines; `ai/audits/**` is indexed, so archived stops meaning gone.
- NOT: to answer the question. Every result is an address. Read the cited `path:line` before acting on it.
- NOT: to search the framework's own pack corpus — that is `scripts/pack-search.py` with its default `--catalog=pack`.
- NOT: on a project that has never run `/learn-from-task`. An empty index says so plainly; it does not fall back to another corpus and it does not invent a row.

## Args

```
/recall "cart cache key tenant"                       # top 8 pointers, ranked
/recall "why is checkout slow" --limit=3              # hard cap is 25
/recall "payment retry" --kind=memory-failure         # only the don't-retry catalog
/recall "repository layer" --owner=feedback-learned   # only user corrections
/recall "n+1" --since=2026-06-01                      # entries dated on/after
/recall "webhook" --format=paths                      # bare path:line, pipe into Read
```

| Flag | Effect |
|---|---|
| `--kind=<k>[,<k>]` | `memory-failure` · `memory-correction` · `memory-learning` · `memory-pattern` · `memory-decision` · `memory-adr` · `memory-drift` · `memory-interaction` · `memory-convention` · `memory-runbook` · `memory-archived` · `memory-session` · `memory-note` |
| `--owner=<o>[,<o>]` | the sink or directory a row came from — `learnings`, `feedback-learned`, `failures`, `decisions`, `patterns`, `runbooks`, `conventions`, `audits`, `sessions` |
| `--since=<YYYY-MM-DD>` | keep only rows whose entry date is on or after this. The engine has no date filter, so this is applied **agent-side** over the returned rows — raise `--limit` when you use it, or a date filter over 8 rows can legitimately return zero. Sinks are dated `### <YYYY-MM-DD> — <label>`; undated rows (ADRs, patterns, conventions) are kept and labelled undated. |
| `--limit=N` / `--top=N` | default 8, hard cap 25 |
| `--format=text\|json\|paths` | `paths` emits bare `path:line`, deduped, for piping into a Read |

## Phases applied

RETRIEVE type — 1, 3. There is no Phase 4/5: this command writes nothing, promotes nothing, and never touches `ai/`.

## Phase 1 — Understand

- Confirm the query is a query, not a task. `/recall` returns addresses; acting on them is the caller's next step.
- Confirm the project has an `ai/` tree. If it does not, say so and stop — `/setup-project` creates it.

## Phase 3 — Retrieve (the whole command)

Run the shared engine against the memory catalog:

```bash
python3 ~/.claude/scripts/pack-search.py "$QUERY" \
  --catalog=memory --repo-root="$PWD" --limit="${LIMIT:-8}"
```

`--catalog=memory` selects `scripts/gen-memory-catalog.py` as the row producer; everything else — tokenizer, BM25 (`k1=1.5`, `b=0.75`), field weights, synonym expansion, filters, the hard cap, the pointer footer — is the same code that serves `pack-search.py`'s default corpus. There is no second index and no second ranking model to keep in step.

**Monorepo**: `--repo-root=<package-dir>` roots the search at that package's `ai/`. The workspace baseline ships a workspace-level `ai/`, so a workspace query is `--repo-root=<workspace-root>`.

The index is a derived cache at `.claude/_memory-index.json`, fingerprinted on every source file's size + mtime and rebuilt on mismatch. It is gitignored (Phase 4.1 writes the entry), never committed, and therefore adds no drift surface — the `ai/` files stay the single source of truth.

## Output

```
score  kind               owner                path
9.89   memory-correction  feedback-learned     ai/dynamic/feedback-learned.md:50
       Never write raw queries inside a service — 2026-06-03 — Repeated: 3 — Rule: always route…
       § Log
7.09   memory-failure     failures             ai/failures/_index.md:37
       Redis-backed cart cache keyed by user id — cache key omitted the tenant prefix…
       § Catalog

12 rows indexed from this project's ai/ tree (pointers only). Rows point AT the
memory file; they do not replace it. Read the cited path before acting.
```

On an empty corpus, the whole output is:

```
no memory captured yet — this project's ai/ tree holds no indexable entries.
Run /learn-from-task at the end of a session; the sinks it writes are what this searches.
```

## What to do next — required closing section

Every run MUST end with a `## What to do next` block: the pointers re-expressed as ONE ordered, numbered to-do — **DO NOW** (read the cited `path:line` of every `memory-failure` and `memory-correction` hit before writing code that touches the same area) → **REVIEW** (`memory-drift` / `memory-decision` rows that may already answer the open question, and `memory-archived` rows that show what was measured last time) → **OPTIONAL** (nothing matched an axis you expected — that is a capture gap, so the step is `/learn-from-task` at the end of this session). Where a sibling command does the work better, the step IS the paste-ready command: `/promote-pattern <name>` when a `WATCHING` entry has clearly earned promotion, `/promote-decision <id>` for a `VALIDATED` pending decision, `/audit-knowledge` when the hits are visibly stale. A no-match run collapses to a single line ("nothing in project memory matches — this is new ground"). Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Halts

- None. Read-only by construction — no write path exists in this command.

## Honest limits (state these; do not overclaim)

- **BM25 is lexical, not semantic.** "Why is checkout slow" will not reach "N+1 in the cart repository" unless the words overlap. The mitigations are kebab/snake sub-token splitting and a small hand-curated synonym map. There is no embedding model — that would break stdlib-only and offline.
- **A row is a pointer, not an answer.** The snippet is a truncated extract. The cited file is the memory.
- **No cross-project memory.** A lesson learned in project A stays in project A. The per-user store at `~/.claude/projects/<encoded>/memory/` belongs to the host, not to this framework.
- **No semantic dedup.** The same lesson recorded twice returns twice. Deduping is `knowledge-curator`'s job, at threshold, with a human.
- **Recall does not fix capture.** A hook cannot understand a session; only `/learn-from-task` turns one into a sink entry, and that stays human-dispatched. Memory quality is bounded by capture discipline, which this command does not improve and does not claim to.
- **`ai/conventions.md` indexes only bullets under a MUST / MUST NOT / Never / Always / Checklist heading** — the same discriminator the pack catalog uses. Bullets under a topical heading (`## Imports`) are prose and stay unindexed; the file is still reachable by path.
- **No claim that recall improves outcomes.** Earning that claim means seeding `/eval` cases whose `guards:` cite memory rows and comparing `ai/evals/_scorecard.md` runs with the recall hook on and off. Until that runs, the honest status is UNKNOWN.

## Automatic recall (opt-in)

`.claude/hooks/recall-inject.sh` (UserPromptSubmit) runs this same search against your prompt and injects the top 3 pointers as context, so the failure catalog can surface itself *before* the failed approach is retried. It is **inert until you opt in**:

```bash
touch .claude/.recall
```

Context-only, never blocks, always exits 0, deduped per row per session, and a silent no-op without `jq` or `python3`. Measured warm end-to-end 30-50 ms against three real project corpora (106 / 246 / 294 rows) on 2026-08-20; re-measure before quoting elsewhere.

## See also

- `/learn-from-task` — the producer. Without it this index is empty.
- `/audit-knowledge` · `/promote-pattern` · `/promote-decision` — what to do with what you find.
- `templates/snippets/learning-sink.md` — the canonical sink set this indexes (unchanged by this command).
- `docs/RETRIEVAL.md § Project memory` — the corpus table, the cache contract, and the measured numbers.
