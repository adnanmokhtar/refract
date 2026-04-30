---
description: Turn a one-line task into a full implementer-ready prompt with context, acceptance criteria, scope, and next-step command.
---

# /expand-task "<brief>"

Most "fix login bug" / "make orders faster" tickets are one line. This produces a structured prompt an implementer (or `/add-feature` / `/fix-bug`) can execute.

## The Premise (read this first, internalize, do not deviate)

**Existing specs are the truth.** This command produces a sibling artifact in the team's `specs/` shape — same sections, same terminology, same Given/When/Then phrasing, same in/out scope discipline, same Suggested-flow tail. The expansion is **structurally identical** to a hand-written spec; only the inputs change (one-liner vs full brief). Inventing a new shape because "this is just an expansion" defeats downstream tools (`/add-feature`, `/fix-bug`) that expect the canonical shape.

**The agent's job is exactly this:**
1. Read 1-2 sibling specs in `specs/` to lock the section list + terminology.
2. Mirror them: `Goal / Context / Acceptance criteria / Scope (in) / Scope (out) / Edge cases / Affected modules / Estimated complexity / Suggested flow`.
3. Cite the brief on every line — every claim ties back to a sentence in the original brief OR a clarification answer. No invented requirements.
4. Stakeholder-decision items stay flagged, never invented. "Should this support X?" → ask, do not guess.

**The agent does NOT:**
- Skip the sibling-spec read. Drift starts with "I'll just structure it my way for now."
- Run more than one clarification round. Multi-round = the brief was too vague; send it back.
- Fabricate `Affected modules`. Each path is grounded in `ai/modules.md` or actual file existence.
- Suggest more than one next command. Multiple = ambiguity at handoff = wrong thing built.
- Tag every criterion MVP. Force a real MVP/v2 split or push back on scope.

**Mechanical halt — sibling-shape parity (mandatory before Phase 4 generate):**

Before producing the expanded spec, the agent MUST:
- Name the 1-2 sibling specs it read (`specs/*.md` paths).
- Confirm the new spec will use the same section list + ordering as those siblings.
- Confirm Given/When/Then phrasing matches sibling AC style.
- Confirm `Affected modules` paths exist (grep `ai/modules.md` or filesystem) — fabricated paths halt the run.
- If no sibling specs exist — HALT. Confirm the template with the user, do not invent shape from training data.

A spec produced without sibling-shape parity is rejected; regenerate or halt.

## Phases applied

1, 2, 3, 4, 5, 7. Phase 6 (Validate) is light — this command produces a spec, not code; validation = "user confirms spec is right".

## When to use / NOT to use

- USE: owner / stakeholder dropped a one-liner in chat.
- USE: before opening a real ticket / starting work.
- USE: ahead of `/add-feature`, `/fix-bug`, `/analyze-task`.
- NOT: when the brief is already structured (acceptance criteria, scope, etc. already present).
- NOT: mid-implementation (`/learn-from-task` instead).

## Phase 1 — Understand (the ask)

