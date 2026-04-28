---
description: Hit a dev endpoint with curl and verify status + response shape via the endpoint-tester agent.
---

# /endpoint-test [controller|method-path]

Diagnostic / read-only verification that a controller actually works end-to-end. Phases 1, 3, 6 dominate; 4 (Generate) produces only test calls; 5, 7 N/A.

## When to use / NOT to use
- USE: after editing a controller, DTO, guard, pipe, or adding a new route.
- USE: when a frontend reports an unexpected response shape and you need ground truth.
- NOT: when no dev server is running — start it first; this command refuses auto-start (side effects).
- NOT: against staging or prod hosts. Localhost / explicit dev tunnel only.

## Phase 1 — Understand
- Resolve target arg:
  - `<controller-name>` → list all routes from that controller, ask which one.
  - `METHOD /path` (e.g. `POST /users`) → use directly.
  - No arg → read recent `git diff` for changed controllers; ask if multiple match.
- Confirm severity / scope: single endpoint vs full controller sweep.

## Phase 2 — Organize
- Decide call set: golden path / invalid body / no auth / wrong tenant / idempotency replay (5-call canonical flow).
- Decide who runs the calls: this command always delegates to `endpoint-tester` agent — no inline curl chains in the orchestrator.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Endpoint-specific:
- The controller file — route decorators, guards, pipes.
- Input DTO — required fields, validation rules.
- Output DTO — expected response shape.
- The dev port from `CLAUDE.md` (must be reachable; if not, stop and ask user to start the dev script).

## Phase 4 — Generate (run the verification)
- Dispatch `endpoint-tester` with the resolved spec (method, path, headers, minimal valid body, expected response).
- Agent runs the 5-call canonical flow and prints a results table + curl replay block.
- No code is written — output is observation only.

## Phase 5 — Update — N/A
Read-only. No state changes, no knowledge persistence.

## Phase 6 — Validate (interpret results)
- Tenant-isolation case (call 4) returning 200 → CRITICAL leak; surface as blocker, route to `/security-audit`.
- Idempotency replay returning a fresh resource → idempotency broken; route to `/fix-bug`.
- Stale dev server (edits not picked up) → restart and re-run; phantom passes are not passes.

## Phase 7 — Improve — N/A
Diagnostic. No learning queued — discoveries get filed by the follow-up `/fix-bug` or `/security-audit` if invoked.

## Output format
```
## /endpoint-test — <method> <path> — <PASS | FAIL | LEAK>

Phase 1 (Understand): <route resolved>
Phase 3 (Retrieved): controller, DTOs, dev port from CLAUDE.md
Phase 4 (Generated): 5 curl calls dispatched via endpoint-tester
Phase 6 (Validated): <pass/fail per case + verdict>

Status: COMPLETE | BLOCKED on <X>

Open follow-ups:
  - <e.g. "tenant leak — invoke /security-audit">
```

## Failure modes
- Targets non-localhost host without explicit dev-tunnel approval → refuse.
- `PROD_*` credentials in env → refuse; source from `.env.dev` / `.env.example` only.
- Dev server stale (HMR didn't pick up controller change) → restart server, re-run.
- Tenant-isolation leak silently passing → agent must flag as CRITICAL even if status is 200.
- Logs suggest 500 with no body → invoke `/log-tail correlation:<id>` to capture context.

## Related

### Sibling commands in backend pack
- `/add-endpoint` — sibling command in backend pack
- `/add-feature` — sibling command in backend pack
- `/add-module` — sibling command in backend pack
- `/analyze-module` — sibling command in backend pack
- `/fix-bug` — sibling command in backend pack
- `/log-tail` — sibling command in backend pack
- `/trace-flow` — sibling command in backend pack

### Patterns
- `ai/patterns/api-contract.md`
- `ai/patterns/api-versioning.md`
- `ai/patterns/caching-strategy.md`
- `ai/patterns/error-handling.md`
- `ai/patterns/parallel-io.md`

### Rules
- `.claude/rules/backend-principles.md`
- `.claude/rules/concurrency-discipline.md`
