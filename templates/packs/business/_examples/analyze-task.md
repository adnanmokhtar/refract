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
- Agent produces:
  - Problem statement (one sentence).
  - User stories (`As <role>, I want <action>, so that <outcome>`).
  - Acceptance criteria per story (`Given/When/Then`).
  - Out of scope (explicit non-goals).
  - Open questions (assumptions to confirm with stakeholder).
- Save draft to `specs/<YYYYMMDD>-<slug>.md`.
- Print draft + open questions. **STOP. Wait for user to confirm or amend.**

**4b — Technical spec (after confirmation):**
- Append to the same file:
  - Affected modules (file paths).
  - DB changes (new tables / columns / indexes / migrations needed).
  - API surface (new/changed endpoints with method + path + auth).
  - Test plan (unit / integration / e2e by layer).
  - Risk + rollout note.
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

## Phase 7 — Improve
- `/learn-from-task` — capture clarification patterns (which ambiguities recur).
- If 3+ specs share a theme → queue ADR proposal: domain primitive (e.g. "every export needs async + permission gate").
- Open questions left unresolved → append to `ai/dynamic/decisions-pending.md`.

## Output format
```
## /analyze-task — <slug>

Phase 1 (Understand): brief = <input>; not in specs/ or tracker
Phase 3 (Retrieved): N ADRs scanned; business-domain consulted
Phase 4a (Generated): business spec at specs/<date>-<slug>.md
   Open questions (confirm before 4b):
     - Export to CSV only or also XLSX?
     - Async via job queue or sync if < N rows?
     - Permission: tenant admin only, or any user with orders.read?
Phase 4b (Generated, after confirmation): technical spec appended
Phase 5 (Updated): spec file, changelog, status.md
Phase 6 (Validated): every story has G/W/T; out-of-scope listed; no ADR conflict
Phase 7 (Improved): decisions-pending updated; patterns queued

Status: AWAITING CONFIRMATION (gate between 4a + 4b) | COMPLETE
```

## Failure modes
- Skipping the confirmation gate → wrong code; the whole point of this command is the clarification round.
- "It should just work" / "make it good" → incomplete brief; push back, don't guess.
- Writing technical spec on a moving target → useless; gate is non-negotiable.
- Spec contradicts active ADR → surface, don't quietly redesign around it.
- All criteria tagged MVP → scope discipline broken; force MVP/v2 split.
