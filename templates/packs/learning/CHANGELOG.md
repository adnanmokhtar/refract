# learning pack — changelog

Release history for `templates/packs/learning/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

Some versions also carry a **Release narrative**. This pack kept a second, independent telling of
each release inside the `_version.json` `summary` string, and every release appended to it, all on
one JSON line. Each telling is preserved below under the version it describes, verbatim and
unabridged.

Headings carry the `released` date recorded for that version. A few early versions were only ever
described in the `summary` narrative and never had a dated `changelog` block — those headings have
no date, which is the honest state of the record rather than an omission.

## 1.5.0 — 2026-08-23

**`/refresh-knowledge` did not re-extract.** Its Phase 3 read "Re-run Phase 2 detection from
`/setup-project` … Walk one full module per layer (controller → service → repo → entity → test)" —
which is verbatim the pre-oracle procedure `extract-codebase-overview` was created to replace
(that skill's own line 10 says so). The command named zero skills and zero agents, and wrote none of
`_extracted-codebase.md` / `_extracted-idioms.md` / `_extracted-business.md`. So a refresh rewrote
`codebase-profile.md` and `ai/conventions.md` — with a fresh date — while the oracle every Phase-4
generator reads stayed at the commit it was last extracted from. Worse: because the file was never
touched, its `approved_hash:` never mismatched, so `/setup-project-health` check 9 reported the stale
oracle **healthy**. The pack's own approval machinery certified it. Nine artifacts across the pack
told users this command re-ran the pipeline; it is now the command those nine describe. Phase 3 invokes
`extract-codebase-overview` (chaining `extract-business-context` at its Step 13) and
`extract-base-class-idiom`, preserves the approval stamp verbatim so the mismatch DOES fire, and
diffs oracle-against-oracle for coverage, provenance and `[CONTESTED]` deltas the profile diff cannot
show. Phase 5 also dispatches `pattern-emergence-watcher` instead of authoring `learned-patterns.md`
inline past the agent's Rule-of-Three floor. Separately: Phase 5 said "Replace
`.claude/codebase-profile.md` with `.codebase-profile.md.new`" — a path Phase 4 never wrote
(`claude/` was missing).

**`[CONTESTED]` was produced correctly and consumed by nobody on the path every project takes.**
Round one emits `[CONTESTED: kebab 6/10, snake 4/10]` into `_extracted-codebase.md § Conventions`.
Grep found exactly one consumer repo-wide: `phase-4.7-deep.md`, whose frontmatter is
`applies-to-modes: [REFINE]`. On a plain CREATE / ENHANCE / REFRESH run the split was measured, cited
and dropped. And even in REFINE, where `## Unsettled conventions` does get written,
`convention-drift-detector` read `ai/conventions.md` with zero knowledge of either marker — so its
Pass 1 flagged the 40% minority as `code-vs-rule` → FIX CODE. The one agent in the repo whose job is
to say "fix this code" was the one agent the marker could not stop. It now builds a contested set from
**both** sources before Pass 1 (the oracle grep covers projects that never ran `--refine`), and a
contested category is `ambiguous` by halt, never `code-vs-rule` — one row per category, not one per
file. `/detect-drift` reads the same set. New `§ Contested categories` names the third state
explicitly beside ABSENT and SETTLED.

**Extraction that overstated its own confidence.** `## Cross-cutting concerns` — the section that
emits `multi-tenant: **confirmed**`, the strongest word in the oracle — had no row in the Step 2.5
per-section denominator table, so it was outside check 7 entirely; its only guard was "cites ≥2
corroborating files". Two files out of 412 is not confirmation of a repo-wide property, and nothing
computed the ratio. `## Anti-patterns observed` was outside it too, emitting counts with no
population ("47 `console.log` calls" reads as an emergency at 60 files and as noise at 4,000). Both
now have denominator rows. Step 9's verdict is a closed three-word grammar — `confirmed` / `partial` /
`not-detected` — with `<matched>/<present>` printed, and `confirmed` on a *pervasive* property
requires `matched == present`; `partial` is the useful verdict a bare `confirmed` was destroying.
Check 7 gained two bullets: the `none declared → must be 100%` cap cell is now **enforced** (a
disclosed short walk on `## API surface` used to pass — Step 7 said so about itself), and its one
non-arithmetic bullet got a closed trigger-word list so "every generalizing claim is marked
`[inferred:]`" stops being the model grading its own prose.

