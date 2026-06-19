---
description: Turn a rough business idea into structured requirements, user stories, and an implementation spec.
---

# /analyze-task "<idea>"

Build command for the spec layer (not code yet). Two-pass: business spec → confirmation → technical spec. All 7 phases apply with a hard pause between Phase 4a and 4b.

> **`--resume <spec-file>`**: resume a paused spec after answering its open questions — skip 4a, ingest the existing draft + answers, append 4b only (idempotent; never regenerate 4a, never change the `Spec-ID`). See Phase 4b.

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
  - **Missing-agent fallback:** if `business-analyst` is not installed in this project, produce the 4a business spec inline against the business-pack spec checklist (problem / stories / G+W+T AC / out-of-scope / open questions) — never skip the structured pass. Note `inline:business-analyst` in the consolidation note.
- Agent produces:
  - Problem statement (one sentence).
  - User stories (`As <role>, I want <action>, so that <outcome>`).
  - Acceptance criteria per story (`Given/When/Then`).
  - Out of scope (explicit non-goals).
  - Open questions (assumptions to confirm with stakeholder).
- **INSUFFICIENT-BRIEF halt:** if open questions outnumber drafted user stories, OR any core dimension (who / what / why / success-metric) is unanswerable from the brief → HALT with status `INSUFFICIENT BRIEF`. Surface the gaps; do NOT draft stories on guesses to satisfy a non-empty check.
- Save draft to `specs/<YYYYMMDD>-<slug>.md`, with a `Spec-ID:` header as the first line (Plan-ID style): `Spec-ID: <slug>-<4char-hash>` — a short hash of `(slug + timestamp + project-name)`, stable for the file, cited later by `/add-feature`, PRs, and commits.
- Print draft + open questions. **STOP. Wait for user to confirm or amend.**

**Spec-file header (top of the saved file):**
```
Spec-ID: <slug>-<4char-hash>
```

**4b — Technical spec (after confirmation):**

> **Resume mechanism (4a → 4b).** To resume after answering the open questions: reply in-session, or re-run `/analyze-task --resume specs/<YYYYMMDD>-<slug>.md`. On resume, skip 4a entirely — ingest the existing draft + the answers, and append 4b only. This is idempotent: never regenerate 4a, never re-ask answered questions, never change the `Spec-ID`.

