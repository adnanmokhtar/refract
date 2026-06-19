---
description: Turn a one-line task into a full implementer-ready prompt with context, acceptance criteria, scope, and next-step command.
---

# /expand-task "<brief>"

Most "fix login bug" / "make orders faster" tickets are one line. This produces a structured prompt an implementer (or `/add-feature` / `/fix-bug`) can execute.

## Phases applied

1, 2, 3, 4, 5, 7. Phase 6 (Validate) is light — this command produces a spec, not code; validation = "user confirms spec is right".

## When to use / NOT to use

- USE: owner / stakeholder dropped a one-liner in chat.
- USE: before opening a real ticket / starting work.
- USE: ahead of `/add-feature`, `/fix-bug`. For a larger idea that needs a full spec, use `/analyze-task` instead (sibling entry point, not a later step).
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

End with ONE suggested next command — the most likely tool for this task (`/add-feature`, `/fix-bug`, `/analyze-task`, `/enhance-ui`). If the spec was saved to `specs/`, cite the path (`Next: /add-feature specs/<YYYYMMDD>-<slug>.md`); if inline, `Next: /add-feature with the spec above`.

## Phase 5 — Update (persist changes to the knowledge base)

- Save to `specs/<YYYYMMDD>-<slug>.md` if the user asks for a doc — stamp a `Spec-ID: <slug>-<4char-hash>` header so `/add-feature specs/<file>` can consume + backreference it; otherwise return inline.
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
Saved: specs/20260424-orders-performance.md   [Spec-ID: orders-performance-7f4a]

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

Next: /add-feature specs/20260424-orders-performance.md
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
