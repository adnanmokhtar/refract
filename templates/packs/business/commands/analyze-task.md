---
description: Turn a rough business idea into structured requirements, user stories, and an implementation spec.
---

# /analyze-task "<idea>"

Build command for the spec layer (not code yet). Two-pass: business spec → confirmation → technical spec. All 7 phases apply with a hard pause between Phase 4a and 4b.

## The Premise (read this first, internalize, do not deviate)

**Existing specs are the truth.** The repo's `specs/` folder is the canon of how this team writes a spec — section names, terminology, stakeholder fields, acceptance-criteria phrasing, scope-tag format (MVP/v2), risk + rollout shape. A new spec is a **sibling**, not a new style. Inventing sections / renaming `Acceptance criteria` to `Behavior` / dropping `Out of scope` because the brief is small — these are drift, not improvement.

**The agent's job is exactly this:**
1. Read 2-3 recent specs in `specs/` before drafting. They define the shape.
2. Mirror their section list, ordering, terminology, stakeholder-question format, MVP/v2 tagging convention.
3. Diverge only where the new task's domain genuinely demands it (e.g., adding a Native-capability section for a mobile-only spec). Document the divergence in 1 line at the top.
4. Use the team's own vocabulary — if specs say "tenant" never write "workspace"; if specs say "owner-confirmed" never write "stakeholder-validated."

**The agent does NOT:**
- Invent sections that no sibling spec has (e.g., "Strategic alignment", "Vision statement"). If no sibling has it, the new spec doesn't either.
- Drop required sections because the brief is short. `Out of scope` empty = scope creep guaranteed; force the section non-empty.
- Skip the confirmation gate between 4a and 4b. The whole point of this command is the clarification round.
- Tag every criterion `MVP`. That's broken scope discipline; force a real MVP/v2 split.
- Substitute its own assumptions for stakeholder answers. Open questions stay open.

**Mechanical halt — sibling-shape parity (mandatory before Phase 4a draft):**

Before dispatching `business-analyst`, the agent MUST:
- List the 2-3 sibling specs read (`specs/*.md` paths).
- Name the section list those specs share (e.g., `Problem / Stories / AC / Out of scope / Open questions / Affected modules / DB / API / Test plan / Risk`).
- Confirm the new spec will use that exact section list, in that order.
- If no sibling specs exist — HALT. Ask the user to confirm the spec template, do not invent one from training data.

Section renaming or section invention without a sibling precedent is rejected; the spec is regenerated mirroring siblings.

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

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

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
- Skipped checking `specs/` or tracker; produced a duplicate of an existing spec → wasted work + diverging interpretations.
- Open questions glossed over with assumed answers → spec looks complete but is fictional.

## Hard rules

- **Two-pass with mandatory PAUSE between 4a and 4b.** Confirmation gate is non-negotiable. Skipping it produces wrong code.
- **Every user story has Given/When/Then acceptance criteria.** Vague AC = vague tests = missed bugs.
- **Out-of-scope section non-empty.** Without explicit anti-scope, scope creep guaranteed.
- **MVP / v2 tagging on every criterion.** Don't ship "everything is MVP" specs.
- **No invented requirements.** Every spec line traces back to brief or stakeholder answer.
- **ADR-aware.** Spec that conflicts with an active ADR halts; surface the conflict, don't redesign around it.
- **One spec at a time.** Don't expand a brief that already has a spec — point at the existing spec.

## Stack-awareness

While the spec is stack-agnostic at Phase 4a, Phase 4b adapts to the project's stack:
- Backend-only project → API surface section dominates; no UI section.
- Frontend-only → Components/screens/state section; API consumed (existing or proposed) listed but not designed.
- Fullstack → Both sections; cross-stack contract specified as the seam.
- Mobile → Add native-capability section (camera/location/etc.) + iOS+Android parity note.

Read CLAUDE.md to determine stack at Phase 3; tailor Phase 4b sections accordingly.

## Related

### Sibling commands in business pack
- `/audit-business` — sibling command in business pack
- `/expand-task` — sibling command in business pack