**Three markers produced and never read.** With `[CONTESTED]` above, two more: **`MEDIUM`** was an
orphan tier — of six round-two skills only `extract-failures-from-history` declares it, and
`compute-anchor-density § Step 4` said "only count if the upstream extraction is **STRONG**", so a
project with one verified failure theme (diffs read, SHAs cited) scored **0** on `failure-theme`,
identically to a project with none. The rule is now STRONG-or-MEDIUM, WEAK excluded. And
**Specificity** — axis 4 of the anchor score — was a nine-string blocklist starting at 25, so
"Follow the team's established patterns for this layer" hit none of them and scored a perfect 25. It
was the one axis satisfiable by writing *more confident* prose, which inverts the rubric's whole
purpose: `6 identifiers + 5 paths + 0 signals + 25 = 75 = ANCHORED`, permanently skipped by 4.6-DEEP
having consumed zero deep signal. It is now a positive test — the fraction of the block's
*directives* that name a verified identifier, path or extracted number. Confident prose with no
referent scores 0.

**Two gates that no run could fail.** `extract-hotpaths` STRONG required "≥ `top_n/2` paths with
`n_plus_1_risk` ≥ **low**" — but `low` is what a path scores for having been scored, so the gate read
"half the paths were looked at" and every run that ran passed it. Now medium-or-high with the
loop-over-query site cited. `extract-architecture-deeply`'s gate was four bare counts while all the
rigour sat in the worked example above it; the example's citation standard moved into the gate, and a
`not detected` concern counts toward the threshold only when the greps that looked for it are named.

**The `_examples/` directory is gone — 1,632 lines deleted, and with them a whole drift class.**
All eight fallbacks were 94-99% body-identical to their sources; five declared themselves literal
copies via `generated-from:` headers and stayed in sync, and the three without the header had
silently drifted. `extract-flows-deeply` and `extract-hotpaths` had both dropped
`## Where the output lands` — the only place naming `ai/business-flows.md` and
`ai/patterns/parallel-io.md` as their destinations — so the shipped extractor did not know where to
write. `setup-quality-scoring` had dropped its entire `**When NOT to apply**` block, including
"scores are intra-project signals, not benchmarks". And `extract-flows-deeply` had re-introduced
`*_e2e.spec.ts` / `*_integration_test.py` / `Sentry` where its source had been generalised to
`<test-ext>` and "the project's APM tool" — stack leakage aimed squarely at greenfield projects,
which receive the fallback **and nothing else**. `validate-pack-consistency.sh` was green throughout
(check 8b's protected set does not cover those sections; `audit-stack-leakage.sh` read `.ts` + `.py`
as diversity). These artifacts are the *engine*: they ship byte-identical to every project in every
mode, so a twin could only ever be a literal copy carrying a standing re-cut obligation. All eight
topics now name their source in `fallback:` — the shape the pack's other sixteen topics already used
— which `phase-4.2-apply.md § 4.2-AUTHOR` step 2 copies identically. `_topics.md` records the policy.

**Consolidation and dead weight.**
- `extract-project-context` **Path A deleted**. Its gate was "a repo exists but has zero source
  files"; its step 5 ran business-domain and technical-signal detection, which read source files —
  unreachable under its own precondition. Its steps 6-7 wrote seven `ai/` targets
  `extract-business-context` + Phase 4.7b own, the collision the file's own scope boundary forbids.
  The mining worth keeping (README / manifest / git / siblings) is now Step 0 and runs whenever those
  signals exist. The skill writes the three files its frontmatter claims, and no others.
- `/audit-knowledge`'s six restated curator duties **deleted** — including a second independent copy
  of "`ai/` ≤ 50 files, each ≤ 300 lines". It keeps what is genuinely its own: full-sweep scope (the
  only entry point that sweeps every sink in one pass), the `--fix` boundary, and the closer.
- The plateau verdict table, the three-reason map and the classification bands lived in full in BOTH
  `compute-anchor-density § Steps 6-7` and `ai-patterns/setup-quality-scoring.md`, plus once more in
  each of their fallbacks — four copies of one contract. The skill keeps the arithmetic; the pattern
  keeps the explanation the arithmetic cannot carry.
- The 18-row per-adapter cheatsheet in `apply-pack-adaptation` **deleted** — and it was already
  stale, sending NEW-FILE commands to `.cursor/commands/<name>.md` after
  `tool-adapters/cursor/adapter.md` moved the primary surface to `.cursor/skills/<name>/SKILL.md`.
  The skill's five genuinely-own decisions stay. Also recorded: `_translate.md` and
  `_user-customization.md`, named as inputs, are `[PLANNED]` and ship for **zero** adapters — every
  reference to them was always running its fallback, which is now written as the behaviour.