1. Take the brief input verbatim. Don't paraphrase yet.
2. Ask clarifying questions in ONE consolidated round (don't ping-pong):
   - User outcome: what does success LOOK like to the user?
   - Symptom or metric: a specific page, error code, latency number, support ticket?
   - Audience: all users / specific role / specific tenant / internal-only?
   - Priority + deadline: what blocks this from waiting until next sprint?
   - Constraints: anything off-limits (libraries, schema, copy)?
3. Identify scope boundaries: what's IN, what's explicitly OUT.
4. If the brief reveals an unanswerable question (depends on a stakeholder decision), surface it as an open question and don't proceed to the spec.

## Phase 2 — Organize (decompose the work)

- Decide whether the expanded spec is a bug, feature, refactor, spike, or ops task. Different downstream commands.
- Sketch the suggested flow (which slash command should run next; which agents).
- Decide if a doc artifact is wanted (`specs/<YYYYMMDD>-<slug>.md`) or inline-only.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

TASK-SPECIFIC:
- Read related code + `ai/` docs to ground the expansion in reality. If the brief mentions a feature, run a quick `/find-module` mentally.
- `ai/modules.md` to identify candidate affected modules.
- Recent `ai/dynamic/changelog.md` entries — has someone already started this?

## Phase 4 — Generate (produce the output)

Produce the full task prompt in this shape:

```markdown
## Task: <expanded title>

### Goal
<one-sentence outcome>

### Context
<why now, grounded in code or business signal — no padding>

### Acceptance criteria
- Given <X>, when <Y>, then <Z>
- ...

### Scope (in)
- <concrete items>

### Scope (out)
- <explicit non-goals — anti-scope-creep>

### Edge cases
- <case> → <expected behavior>

### Affected modules
- <path or name>
- ...

### Estimated complexity
- S / M / L  — <one-line reason>

### Suggested flow
1. /analyze-module orders
2. /add-feature with the spec above
3. /pre-commit before opening PR
```

End with ONE suggested next command — the most likely tool for this task (`/add-feature`, `/fix-bug`, `/analyze-task`, `/design-system`).

## Phase 5 — Update (persist changes to the knowledge base)

- Save to `specs/<YYYYMMDD>-<slug>.md` if the user asks for a doc; otherwise return inline.
- If a stakeholder open-question was surfaced → append to `ai/dynamic/decisions-pending.md`.
- No `ai/status.md` entry yet (this is pre-work; wait for execution).

## Phase 6 — Validate (verify correctness)

- Acceptance criteria are Given/When/Then (testable, not vague).
- Scope (out) is non-empty if the area is broad — anti-scope-creep enforced.
- Affected modules grounded in actual paths (no fabricated module names).
- Suggested next command is exactly ONE — multiple = ambiguity at handoff.

## Phase 7 — Improve (feed the learning loop)

- If the user heavily edited the produced spec → run `/learn-from-task` and capture what was missing (extra acceptance criterion, missed edge case) → append to `ai/dynamic/feedback-learned.md`.
- If a recurring brief shape emerges (e.g., "make X faster" always becomes a perf-audit-then-fix flow) → after 3 occurrences, queue to `ai/dynamic/learned-patterns.md` as a possible expansion template.

## Output

```
Saved: specs/20260424-orders-performance.md

Task: Reduce GET /orders p95 latency below 200ms

Goal: List endpoint p95 < 200ms at current traffic levels.

Context: APM shows p95 = 820ms; correlates with order count growth (~5M rows).
N+1 in items hydration confirmed via /perf-audit on 2026-04-23.

Acceptance criteria:
  - Given a tenant with 1k orders, when calling GET /orders, then p95 < 200ms locally.
  - Given the same tenant, when running /perf-audit, then no N+1 reported.

Scope (in):
  - orders.repository.ts query rewrite
  - composite index migration on (tenant_id, created_at DESC)

Scope (out):
  - Caching (handled separately if perf still insufficient after fix)
  - UI changes

Edge cases:
  - Tenant with 0 orders — must return [] not 404.
  - Filter combinations — verify each still uses the new index.

Affected modules: src/modules/orders

Complexity: M  (migration + repo rewrite + perf re-test)

Next: /add-feature with the spec above.
```

## Failure modes

- Brief is too vague after one clarification round → say so and stop. Guessing produces wrong code.
- User insists on no clarification round on a vague brief → produce the spec but mark it `LOW_CONFIDENCE` at the top with explicit assumptions called out.
- Stakeholder decision needed → don't proceed to spec; surface the open question.
- Brief contradicts existing roadmap (`ai/status.md` says we're in Phase 1, brief is Phase 3 work) → flag the scope creep before producing the spec.

## Gotchas

- Never fabricate context. If the brief is too vague after one clarification round, say so and stop — guessing produces wrong code.
- Keep the expansion focused. Don't pad with platitudes ("ensure best practices") — those are noise.
- Acceptance criteria as Given/When/Then forces concrete tests later. Vague criteria = vague tests = missed bugs.
- Out-of-scope is as important as in-scope. Anti-scope-creep prevents the implementer from building "nice to haves" not asked for.
- Suggested next command is always ONE. Multiple suggestions = ambiguity at handoff.

## Hard rules

- **One clarification round, then commit or stop.** Multiple rounds = the brief was too vague to start. Send it back.
- **Every acceptance criterion is testable.** Vague AC ("works well") rejected; restate as Given/When/Then.
- **Out-of-scope explicit, not implicit.** Without explicit anti-scope, implementers build what wasn't asked for.
- **Cite the brief.** Every claim in the spec ties back to a sentence in the original brief OR a clarification answer. No invented requirements.
- **Stakeholder-decision items flagged, not invented.** "Should this support X?" → ask, don't guess.
- **Roadmap-aware.** Brief that contradicts `ai/status.md` declared phase = halt + surface scope-creep concern.
- **Suggested next command = ONE.** Multiple = ambiguity at handoff = wrong thing built.
- **No PII in the spec.** If the brief mentions specific user data, redact in the published spec.

## Related

### Sibling commands in business pack
- `/analyze-task` — sibling command in business pack
- `/audit-business` — sibling command in business pack
