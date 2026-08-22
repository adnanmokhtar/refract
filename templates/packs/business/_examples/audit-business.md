---
description: Audit a feature from the user perspective — missing cycles, broken flows, gap closures.
---

# /audit-business <feature>

Audit command. Reviews a shipped feature for completeness, not correctness. Phases 1-3 + 6 dominate; Phase 4 produces findings; Phase 5 logs the audit; Phase 7 surfaces systemic gaps.

## The Premise (read this first, internalize, do not deviate)

**Existing specs + prior audits are the truth.** The feature was built against a spec; the spec encodes the intent. A gap is the delta between **what the spec promised** and **what the user can actually do** — not the delta between what the agent imagines a great product would be and what the feature is. Inventing gaps the spec never claimed is scope creep dressed as audit.

Read the feature's spec(s) from `specs/` before walking the code — the spec is the oracle. Read prior `ai/audits/<date>-<feature>*.md` for the same feature; repeated findings are SYSTEMIC, not new. Walk the user journey end-to-end and flag concrete gaps with `<file:line>` or `<route+role>` reproduction steps. Tag every finding `[blocker]` / `[gap]` / `[opinion]`; opinions never inflate blocker count.

**The agent does NOT** audit code style (stay in user POV) · propose net-new features (in-scope gaps route to `/analyze-task`) · write "feels off" findings · skip the prior-audit cross-reference · pad blocker counts with `[opinion]` enhancements.

**Mechanical halt — hand-wave grep + cite-or-halt (mandatory before the Phase 5 write):** before appending to `ai/audits/<date>-business-<feature>.md`, grep the findings and reject any line that contains `feels` / `seems` / `should probably` / `might want` / `could be better` / `polish` / `nicer flow` without a reproducible step list · lacks a `<route or screen + role + action>` reproduction for a `[blocker]` / `[gap]` · lacks a citation of either the spec line or an entity-lifecycle gap · tags `[opinion]` with no heuristic anchor. Findings that fail the grep are **dropped**, not softened; report `Dropped (uncited): <N>`. The same finding in 3+ historical audits without escalation forces the SYSTEMIC tag and queues an ADR.

## When to use / NOT to use
- USE: feature is "done" but feels incomplete in walkthrough.
- USE: support tickets cluster around one feature.
- USE: before promoting from beta to GA.
- NOT: code-only features with no user surface (refactors, infra) — nothing to audit from user perspective.
- NOT: as a substitute for `/analyze-task` on net-new scope — this audits what exists.

## Phase 1 — Understand
- Resolve feature: name → directory or module path. If ambiguous, ask.
- Confirm goal: gap finding (this command) vs net-new scope proposal (route to `/analyze-task`).

## Phase 2 — Organize

The three business agents are **orthogonal axes, not alternatives**, and this command is the only place they are dispatched:

| Agent | Axis | Dispatch when |
|---|---|---|
| `business-auditor` | EXPERIENCE — missing cycles, broken flows, dead ends | always |
| `@workflow-integrity` | STATE GRAPH — transitions legal, guarded, terminal, reachable | entity carries a `status` / `state` / `phase` column, a state-machine config, or scattered `if status ==` checks |
| `@domain-model-auditor` | INVARIANTS — each aggregate rule names a real enforcement layer | feature touches ORM models / migrations / money / inventory / balance |

Optional: `ux-reviewer` for the visual / interaction overlay. **A warranted axis that was not run is reported `NOT AUDITED (reason)`, never silence** — "no findings on an axis nobody opened" reads exactly like a clean audit. Plan grouping: blockers | gaps | enhancements.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Feature-specific:
- Feature code (controllers, services, UI components).
- `specs/*<feature>*.md` — original intent (gaps from spec are highest signal).
- Prior `ai/audits/<date>-<feature>*.md` — repeated findings = systemic.
- Support-ticket samples if linked.

## Phase 4 — Generate (findings)
- Dispatch `business-auditor` with assembled context.
- Dispatch `@workflow-integrity` when the lifecycle trigger fired — an `ILLEGAL⚠` cell or a money edge at `$-conserve: UNVERIFIED` is a finding of THIS command.
- Dispatch `@domain-model-auditor` when the domain trigger fired — any `enforced-where: NOWHERE` on money / inventory / balance is a `[blocker]` here.
- Auditor walks the user journey and flags:
  - **Missing cycles** — user can start a thing but not finish it (created order, no way to cancel).
  - **Broken flows** — step N depends on data step N-1 doesn't produce.
  - **Dead ends** — UI states with no action available (empty list with no "create" CTA, error with no retry).
  - **Inconsistent state** — same entity shown differently across views.
  - **Notification gaps** — events that should email/notify but don't.