- **NOT merged: the twelve skills.** Normalised for the house SKILL.md skeleton (14 headings shared
  by ≥20 of 115 files), measured redundancy is **2.1%** across 1,251 lines; highest pair
  `extract-flows-deeply ↔ extract-hotpaths` at 6.7% (n=4). Twelve distinct jobs.
- **NOT created: a rules file.** learning stays the only pack of 23 with none and the only ALWAYS-applied
  pack contributing **0** always-loaded tokens. Recorded as a deliberate decision in `_essentials.md`.

**Honesty fixes.** `pattern-emergence-watcher` claimed four triggers; two were false — the
`post-commit-learn.sh` hook only `echo`s a line into `ai/dynamic/.review-queue` (which
`session-start.sh` prints and a human drains), and there is no cron behind "Periodic: weekly scan".
Dispatched-vs-queued is now stated, matching `knowledge-curator`'s frontmatter and
`/learn-from-task § Dispatch`. `promote-decision`'s HALT gate grepped `ai/dynamic/_session-digest.md`
— 1 of 41 uses repo-wide, and not the path the baseline ships (`ai/_session-digest.md`); a gate
grepping a file that never exists passes because it finds nothing. `promote-pattern` Phase 6 gained
the grep-confirm / index / digest checks CHANGELOG 1.3.1 said its twin already had (it did not), and
`knowledge-curator § 8` gained the `/promote-pattern` digest trigger it was missing — without it the
digest still lists a just-promoted pattern under "Patterns currently emerging". `/eval`'s REGRESS
fired only on PASS→FAIL, so 7/8 → 2/8 was not a regression because both are FAIL; it now fires on a
score drop, which is the common shape since a case that never passes is the case nobody watches.
`knowledge-curator` duty 6 ("Detect orphans") was four bullets with no method — now four classes each
with a runnable procedure and an age qualifier, because an audit that re-reports every young artifact
is an audit people stop reading. `_essentials.md` said `extract-project-context` "is the single skill
in the pack"; the pack has twelve. `_topics.md` had no entry for `apply-pack-adaptation` — 562 lines,
the file that writes every anchor — so `validate-pack-consistency.sh` check 5 warned and it shipped
only by the copy loop.

Pack now: 3 agents · 12 skills · 8 commands · 1 ai-pattern · 0 `_examples/` fallbacks · 5,592 lines
(was 6,804: −1,632 from deleting `_examples/`, +420 of substantive content across 18 files, −1,212 net).
Still 0 rules, still absent from `scripts/_rule-budget-baseline.txt`, still 0 always-loaded tokens.

## 1.4.1 — 2026-08-22

**A property asserted of a check that opening the check disproves.** `skills/extract-codebase-overview/SKILL.md`
Step 7 read: "no cap is declared for this step, so Step 15 check 7 asserts `seen == present` here."
Check 7 asserts nothing of the kind. Its rules are: `seen`/`present` must be integers in
`## Coverage`; `seen < present` with **no** `[SAMPLED]` marker → FAIL; `seen == present` **with** a
`[SAMPLED]` marker → FAIL; generalizing claims in sampled sections must be `[inferred:]`;
`[CONTESTED]` arithmetic. Nothing is keyed to the uncapped row — a run that walks 12 of 40 controllers
and writes `[SAMPLED: 12/40 files]` on `## API surface` passes check 7 cleanly.

The 100% obligation is real, but it belongs to the Step 2.5 per-section denominator table
(*"none declared → must be 100%"*), not to check 7. Step 7 now says which one enforces what, and so
does the caller (`templates/phases/phase-2-profile.md`), where the same sentence had been repeated.

## 1.4.0 — 2026-08-20

- NEW `commands/recall.md`: retrieval over the memory this pack already writes. `/recall <query>`
  searches the project's existing `ai/` tree — the `ai/dynamic/` sinks, `ai/failures/_index.md`,
  ADRs, patterns, runbooks, directive bullets in `conventions.md`, and the `ai/audits/**`
  archives — and returns ranked POINTERS (`path:line`). Read-only. Flags `--kind` / `--owner` /
  `--since` / `--limit` (hard cap 25) / `--format=text|json|paths`.
- **No new store, and no new sink.** `templates/snippets/learning-sink.md` is unchanged, every
  promotion threshold is unchanged, and `/learn-from-task` and `knowledge-curator` are untouched.
  The gap this closes was never capture — it was that nothing could FIND what was captured.
  `ai/failures/_index.md` is an append-only don't-retry catalog whose entire value lands at the
  moment someone is about to retry the failed approach, and there was no recall path to it.
