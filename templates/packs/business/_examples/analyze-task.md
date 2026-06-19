---
description: Turn a rough business idea into structured requirements, user stories, and an implementation spec.
---

# /analyze-task "<idea>"

Build command for the spec layer (not code yet). Two-pass: business spec → confirmation → technical spec. All 7 phases apply with a hard pause between Phase 4a and 4b.

## When to use / NOT to use
- USE: owner / stakeholder gave a one-liner that needs unpacking before code.
- USE: sibling of `/expand-task` — reach for `/analyze-task` when an idea needs a full business + technical spec; reach for `/expand-task` when a one-liner just needs an implementer-ready prompt. Neither consumes the other.
- NOT: when a spec already exists in `specs/` or a tracker ticket — use that.
- NOT: for trivial single-file changes — over-process for under-scope.

## Phase 1 — Understand
- Take rough input as quoted string argument.
- Confirm: is this a real ambiguous brief, or already specified elsewhere? Search `specs/` first.

## Phase 2 — Organize
- Decide the two passes:
  - 4a Business spec → user confirmation gate.
  - 4b Technical spec (only after confirmation).
- Identify which agents to dispatch: `business-analyst` for 4a, defer technical agent until after the gate.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Spec-specific:
- `ai/decisions/` — recent ADRs (don't redesign around an active constraint).
- `specs/` — search for related drafts.
- `ai/architecture.md` — boundary the spec must respect.

## Phase 4 — Generate (two passes with confirmation gate)

**4a — Business spec (then PAUSE):**
- Dispatch `business-analyst` with input + `ai/business-domain.md` + recent ADRs.
  - **Missing-agent fallback:** if `business-analyst` is not installed, produce the 4a spec inline against the business-pack spec checklist — never skip the structured pass. Note `inline:business-analyst`.
- Agent produces:
  - Problem statement (one sentence).
  - User stories (`As <role>, I want <action>, so that <outcome>`).
  - Acceptance criteria per story (`Given/When/Then`).
  - Out of scope (explicit non-goals).
  - Open questions (assumptions to confirm with stakeholder).
- **INSUFFICIENT-BRIEF halt:** if open questions outnumber stories, OR who/what/why/success-metric is unanswerable → HALT with status `INSUFFICIENT BRIEF`; do not guess.
- Save draft to `specs/<YYYYMMDD>-<slug>.md` with a `Spec-ID: <slug>-<4char-hash>` header line (stable; cited by `/add-feature`, PRs, commits).
- Print draft + open questions. **STOP. Wait for user to confirm or amend.**

**4b — Technical spec (after confirmation):**

> **Resume (4a → 4b):** reply in-session, or re-run `/analyze-task --resume specs/<…>.md` — skip 4a, ingest draft + answers, append 4b only (idempotent; never regenerate 4a or change the `Spec-ID`).
> **Section-shape rule:** mirror sibling specs; add a section below only when its signal applies — NFR/SLO, authorization, observability are strongly recommended for any non-trivial feature.

- Append to the same file:
  - **Traceability table** (required): Story | AC-ID (G/W/T) | Test-plan item | Affected module(s).
  - Affected modules (file paths).
  - DB changes (tables / columns / indexes / migrations) → relations / FKs / constraints / retention.
  - API surface (new/changed endpoints with method + path).
  - Authorization & data sensitivity (who-can-do-what per endpoint; PII / data-classification of new fields).
  - Non-functional requirements & SLOs; Error & edge-case behavior; Observability (log/measure/trace + redaction).
  - Rollout & migration: feature-flag, expand→migrate→contract + backward-compat, rollback path, backfill.
  - Dependencies & sequencing; Test plan (unit / integration / e2e); Success metrics (traceable to `ai/project-goals.md`); Sizing signal (trivial/standard/heavy → feeds /add-feature tier).
- Tag each criterion `MVP` or `v2` for scope discipline.

## Phase 5 — Update
- `specs/<YYYYMMDD>-<slug>.md` — created (and appended after gate).
- `ai/dynamic/changelog.md` — one-line: `spec drafted: <slug>`.
- `ai/status.md` — `## Recent Changes` bullet if spec is non-trivial.

## Phase 6 — Validate
- Each user story has at least one Given/When/Then acceptance criterion.
- Out-of-scope section is non-empty (forces explicit boundary).
- If spec conflicts with an active ADR → surface the conflict, don't redesign around it.
- Each criterion tagged `MVP` or `v2`.
- **Traceability closure (HALT):** every AC maps to exactly one test-plan item + ≥1 module; every module traces to ≥1 AC.
- **Vague-AC detector:** reject `Then` clauses with unquantified qualifiers (works/good/fast/properly/gracefully).
- **Error-path floor:** input/mutation/external-call stories need ≥1 negative-path AC.
- **INSUFFICIENT BRIEF:** open questions > stories, or a core dimension unanswerable → don't ship as complete.
- **EPIC-split flag:** >5-7 stories OR >1 bounded context OR mixed MVP/v2 → suggest sibling specs `<slug>-1`/`<slug>-2`.

## Phase 7 — Improve
- `/learn-from-task` — capture clarification patterns (which ambiguities recur).
- If 3+ specs share a theme → queue ADR proposal: domain primitive (e.g. "every export needs async + permission gate").
- Open questions left unresolved → append to `ai/dynamic/decisions-pending.md`.

## Output format
```
## /analyze-task — <slug>   [Spec-ID: <slug>-<4char-hash>]

Phase 1 (Understand): brief = <input>; not in specs/ or tracker
Phase 3 (Retrieved): N ADRs scanned; business-domain consulted
Phase 4a (Generated): business spec at specs/<date>-<slug>.md
   Open questions (confirm before 4b):
     - Export to CSV only or also XLSX?
     - Async via job queue or sync if < N rows?
     - Permission: tenant admin only, or any user with orders.read?
Phase 4b (Generated, after confirmation): technical spec appended; traceability table complete
Phase 5 (Updated): spec file, changelog, status.md
Phase 6 (Validated): every story has G/W/T; traceability closed (AC↔test↔module); no vague AC;
   error-path floor met; out-of-scope listed; no ADR conflict; epic-split checked
Phase 7 (Improved): decisions-pending updated; patterns queued

Next: /add-feature specs/<date>-<slug>.md  (add --plan to plan-only)

Status: AWAITING CONFIRMATION (gate between 4a + 4b) | INSUFFICIENT BRIEF | EPIC (split suggested) | COMPLETE
```

## Failure modes
- Skipping the confirmation gate → wrong code; the whole point of this command is the clarification round.
- "It should just work" / "make it good" → incomplete brief; push back, don't guess.
- Writing technical spec on a moving target → useless; gate is non-negotiable.
- Spec contradicts active ADR → surface, don't quietly redesign around it.
- All criteria tagged MVP → scope discipline broken; force MVP/v2 split.
- Drafting on a thin brief → ship `INSUFFICIENT BRIEF` instead of guessing.
- AC with no test/module, or module with no AC → broken traceability; HALT.
- Unquantified ACs ("works", "fast") → untestable; vague-AC detector rejects.
- Mutation/external-call story with only happy-path ACs → error-path floor unmet.
- Oversized multi-context spec → flag `EPIC`, propose sibling specs.
