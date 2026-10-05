---
purpose: The run directory contract — ai/runs/<run-id>/ holds one delivery run's typed artifacts, who writes each, when, and how big it may get; plus the orchestrator's ledger (facts · guesses · plan · loop counters · diary). Shared by the delivery /add-feature orchestrator, its agents, risk-tier.py, trace-matrix.py, ears-lint.py, artifact-ownership.sh and precompact-handoff.sh.
---

# Run ledger — one run, one directory, one writer per file

A feature run is a directory of files, not a conversation. Every phase writes a typed artifact a
script or a different agent can check, every artifact has exactly one writer, and the
orchestrator's own reasoning lives in one file no judge ever reads.

## 1. The run id and the directory

- **Run id:** `<YYYYMMDD>-<slug>-<4hex>` — the Spec-ID convention of `/analyze-task`
  (`<slug>-<4char-hash>`, a short hash of slug + timestamp) with the UTC date in front:
  `date -u +%Y%m%d`, a kebab slug of the ask (≤ 40 chars), and the first 4 hex chars of
  `sha1(slug + timestamp)`. When the run is built from a spec, `run.json.spec_id` carries its Spec-ID.
- **Where:** `ai/runs/<run-id>/`. **Committed** with the change (decision O1(c)): requirements and
  design are reviewable product knowledge, and CI re-checks the records bound to the tree.
  `ai/runs/<run-id>/evidence/raw/` is **git-ignored** — the orchestrator writes `ai/runs/.gitignore`
  containing `*/evidence/raw/` when it opens the first run. Session-local records stay in the
  already-ignored `.claude/evidence/`.
- **T0 opens no run.** A docs, copy or typo change records one `ai/status.md` line; the tier matrix
  lives in `.claude/templates/governance/tiers.json`.

## 2. The files — writer, phase, budget

| File | Writer (only) | Phase | Budget | Checked by |
|---|---|---|---|---|
| `run.json` | orchestrator (main session); `risk-tier.py --write` for promotions | P0, every phase change | schema | `.claude/schemas/run.schema.json` |
| `requirements.md` | `@product-analyst` | P1, §Impact in P2 | ≤150 lines | `ears-lint.py`, `@requirements-reviewer` |
| `quality-attributes.md` | `@product-analyst` (draft P2) → `@architect` | P2, P4 | ≤120 | `@architecture-reviewer` |
| `ux.md` | `@ux-designer` *(ui-ux pack)* | P3, UI lanes | ≤150 | `@ux-reviewer` |
| `design.md` | `@architect` | P4, §Interfaces + §Work split in P5 | ≤250 | `@architecture-reviewer` |
| `threat-model.md` | `@architect` | P4 (T3) | ≤120 | security lens |
| `test-plan.md` | `@test-engineer` | P5 | ≤150 | `@plan-critic` |
| `acceptance.json` | `@test-engineer` (main session at T1) — until locked | P5 | schema | `lock-acceptance.sh`, `trace-matrix.py` |
| `plan.md` | orchestrator | P5 | ≤200 | `trace-matrix.py --phase=plan`, `@plan-critic` |
| `reviews/<agent>-<lens>.json` | `persist-review.sh` (hook) | P2–P11 | schema | `gate-check.py` G7 |
| `verdict.json` · `verdict-refute.json` | `persist-verdict.sh` (hook) | P12 | schema | `gate-check.py` G1, G15 |
| `release.md` | platform-engineer *(devops pack)*, else orchestrator | P11 (T3) | ≤80 | operability lens |
| `ledger.md` | orchestrator | every phase | ≤200 (roll older diary into `ledger-archive.md`) | nobody — **never** given to a judge |
| `handoff.json` | `precompact-handoff.sh` (hook) | before a compaction | — | `session-start.sh` re-prints it |

`artifact-ownership.sh` enforces the writer column for tool edits while a run is `open`; `test-lock.sh`
keeps the locked contract and every hook-written record out of reach. A file whose writer is not
installed is written by nobody: the phase is skipped with `covered_by: UNREVIEWED(<role>) — <agent>
not installed (<pack> pack)` and the run cannot close COMPLETE.

### Formats the scripts parse

`requirements.md` — one story per heading, criteria as list items:

```markdown
### REQ-001 — Refund a paid order
As a support agent, I want to refund a paid order, so that the customer gets their money back.
- AC-001: WHEN an agent submits a refund for a paid order THE refunds API SHALL record exactly one refund for the order total in minor units.
- AC-002: IF the order belongs to another tenant THEN THE refunds API SHALL return 403 and record no refund.
```

EARS shapes (`ears-lint.py`): `THE <system> SHALL …` · `WHEN <trigger> THE <system> SHALL …` ·
`WHILE <state> …` · `WHERE <feature> …` · `IF <condition> THEN THE <system> SHALL …`. **Every story
carries at least one `IF … THEN` clause.** Fixed sections: `## Problem`, `## Stories`,
`## Unchanged behaviour`, `## Non-functional` (`NFR-###` → `QA-###`), `## Out of scope`,
`## Open questions` (A/B options, never verdicts), `## Impact` (P2), `## Success metric`
(metric + counter-metric).

`plan.md` — the 8-header plan schema (`.claude/plans/README.md`); each task under `## Steps` is one
line that cites the criteria it serves: `- T-003 (AC-001, AC-002) [lane: backend] <step>`.
`trace-matrix.py` maps REQ → AC → T → test and fails on any orphan.

## 3. `run.json` — the state machine

Shape: `.claude/schemas/run.schema.json`. The orchestrator updates it at every phase boundary:
`phase` moves forward, `phases.<P>` records `state`, `by`, `artifacts`, `verified_by`; a phase the
tier skips goes into `skips[]` with `covered_by`. Human gates land in `approvals[]` with the SHA-256
of each artifact shown, so an approval is bound to the bytes the human saw. **Tier only goes up:**
`risk-tier.py --run=<id> --write` re-tiers from the predicted file set after P4 and from the diff
after P6; a promotion re-opens the phases the new tier requires (`tier_history[].backfill`). A lower
tier is forced at P0 only, with a reason (`forced_lower`), and CI re-tiers from the diff.

## 4. `ledger.md` — the orchestrator's working memory

```markdown
# Ledger — <run-id>

## Facts            (read in a file or a tool output — cite path:line or the command)
## Guesses          (believed, not yet checked — each with the check that would settle it)
## Plan             (the next 1–3 moves)
## Loops            fix 0/3 · review rounds 0/2 · replans 0/2 · stalls 0   (THR-LOOP)
## Diary
### Interpretations (how an ambiguous ask was read, and the alternative)
### Deviations      (where the run left design.md or plan.md, and why)
### Tradeoffs       (what was chosen over what)
### Open            (what a human still has to decide)
```

- **Stall ledger.** A phase that ends with no new artifact and no new fact is a stall. Two stalls in
  a row → replan (`loops.replans += 1`, a new `## Plan`); a third → stop and hand the human the
  ledger. Fix loops cap at `THR-LOOP.fix_loops_max`, review rounds at `review_rounds_max` (round 2
  posts IMPORTANT findings only — `posting-bar.md`), replans at `replans_max`.
- **The ledger is the builder's narrative.** It is never named in a brief to a judge, and
  `judge-bash-guard.sh` denies a judge that tries to read it (`delegation-brief.md` § 2).

## 5. Handoff across a compaction

`precompact-handoff.sh` (PreCompact) writes `ai/runs/<run-id>/handoff.json` for the open run — intent,
tier, phase, phase states, loop counters, files changed since the base, the ledger's Open and Plan
lines, and the next step — and prints a short "preserve" brief: Claude Code passes a PreCompact
hook's stdout to the summariser as custom instructions (measured, Claude Code 2.1.236). After the
compaction, `session-start.sh` (source `compact`) prints the handoff back into context.

## 6. Delegation

Every dispatch inside a run is a [delegation brief](delegation-brief.md): `run_id`, the role's paths,
and the return shape — paths only, return ≤ 2K tokens of prose around one JSON object or one
written artifact. A writer agent returns `DONE <path>` / `NEEDS_INPUT <question + options>` /
`SPEC_CONFLICT <AC-id — requirement — evidence>` / `BLOCKED <why>`; the orchestrator reads the
artifact, never the agent's account of it.
