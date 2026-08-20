---
description: Map what is INTENDED but not yet built, then phase the build order. Trigger on 'what is left to finish this', 'map the missing features so I can start', 'plan completion for the orders module', 'build the next phase' (--build), 'where am I' (--status). Read-only by default. Do NOT trigger for defects in code that already exists — bugs, security, perf, and scale are /audit. Not for porting features that live in ANOTHER codebase (/migrate), and not for one feature you already know you want (/refine-prompt then /do).
compatibility: Requires _extracted-codebase.md or codebase-profile.md populated for PROJECT_KIND and the entity inventory. A README, PRD, or ADRs feed the spec-delta detector; with none it falls back to five code-signal detectors and reports reduced spec confidence, or pass --goal to state intent inline. --build additionally requires green CI and a clean tree (or --allow-dirty).
kind: command
pack: orchestration
---

# /roadmap [<scope>] [--goal "<intent>"] [--build [<N>]] [--status]

## What this does

**Single command. Map everything still missing to finish the project into a phased completion plan — then, optionally, build it one phase at a time.** Deep multi-agent scan of a SINGLE codebase, no second reference required. Whole project or scoped. **Read-only by default** — it produces a plan, not a diff.

The agent:
1. **Scans the codebase for "intended but unfinished"** — stubs, half-wired features, asymmetric coverage, and a diff against whatever the project says it should be (README / PRD / ADRs / `CLAUDE.md` / open issues).
2. **Infers what "done" means** from six signals (the six completion detectors below), because a single incomplete project has no V1 to copy and no defect list to rank — the reference for "complete" must be reconstructed. You can also **state "done" directly** with `--goal "<intent>"` — your words become authoritative intended-state, so the map includes requirements that are not in the code or docs yet.
3. **Builds one row per missing capability** — title, domain, detector kind, `<file:line>` evidence, dependencies, size tier, risk.
4. **Phases the rows** by dependency + domain — Phase 1 = foundations / blockers, later phases depend on earlier ones, cosmetic polish last. Each phase is a small, shippable, revertible batch.
5. **Writes ONE plan** at `ai/roadmap/plan.md` — the phased completion plan, which doubles as the ledger.
6. **With `--build`**: executes exactly ONE phase (the next pending one, or `--build <N>`) in dependency-ordered parallel waves, verifies, marks the rows `done`, and **halts at the phase boundary**. Never all-at-once.

You see: features found, the phases, sizes, blockers — and (under `--build`) what got built, commits, diff stats, test status. NO ledger talk, NO terminology, NO mid-run questions surfaced.

This is the single-codebase analog of `/migration-scan` + `/migration-plan`: same "map the delta, phase it, drain it" engine, but the delta is **current state → intended state** instead of **V1 → V2**.

## When to use

- "I have a half-built project — what's left to finish it?" → `/roadmap`
- "Map the missing features so I can start." → `/roadmap`
- "Finish it — and I also want things that aren't in the code yet (X, Y, Z)." → `/roadmap --goal "X; Y; Z"`
- "Plan completion for the orders module only." → `/roadmap the orders module`
- "Build the next phase." → `/roadmap --build`
- "Build phase 2." → `/roadmap --build 2`
- "Where am I?" → `/roadmap --status`

## When NOT to use

- For **defects** in code that already exists (bugs, security, perf, scale) — that's a quality problem, not a missing-capability problem → `/audit`.
- For porting features that already exist **in another codebase** (V1 → V2) → `/migrate`.
- For a **deep prompt for one specific feature** you already know you want → `/refine-prompt`, then `/do`.
- For **architectural cleanup** of finished code → `/optimize`.
- Mid-feature work / dirty tree when using `--build` → commit or stash first.

The line: `/roadmap` answers *"what capability is intended but not yet built, and in what order do I build it?"* Everything else answers *"what's wrong with what is built?"* or *"how do I move what exists?"*

## Args

