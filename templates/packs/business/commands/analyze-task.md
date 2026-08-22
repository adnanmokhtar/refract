---
description: Turn a rough business idea into structured requirements, user stories, and an implementation spec.
---

# /analyze-task "<idea>"

Build command for the spec layer (not code yet). Two-pass: business spec → confirmation → technical spec. All 7 phases apply with a hard pause between Phase 4a and 4b.

> **`--resume <spec-file>`**: resume a paused spec after answering its open questions — skip 4a, **fold the confirmed answers into the existing `Resolved decisions` section** (do NOT add a new section), mark the answered `Open questions` resolved, flip `Status` to `COMPLETE`, then append 4b only (idempotent; never regenerate 4a, never change the `Spec-ID`). See Phase 4b.
>
> **`--decisions <plan-file>`** (or inline `--decisions "q1=…; q2=…"`): decisions are already made — e.g. from a prior Plan Mode discussion — so there is nothing left to confirm. Ingest them, fold into `Resolved decisions`, and emit **4a + 4b in one pass with no gate/pause**. See Phase 4.

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
- Skip the confirmation gate between 4a and 4b. The whole point of this command is the clarification round. **Exception:** when decisions are supplied up front via `--decisions` (e.g. a prior Plan Mode plan), the round is already complete — fold the answers into `Resolved decisions` and emit 4a+4b in one pass. Skipping the gate is legal ONLY when there are no open questions left to ask, never to save time.
- Tag every criterion `MVP`. That's broken scope discipline; force a real MVP/v2 split.
- Substitute its own assumptions for stakeholder answers. Open questions stay open — UNLESS the answer was explicitly supplied (`--decisions`, or a `--resume` answer set), in which case it is a recorded decision, not an assumption.
- Add a separate section to record confirmed answers (`Gate answers`, `Confirmed decisions`, …). Answers have ONE home: the `Resolved decisions` section. A second section is sibling-shape drift (no sibling spec has it) and scatters the same decision across three places.

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
- **One-pass branch:** if invoked with `--decisions` (or the brief itself already resolves every open question — e.g. it pastes a finished Plan Mode plan), there is no gate. Produce 4a, fold the supplied answers into `Resolved decisions`, set `Status: COMPLETE`, and continue straight to 4b in the same run. The gate guards against *guessing*; when answers are given, that risk is gone.
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

> **Resume mechanism (4a → 4b).** To resume after answering the open questions: reply in-session, or re-run `/analyze-task --resume specs/<YYYYMMDD>-<slug>.md`. On resume, skip 4a entirely — ingest the existing draft + the answers, then in this exact order:
> 1. **Fold each confirmed answer into the existing `Resolved decisions` section.** Do NOT add a new section (`Gate answers`, `Confirmed`, etc.) — no sibling spec has one, so it is sibling-shape drift. One home for decisions, not three.
> 2. **Update the `Open questions` section in place** — append `→ resolved: <answer>` to each, or drop the section. Never leave an answered question phrased as still-open.
> 3. **Flip `Status`** from `AWAITING CONFIRMATION (gate between 4a + 4b)` to `COMPLETE (gate passed — answers folded into Resolved decisions)`.
> 4. **Append 4b only.**
> Idempotent: never regenerate 4a, never re-ask answered questions, never change the `Spec-ID`.
>
> **One-pass mechanism (`--decisions`).** When decisions are supplied up front (a prior Plan Mode plan, or inline `--decisions`), there is no pause: produce 4a, run steps 1–3 above against the supplied answers (same one-home rule), then append 4b in the same run. The gate exists to avoid *guessing*; when the answers are given, guessing isn't a risk, so the gate is satisfied — not skipped.

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

Each check below is the mechanical execution of one Hard rule (stated once, below — not restated here). Run them in order; the first four HALT, the rest re-emit.

| # | Check (run it) | On failure |
|---|---|---|
| 1 | Every AC-ID appears in exactly one test-plan row AND ≥1 affected module; every affected module appears in ≥1 AC row | **HALT** — traceability open (an orphan AC does not constrain the build; a module with no AC was fabricated) |
| 2 | Grep every `Then` clause for `works` / `good` / `fast` / `properly` / `gracefully` with no adjacent number or observable | **HALT** — vague AC; rewrite with a threshold or move to `Open questions` |
| 3 | Every story that takes input, mutates state, or calls out has ≥1 negative-path AC | **HALT** — error-path floor unmet (unless the story is declared read-only with no failure modes) |
| 4 | Count open questions vs drafted stories; check who / what / why / success-metric each answerable | **HALT** — `INSUFFICIENT BRIEF`; do not ship a guessed spec as complete |
| 5 | Exactly one section holds confirmed answers, named `Resolved decisions`; no answered question still phrased as open | re-fold and re-emit (a second answers section is sibling-shape drift) |
| 6 | Every criterion carries `MVP` or `v2`; `Out of scope` non-empty | re-emit with a real split / a real boundary |
| 7 | Story count ≤ ~5-7, one bounded context, no independently-shippable halves mixed | flag `EPIC: consider splitting` into `<slug>-1` / `<slug>-2` with a dependency note |
| 8 | Cross-check against active ADRs in `ai/decisions/` | surface the conflict in the spec; never quietly redesign around it |

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

Status: AWAITING CONFIRMATION (gate between 4a + 4b) | INSUFFICIENT BRIEF | EPIC (split suggested) | COMPLETE (gate passed, or one-pass via --decisions)
```

## Failure modes
These are the ways a spec passes every check and is still wrong — the ones the Phase-6 table cannot catch:

- **"It should just work" / "make it good"** → the brief is incomplete; push back rather than inferring. A guessed requirement reads identically to a gathered one.
- **Open questions glossed over with assumed answers** → the spec looks complete and is fictional. An assumption belongs in `Open questions` with its blast radius, never folded silently into prose.
- **A duplicate of an existing spec** → `specs/` and the tracker were never searched; two interpretations of one feature now exist and will diverge in build.
- **Solving the wrong problem beautifully** → every check passes because they all check the spec against itself. The goal restatement + confirmation is the only guard, and it happens before any of them.
- **Writing 4b on a moving target** → the technical spec is derived from unconfirmed business decisions; the gate exists precisely so this cannot happen.

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