- NEW `scripts/gen-memory-catalog.py`: a second row producer for the existing BM25 engine, same
  9 columns and same module interface as `gen-pack-catalog.py`. Deliberately not indexed:
  `ai/dynamic/changelog.md` (a one-line activity log), the `.review-queue`, README/_template
  scaffolds, fenced format blocks, and any heading still carrying a `<placeholder>`.
- `scripts/pack-search.py`: one new argument, `--catalog=pack|memory`. The default path is
  unchanged — same tokenizer, same `k1`/`b`, same field weights, same synonyms, same hard cap,
  same footer — so the pack corpus keeps its row floors. Memory caches to
  `.claude/_memory-index.json` (gitignored, fingerprinted on size+mtime, never committed).
- NEW `templates/repo-baseline/.claude/hooks/recall-inject.sh` (UserPromptSubmit) — searches the
  same corpus with the user's prompt and injects the top 3 pointers as `additionalContext`, so
  the failure catalog surfaces itself before the failed approach is retried. **Opt-in**:
  inert until `touch .claude/.recall`. Context-only, always exits 0, never blocks, deduped per
  row per session, silent no-op without `jq` or `python3`.
- `update-session-log.sh` (Stop): additionally records the harness's `session_id` +
  `transcript_path` as POINTERS at the verbatim transcript the host already keeps. The transcript
  is never copied into the repo — a hook write is not an Edit, so `secret-scan.sh` never sees it.
  The first prompt (≤120 chars) is CONTENT and is recorded only under the `.recall` opt-in.
- Measured 2026-08-20 on three real consuming project corpora (106 / 246 / 294 rows): cold
  rebuild 17-45 ms, warm cache 2-4 ms, warm end-to-end 30-50 ms. No claim that recall improves
  outcomes — earning that means seeding `/eval` cases whose `guards:` cite memory rows and
  comparing `_scorecard.md` runs with the hook on and off. Until then: UNKNOWN.

## 1.3.2 — 2026-07-12

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

/eval SAFETY FIX — graded sub-agents are now dispatched READ-ONLY (propose answers as text, never
Write/Edit/Bash) so a scoring run can never mutate product source; observed 2026-07-12 a run leaked
brandService.ts + 5 other files. A stray write now voids the run instead of scoring a polluted repo.
Phase-6 continuous-learning pack — curator + drift/pattern watchers + now the measurement half.

## 1.3.1 — 2026-07-10

- promote-decision: added the Phase-6 Validate its twin promote-pattern already had — HALTs unless
  the numbered ADR exists with required sections + status:accepted + no placeholders, the pending
  entry is grep-confirmed removed, the index line is appended once, and the digest is regenerated.
  Was a mutating command with no verification.

## 1.3.0 — 2026-07-03

- NEW commands/eval.md: the measurement half of the learning loop. RUN/SEED/GUARD/REGRESS/RETIRE
  vocabulary; modes default | --case | --coverage | --seed; five detectors (unguarded, regress,
  stale, toothless, uncovered-failure); anti-theater Phase-6 that asserts a real _scorecard.md run
  block was written and that every FAIL produced a matching learnings.md sink entry.
- NEW baseline scaffold templates/repo-baseline/ai/evals/ — README.md (lifecycle + auto-vs-manual
  wiring note), cases/_template.md (scenario + answer key + guards: provenance), _scorecard.md
  (append-only run history), cases/.gitkeep.
- templates/snippets/learning-sink.md: documented /eval as a third writer of the
  ai/dynamic/learnings.md sink (failure hand-off), and _scorecard.md as its own recorded-outcome
  artifact (not a sink).
- _essentials.md + _topics.md: /eval added as an always-on core command alongside learn-from-task.

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

NEW /eval command + ai/evals/ baseline scaffold — the grade to /learn-from-task's capture. Replays
saved eval cases (scenario + answer key + guards: link) against the current knowledge base, scores
each, records an append-only _scorecard.md, and feeds FAIL/REGRESS back into ai/dynamic/learnings.md
— closing the loop that used to promote rules with no proof they worked. Five detectors (unguarded /
regress / stale / toothless / uncovered-failure) + coverage %. /eval is a third writer of the
learnings.md sink (snippet updated).

## 1.2.1 — 2026-06-22

- knowledge-curator.md: the inline 4-column learning-sink table (sink read → what you promote it to)
  extracted to templates/snippets/learning-sink.md and linked, so the canonical curator and the
  repo-baseline copy (which must stay body-identical) no longer carry a divergence-prone duplicate.
- learn-from-task.md: audit action-plan rollout carried into the version record.

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

curator learning-sink table extracted to templates/snippets/learning-sink.md.

## 1.2.0

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

provenance discipline + oracle approval stamp.

## 1.1.0

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

/promote-decision + /audit-knowledge.