- `<scope>` (optional) — natural-language description OR explicit path. If omitted: whole project.
- `--goal "<intent>"` (optional) — a free-text statement of what *done* means: capabilities you want that may not be in the code or docs yet. Each clause is folded into the intended-state reference (detector 4) as **authoritative** intent, so the map includes goal items even where there is no existing trace — and even when a clause re-defines a feature that already works (e.g. *"storage must be pluggable, selectable"* makes today's local-only storage a gap). Combine with `<scope>` (where to look) and `--build` (then build it).
- `--build [<N>]` — execute one phase (the next pending phase, or phase `<N>`). Halts at the phase gate.
- `--status` — read-only progress report from `ai/roadmap/plan.md`. No scan, no build.

Examples:
```
/roadmap                                   # whole project — map, write the phased plan, stop
/roadmap the payments domain               # scope the map to one area
/roadmap "everything except admin"         # exclusion-by-description
/roadmap --build                           # build the next pending phase, then halt
/roadmap --build 3                          # build a specific phase
/roadmap --status                          # progress only
/roadmap --goal "finish media decryption + key delivery; anti-download protection; pluggable storage (local | external, selectable)"
```

## The six completion detectors

A single unfinished project has no external oracle for "done." `/roadmap` reconstructs the intended scope from six independent signals and unions their findings (deduped by `<file:line>` + capability). This is the specialist core — each detector emits rows the others miss.

1. **Stubs & placeholders** — `TODO` / `FIXME` / `HACK` / `XXX` markers, not-implemented bodies (`NotImplementedError` / `pass` / empty function / `throw new Error("not implemented")` / `return null  // TODO`), mock or hard-coded data still wired to a real surface, commented-out implementation blocks, generated scaffolding never filled in.
2. **Dangling wires** — a route with no handler (or a handler with no route), a UI affordance (button / link / form) with no action or submit target, a form with no validation or no backing endpoint, an entity/model with partial CRUD (e.g. create exists, update/delete don't), a config/env var referenced but never set, a feature flag defined but never gated, a migration with no consuming code.
3. **Feature asymmetry** — across sibling entities or features, the ones missing a slice the *majority* already have: list / detail / create / edit / delete, plus tests, validation, empty / loading / error states, permission checks, and i18n. If 8 of 10 entities have full coverage, the other 2 are flagged with the specific missing slices.
4. **Spec delta** — parse the project's own statements of intent — `README` / PRD / design docs / ADRs / `CLAUDE.md` / open issues / checklists — extract *promised* capabilities, and diff against what is actually implemented. Promised-but-absent → a row, cited to the promise. **A `--goal "<intent>"` argument is the strongest such statement** — its clauses are treated as authoritative intent (cited as `--goal "<clause>"`), even when they re-define a feature that already works. This is how you map requirements that live in your head, not the repo.
5. **Domain table-stakes** — infer `PROJECT_KIND` (per `_extracted-codebase.md`), then check the capabilities that kind structurally implies but the code lacks. The detector is universal; it adapts to the kind it finds (e.g. a checkout surface with no order-confirmation or refund path; an auth surface with sign-in but no password-reset / session-refresh / sign-out; an upload surface with no size/type validation or no failure path). Table-stakes rows are flagged as *inferred* and tier-capped lower than spec-delta rows, since intent is implied, not stated.
6. **Dead-end flows** — trace end-to-end user journeys (entry → core action → settle) and find where one stops half-built: a UI that exists with no backend behind it, a happy path with no error/empty branch, a multi-step flow whose later steps are unreachable, a created record with no way to read or act on it.

Every finding becomes a plan row:

```
id        a stable short token (e.g. R-014)
title     the missing capability, one line
domain    auth / orders / payments / shared / …
kind      stub | dangling | asymmetry | spec-gap | table-stakes | dead-end | goal
evidence  one or more <file:line> citations (or <doc:section> for spec-gap, or --goal "<clause>" for goal rows)
deps      ids this row depends on (must build first)
size      trivial | standard | heavy
risk      contract-break / security / cross-cutting / data-loss, or none
phase     assigned in the phasing step
status    pending | building | done | blocked
```

## What happens internally (silent)

**Discipline:** under `--build`, MUST read [`templates/governance/core-discipline.md`](../templates/governance/core-discipline.md) before generating code (clean-code + SOLID pointer). Stack-specific rules load from the pack rules after `/setup-project`.

The agent does ALL of this silently — you don't see phases, ledger states, or detector dispatch:

1. **Scan** — read source + the project's intent docs for the scope. Run all six detectors in parallel. Reuse `_extracted-codebase.md` / `_extracted-idioms.md` for `PROJECT_KIND`, idioms, and the entity/surface inventory. If `--goal` is set, its clauses join the intent docs as authoritative spec-delta input.
2. **Resolve scope** — if `<scope>` is a description, semantic-resolve to source paths via the codebase profile.
3. **Dedup + size** — union detector findings; collapse duplicates by `<file:line>` + capability; assign a size tier from blast radius (trivial = single file / mechanical; standard = one feature slice; heavy = cross-cutting, new subsystem, contract or security surface).
4. **Build the dependency graph** — topologically order rows. A cycle is a real finding: it surfaces (halt) rather than being silently broken.
5. **Phase** — group into phases by dependency + domain. Foundations / blockers (shared, auth, data layer that others need) first; domain phases next; cosmetic / polish last. Each phase contains only rows whose dependencies land in the same or an earlier phase, so every phase is independently shippable.
6. **Write the plan** — `ai/roadmap/plan.md` (see below). Read-only path ends here.
7. **If `--build`** — take the next pending phase (or `<N>`), dispatch one agent per row in dependency-ordered parallel waves, route by size (trivial / standard → tight detect→build→verify loop; heavy → deep per-feature loop with its own audit), one commit per row, verify (lint / typecheck / scoped tests), flip rows to `done`, write `ai/roadmap/final-report.md`, and **stop at the phase boundary**.

## The completion plan (the artifact)

`ai/roadmap/plan.md` is the single source of truth — the phased plan AND the ledger. Read-only by default; `--build` updates row `status` in place. Re-running `/roadmap` re-maps and **merges**: new gaps append as `pending`, `done` rows are preserved, capabilities that are now implemented flip to `done`.

```markdown
# Completion roadmap  (ai/roadmap/plan.md)

Scanned: <YYYY-MM-DD>
Scope:   whole project
Project: <PROJECT_KIND>

## Summary
- Missing capabilities: 34   (12 stub · 9 dangling · 6 asymmetry · 4 spec-gap · 2 table-stakes · 1 dead-end)
- Phases: 4
- Done: 0 / 34
- Blocked: 1 (cross-repo)

## Phase 1 — Foundations  (5 rows · 1 heavy · est. settle-first)
| id    | title                          | kind      | size     | deps | evidence              | status  |
|-------|--------------------------------|-----------|----------|------|-----------------------|---------|
| R-001 | session refresh endpoint       | dangling  | standard | —    | auth/session.x:88     | pending |
| R-002 | password-reset flow            | table-stakes | heavy | R-001| auth/* (absent)       | pending |
| ...   |                                |           |          |      |                       |         |

## Phase 2 — Orders domain  (8 rows · depends on Phase 1)
...

## Phase 3 — Payments  (6 rows · depends on Phase 2)
...

## Phase 4 — Analytics  (4 rows · independent — can ship anytime)
...
```

## --build mode (phased execution)

`--build` is deliberately **one phase per invocation**. Large projects have many phases; dumping every missing feature in one change is unreviewable and unrevertible, so the phase is the batch boundary.

- Picks the next `pending` phase (or `--build <N>`).
- Executes that phase's rows in **dependency-ordered parallel waves** — independent rows in parallel, dependents after their `deps` land.
- One commit per row. Routes by size: trivial / standard rows run a tight build→verify loop; heavy rows run the deep per-feature loop (own mini-audit, parity-sensitive verify).
- **Phase gate**: every row in the phase must reach `done` with scoped tests green before the phase counts as complete. Rows that can't (cross-repo, genuine blocker) are marked `blocked` with a one-line reason and excluded from the gate.
- **Halts at the boundary** — does not roll into the next phase. Review, then `/roadmap --build` again.

```
/roadmap            → review the phased plan          (map, read-only)
/roadmap --build    → Phase 1 → halt at gate → review
/roadmap --build    → Phase 2 → halt at gate → review
/roadmap --build    → Phase 3 → halt at gate → review
/roadmap            → re-map → 0 missing = done
```

## Pre-requisites

- `_extracted-codebase.md` OR `codebase-profile.md` populated (for `PROJECT_KIND` + entity inventory).
- For `--build`: mechanical CI green (lint, typecheck, build, tests) and a clean working tree (or `--allow-dirty`).
- A statement of intent helps the spec-delta detector: a `README` / PRD / ADRs / `CLAUDE.md`. With none, `/roadmap` falls back to the five code-signal detectors and flags reduced spec confidence — or pass `--goal "<intent>"` to supply that statement inline (restores high spec confidence with no doc).

## Optional flags

- `--build [<N>]` — execute one phase (next pending, or `<N>`); halt at the gate.
- `--status` — read-only progress from `ai/roadmap/plan.md`.
- `--goal "<intent>"` — state what *done* means inline; folded into the intended-state reference (detector 4) as authoritative. Maps requirements with no code/doc trace yet (combine with `<scope>` and `--build`). A broad clause with a large design space (e.g. *anti-download protection*) becomes a `heavy`-tier row — `--build` runs the deep per-feature loop on it, or the plan routes you to `/refine-prompt` for a fuller spec first.
- `--refresh` — re-scan and merge into the existing plan (new gaps appended `pending`; `done` preserved; now-implemented rows flipped `done`); no build.
- `--dry-run` — show what would be built for the target phase; no edits.
- `--allow-dirty` — proceed with uncommitted changes (`--build`).
- `--max-parallel=<N>` — cap concurrent row dispatch within a phase (default: 6 trivial / 3 standard / 1 heavy).
- `--exclude=<scope>` — exclude areas from the map (e.g. `--exclude=admin,internal-tools`).
- `--no-table-stakes` — drop detector 5 (inferred rows); map only stated + code-signal gaps.

## Progress tracking (multi-day workflow)

`ai/roadmap/plan.md` is both the plan and the progress record — there is no separate projection (single codebase, so the row `status` column IS the state).

- **First run** → scans, writes the plan with all rows `pending`. With `--build`: also executes Phase 1.
- **Subsequent runs** → re-map merges into the existing plan (see `--refresh` semantics); `--build` picks the next pending phase.
- **`/roadmap --status`** → reports per-phase `done` / `pending` / `blocked` counts and the next action. No work.
- **Convergence** → re-running `/roadmap` after a build round re-maps and shows what's still missing (and anything the build revealed). Keep going until the map returns zero — the same way `/migration-final` converges a port.

## What you see (output)

```
Roadmap mapped

Scope:               whole project
Project kind:        <PROJECT_KIND>
Missing capabilities: 34  (12 stub · 9 dangling · 6 asymmetry · 4 spec-gap · 2 table-stakes · 1 dead-end)

Phases:              4
  Phase 1 — Foundations:   5 rows  (1 heavy)   — build first
  Phase 2 — Orders:        8 rows              — depends on Phase 1
  Phase 3 — Payments:      6 rows              — depends on Phase 2
  Phase 4 — Analytics:     4 rows              — independent

Blockers (1):        R-019 (refund webhook) — needs upstream payment-provider contract
Risk flags (2):      R-002 password-reset (security surface); R-031 bulk-import (data-loss path)

Plan:                ai/roadmap/plan.md
Next: /roadmap --build   (build Phase 1, then halt)   OR   read the plan and pick a phase
```

Under `--build`, the end-of-run summary mirrors the sibling sweeps — features built, commits, diff, tests, plus the mandatory honesty lines:

```
Phase 1 built

Rows done:           5 / 5
Commits:             5 (one per row)
Diff:                +612 / -38
Tests:               88/88 passing (4 new)
Wall-clock:          9m 41s

Not validated:       e2e suite (no staging env) — run before merge
Risks:               R-002 touches the auth boundary — manual smoke-check recommended
Revert:              git revert <first>..<last>  (or per-row: git revert <sha>)

Phase gate:          PASSED — halting at boundary
Next: /roadmap --build   (Phase 2)   OR   /roadmap --status
```

## What you DON'T see

- "Detector 4 of 6 running"
- "Phase 2 of 4 — dependency wave 3"
- "Ledger row R-014 promoted pending → building"
- "Tier auto-promoted trivial → standard"

All internal. Just the map, and (under `--build`) the result.

## Final report contract

Every `--build` run writes `ai/roadmap/final-report.md` and MUST end with an **`## Actionable next steps`** section per [`templates/snippets/actionable-next-steps.md`](../templates/snippets/actionable-next-steps.md): every `blocked` / deferred row gets one paste-ready follow-up — comment line (WHAT + WHY + row id) + exact command + sorted by dependency order. Routes per row state: `blocked` (cross-repo / upstream) → name the upstream + defer; risk-flagged security/contract rows → `/audit <area>` before shipping; a settled phase → `/roadmap --build` for the next one; learnings → `/learn-from-task`.

## Hard rules (internal)

Applied silently:

- **Read-only is the default.** No flag → no edits, only `ai/roadmap/plan.md`.
- **Every row cites evidence.** A row with no `<file:line>` (or `<doc:section>` for spec-gap) is not emitted — no phantom features. This is the anti-fabrication discipline: `/roadmap` maps what the code/docs actually show is missing, never an invented wishlist.
- **The dependency graph is acyclic.** A cycle surfaces as a finding (halt), not a silent reorder.
- **Foundations first.** Shared / auth / data-layer rows that others depend on land before dependents.
- **One phase per `--build`.** Never advances past the phase boundary in a single run.
- **Gap-count parity under `--build`.** Rows the phase set out to close == rows marked `done`. Nothing flips to `done` without scoped tests green.
- **One commit per row.**
- **Honesty clause in the `--build` summary.** `Not validated:` / `Risks:` / `Revert:` appear before `Next:`, same contract as the other simple-surface sweeps. `Tests: N/N` alone is insufficient.

User sees results, not the policing.

## Failure modes

- **Nothing missing** → "Project appears complete — 0 missing capabilities found. Nothing to plan." (Re-run with `--refresh` after changes.)
- **No statement of intent** → spec-delta detector degrades; the map is built from the five code-signal detectors and the summary flags `Spec confidence: low (no README/PRD/ADRs found)` — pass `--goal "<intent>"` to supply intent inline and restore high confidence.
- **Circular dependency** → halts; surfaces the cycle with citations; asks you to break it.
- **Pre-flight red** (`--build` on a dirty tree / mechanical red) → halts with a one-line "fix this first"; no build attempted.
- **Capability unlocatable** (named in a doc, no code anchor) → emitted as a row with `evidence: <doc:section> (no code yet)` and size defaulted to `standard`.

## Related (advanced)

- `/audit` — rank + fix defects in code that already exists (the complement: *what's wrong*, not *what's missing*).
- `/migrate` — port features that already exist in a V1 codebase (two-codebase delta).
- `/refine-prompt` → `/do` — go deep on ONE feature and execute it.
- `/optimize` — architectural + tactical cleanup of finished code.
- `/learn-from-task` — promote learnings after a `--build` phase.
