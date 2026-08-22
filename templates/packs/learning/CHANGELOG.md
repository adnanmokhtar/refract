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
