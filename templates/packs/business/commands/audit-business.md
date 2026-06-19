---
description: Audit a feature from the user perspective — missing cycles, broken flows, gap closures.
---

# /audit-business <feature>

Audit command. Reviews a shipped feature for completeness, not correctness. Phases 1-3 + 6 dominate; Phase 4 produces findings; Phase 5 logs the audit; Phase 7 surfaces systemic gaps.

## The Premise (read this first, internalize, do not deviate)

**Existing specs + prior audits are the truth.** The feature was built against a spec; the spec encodes the intent. A gap is the delta between **what the spec promised** and **what the user can actually do** — not the delta between what the agent imagines a great product would be and what the feature is. Inventing gaps that the spec never claimed is scope creep dressed as audit.

**The agent's job is exactly this:**
1. Read the feature's spec(s) from `specs/` before walking the code. The spec is the oracle.
2. Read prior `ai/audits/<date>-<feature>*.md` for the same feature — repeated findings are SYSTEMIC, not new.
3. Walk the user journey end-to-end and flag concrete gaps with `<file:line>` or `<route+role>` reproduction steps.
4. Tag every finding: `[blocker]` (broken flow), `[gap]` (missing cycle / dead end / inconsistent state / notification gap), `[opinion]` (enhancement). Opinions never inflate blocker count.

**The agent does NOT:**
- Audit code style. Working code with bad UX still fails this audit; bad code with good UX passes. Stay in user POV.
- Propose net-new features. Gaps in scope route to `/analyze-task`, not into the audit report.
- Write "feels off" findings. Every finding has a reproduction (route, role, action, expected vs actual).
- Skip the prior-audit cross-reference. Repeated findings without escalation hide the systemic problem.
- Pad blocker counts with `[opinion]` enhancements to look thorough.

**Mechanical halt — hand-wave grep + cite-or-halt (mandatory before Phase 5 write):**

Before appending to `ai/audits/<date>-business-<feature>.md`, the agent MUST grep its own findings and reject any line that:
- Contains `feels`, `seems`, `should probably`, `might want`, `could be better`, `polish`, `nicer flow` — without a reproducible step list.
- Lacks a `<route or screen + role + action>` reproduction for `[blocker]` / `[gap]` findings.
- Lacks a citation of either the spec line ("spec said X, app does Y") OR an entity-lifecycle gap (created → no exit / edit → no audit log / etc.).
- Tags `[opinion]` without a heuristic anchor (Nielsen N, declared product principle, prior decision in `ai/decisions/`).

Findings that fail the grep are **dropped**, not softened. Report `Dropped (uncited): <N>` in the output. Same finding appearing in 3+ historical audits without escalation = SYSTEMIC tag forced; queue ADR.

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
- Decide reviewers:
  - Always: `business-auditor` walks user journeys.
  - Optional: `ux-reviewer` for visual / interaction overlay.
- Plan grouping: blockers (broken flow) | gaps (missing cycle) | enhancements (opinion).

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Feature-specific:
- Feature code (controllers, services, UI components).
- `specs/*<feature>*.md` — original intent (gaps from spec are highest signal).
- Prior `ai/audits/<date>-<feature>*.md` — repeated findings = systemic.
- Support-ticket samples if linked.

## Phase 4 — Generate (findings)
- Dispatch `business-auditor` with assembled context.
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
- Suggest next-step commands per finding (`/add-feature` / `/fix-bug` / `/expand-task`). Note: `/add-feature` is **pack-specific** — it resolves to whichever track pack is installed (backend / frontend / mobile), not a single canonical command. If you can't be sure which pack is loaded, route through the pack-neutral `/do` meta-router (it dispatches to the right `/add-feature` for the project) rather than naming a track command the project may not have.

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-business-<feature>.md` — append timestamped report.
- `ai/dynamic/changelog.md` — one-line: `Business audit on <feature>: B blockers, G gaps`.
- `ai/status.md` `## Recent Changes` if blockers found.

## Phase 6 — Validate
- Each blocker / gap is reproducible (steps named, not vibes).
- Enhancements clearly labeled `[opinion]` and not padding the blocker count.
- Cross-reference with prior `ai/audits/` — repeated findings flagged as SYSTEMIC.

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
Phase 7 (Improved): N systemic patterns queued

Status: COMPLETE | BLOCKED on <B> broken flows
```

## Failure modes
- Auditing code style instead of UX → working code with bad UX still fails this audit; stay in user POV.
- Padding blockers list with `[opinion]` enhancements → distorts severity; label and segregate.
- Proposing new features → out of scope; gaps in scope route to `/analyze-task`.
- Same finding appears in 3+ audits without escalation → systemic; force ADR or process change.
- Blocker described as "feels off" without reproduction steps → reject; describe reproducible.
- Cross-referencing skipped → repeat findings stay invisible; always check prior `ai/audits/`.

## Related

### Sibling commands in business pack
- `/analyze-task` — sibling command in business pack
- `/expand-task` — sibling command in business pack