- Optionally dispatch `ux-reviewer` for interaction overlay.
- Print grouped findings:
  ```
  Feature: subscriptions

  Broken flows (1):
    - User can upgrade plan but downgrade returns 500 (the payment-vendor service's change-plan call doesn't handle prorate=false)
  Missing cycles (3):
    - No "cancel subscription" UI; only available via API
    - Failed payment doesn't surface in app — user only sees it in email
    - Renewed subscription doesn't notify the user
  Enhancements [opinion] (2):
    - Trial countdown banner
    - Plan comparison table on billing page
  ```
- Suggest next-step commands per finding (`/add-feature` / `/fix-bug` / `/expand-task`). Note: `/add-feature` is **pack-specific** (backend / frontend / mobile) — route through the pack-neutral `/do` meta-router when you can't be sure which pack is installed.

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-business-<feature>.md` — append timestamped report.
- `ai/dynamic/changelog.md` — one-line: `Business audit on <feature>: B blockers, G gaps`.
- `ai/status.md` `## Recent Changes` if blockers found.

## Phase 6 — Validate
- Each blocker / gap is reproducible (steps named, not vibes).
- Enhancements clearly labeled `[opinion]` and not padding the blocker count.
- Cross-reference with prior `ai/audits/` — repeated findings flagged as SYSTEMIC.
- **Axis coverage is stated, not assumed.** One line per axis — `experience` / `state-graph` / `invariants` — each `AUDITED (verdict)` or `NOT AUDITED (<no lifecycle surface | no domain layer | not run | no access>)`.

### Terminal verdict — computed from the axis lines

- `COMPLETE` — every warranted axis AUDITED, zero `[blocker]` open. Carries the three axis verdicts.
- `BLOCKED on <B> broken flows` — an axis found a blocker (broken journey, `ILLEGAL⚠` money edge, money invariant enforced NOWHERE). Name each.
- `INCOMPLETE — <axis> not audited` — a warranted axis was not run, or the feature could not be walked end-to-end. This is the honest default, and reporting it IS a success; `COMPLETE` printed over an un-audited axis is the defect this gate exists to prevent.

## Phase 7 — Improve
- `/learn-from-task` — capture finding categories.
- If same gap class appears 3+ features (e.g. "no cancel UI") → queue to `ai/dynamic/learned-patterns.md` as a domain principle (every lifecycle needs symmetric exit).
- If notification gaps recur → queue ADR: notification taxonomy + required events per entity.
- If support tickets correlate with audit findings → queue process improvement.

## Output format
```
## /audit-business — <feature>: <B> blockers, <G> gaps

Phase 1 (Understand): feature = <name>; goal = gap finding
Phase 3 (Retrieved): code + spec + prior audits scanned
Phase 4 (Generated): grouped findings (above)
Phase 5 (Updated): ai/audits/<date>-business-<feature>.md, changelog, status.md
Phase 6 (Validated): findings reproducible; opinions labeled; SYSTEMIC tags applied

Axis coverage:
  experience   AUDITED   — @business-auditor: <N> defects, <G> gaps
  state-graph  AUDITED   — @workflow-integrity: <verdict> · $-conserve <K·P·U>
  invariants   NOT AUDITED (no domain layer — feature is UI-only)

Phase 7 (Improved): N systemic patterns queued

Status: COMPLETE | BLOCKED on <B> broken flows | INCOMPLETE — <axis> not audited
```

## Failure modes
- Auditing code style instead of UX → working code with bad UX still fails this audit; stay in user POV.
- Padding blockers list with `[opinion]` enhancements → distorts severity; label and segregate.
- Proposing new features → out of scope; gaps in scope route to `/analyze-task`.
- Same finding appears in 3+ audits without escalation → systemic; force ADR or process change.
- Blocker described as "feels off" without reproduction steps → reject; describe reproducible.
- Cross-referencing skipped → repeat findings stay invisible; always check prior `ai/audits/`.
- Reporting `COMPLETE` after auditing only the experience axis → the state-graph and invariant axes were never opened. Print the axis lines.