> **Section-shape rule (read before listing sections).** Mirror the section list of sibling specs in `specs/`. Where a concern below applies to *this* task and no sibling covers it, add its section — `Non-functional requirements & SLOs`, `Authorization & data sensitivity`, and `Observability requirements` are strongly recommended for any non-trivial feature. The list below is **signal-gated**, not a checklist to fill on every spec: add a section when its signal is present, omit it (don't stub it) when it isn't.

- Append to the same file:
  - **Traceability table** (required) — one row per acceptance criterion:

    | Story | AC-ID (G/W/T) | Test-plan item | Affected module(s) |
    |---|---|---|---|

  - Affected modules (file paths).
  - DB changes (new/changed tables / columns / indexes / migrations) → relations + FKs + constraints + retention.
  - API surface (new/changed endpoints with method + path).
  - Authorization & data sensitivity — who-can-do-what per endpoint (promote the bare "auth" attribute); PII / data-classification of any new fields.
  - Non-functional requirements & SLOs — latency / throughput / availability targets where the signal applies.
  - Error & edge-case behavior — failure, empty, concurrent, partial-write, abusive-input handling.
  - Observability requirements — what to log / measure / trace, plus redaction of sensitive fields.
  - Rollout & migration (split the catch-all rollout note): feature-flag decision; expand → migrate → contract order + backward-compat; rollback path; backfill of existing rows.
  - Dependencies & sequencing — what must ship first (feature / migration / ADR).
  - Test plan (unit / integration / e2e by layer).
  - Success metrics — product outcome, traceable to `ai/project-goals.md`.
  - Sizing signal — `trivial` / `standard` / `heavy` hint that feeds `/add-feature`'s tier selection.
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
- **Traceability closure (HALT on failure):** every AC-ID maps to exactly one test-plan item AND ≥1 affected module. Every affected module traces back to ≥1 AC (catches fabricated modules). HALT if any AC has no test or no module, or any module has no AC.
- **Vague-AC detector:** each `Then` clause must assert an observable / measurable outcome. Reject unquantified qualifiers (works / good / fast / properly / gracefully) carrying no threshold — rewrite with a number or move to Open questions.
- **Error-path floor:** any story involving input / mutation / external-call requires ≥1 negative-path AC (unless the story is explicitly "read-only, no failure modes").
- **INSUFFICIENT-BRIEF re-check:** if open questions outnumber drafted stories, OR a core dimension (who / what / why / success-metric) is unanswerable → status `INSUFFICIENT BRIEF`, do not ship the spec as complete.
- **EPIC-split flag:** if the spec exceeds ~5-7 stories OR spans >1 bounded context OR mixes independently-shippable MVP / v2 → flag `EPIC: consider splitting` into sibling specs (`<slug>-1`, `<slug>-2`) with a dependency note. Don't silently emit one oversized spec.

## Phase 7 — Improve
- **Handoff (single next command):** `Next: /add-feature specs/<YYYYMMDD>-<slug>.md` — cite the `Spec-ID`. Add `--plan` to plan the feature and exit before any edit (`/add-feature specs/<…>.md --plan`). Mirror `/expand-task`'s one-next-command discipline; do not list a menu of follow-ups.
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
- Skipped checking `specs/` or tracker; produced a duplicate of an existing spec → wasted work + diverging interpretations.
- Open questions glossed over with assumed answers → spec looks complete but is fictional.
- Drafting stories on a thin brief to satisfy a non-empty check → ship `INSUFFICIENT BRIEF` instead; guessed requirements are worse than a halt.
- AC with no test or module, or a module with no AC → broken traceability; the spec doesn't actually constrain the build. HALT and close the table.
- Unquantified ACs ("works", "fast", "gracefully") → untestable; the vague-AC detector rejects them.
- Mutation / external-call story with only happy-path ACs → error-path floor unmet; the failure case is where users get burned.
- One oversized spec spanning many contexts → should have been an epic split; flag `EPIC` and propose sibling specs.

## Hard rules

- **Two-pass with mandatory PAUSE between 4a and 4b.** Confirmation gate is non-negotiable. Skipping it produces wrong code.
- **Every user story has Given/When/Then acceptance criteria.** Vague AC = vague tests = missed bugs.
- **Out-of-scope section non-empty.** Without explicit anti-scope, scope creep guaranteed.
- **MVP / v2 tagging on every criterion.** Don't ship "everything is MVP" specs.
- **No invented requirements.** Every spec line traces back to brief or stakeholder answer.
- **ADR-aware.** Spec that conflicts with an active ADR halts; surface the conflict, don't redesign around it.
- **One spec at a time.** Don't expand a brief that already has a spec — point at the existing spec.
- **Traceability is mandatory.** Every AC maps to exactly one test-plan item + ≥1 module; every module traces to ≥1 AC. No orphan ACs, no fabricated modules.
- **Insufficient brief halts.** If the brief can't answer who / what / why / success-metric, or open questions outnumber stories, ship `INSUFFICIENT BRIEF` — never guess to fill the spec.
- **Observable ACs only.** Every `Then` asserts a measurable outcome; mutation / external-call stories carry ≥1 negative-path AC.
- **Stable Spec-ID.** Each spec gets a `Spec-ID` at creation; it never changes (including across `--resume`) and is cited by `/add-feature`, PRs, and commits.
- **Epic discipline.** Specs over ~5-7 stories or >1 bounded context split into sibling specs with a dependency note — never one oversized spec.

## Stack-awareness

While the spec is stack-agnostic at Phase 4a, Phase 4b adapts to the project's stack:
- Backend-only project → API surface section dominates; no UI section.
- Frontend-only → Components/screens/state section; API consumed (existing or proposed) listed but not designed. Add an a11y acceptance criterion (keyboard / focus / contrast / ARIA) and i18n requirements (string keys, RTL, locale formatting) for any user-facing surface.
- Fullstack → Both sections; cross-stack contract specified as the seam.
- Mobile → Add native-capability section (camera/location/etc.) + iOS+Android parity note.

Read CLAUDE.md to determine stack at Phase 3; tailor Phase 4b sections accordingly.

## Related

### Sibling commands in business pack
- `/audit-business` — sibling command in business pack
- `/expand-task` — sibling command in business pack
