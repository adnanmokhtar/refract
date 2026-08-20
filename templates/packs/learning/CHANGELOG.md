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
