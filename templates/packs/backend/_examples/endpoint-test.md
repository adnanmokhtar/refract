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

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves.** This command pokes a live dev server and reports what the wire actually does. The whole value is empirical: status codes, response shapes, headers — observed, not assumed. A response shape claimed without the actual JSON is a hypothesis dressed as a finding. A "200 OK" claimed without the actual status line is a fabrication.

**This command does NOT:** run curl inline (it always delegates), report "the endpoint returns the expected shape" without quoting the body, or accept a run in which a mandatory case was skipped to save time.

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

## Phase 6 — Validate (the hand-wave halt, then routing)

**Mechanical gate, all tiers.** Before printing anything, grep the returned report for hand-wave tokens: `etc.`, `...` used as "and similar", `usual fields`, `expected shape` (without the literal shape quoted), `looks correct` (without the literal body quoted), `among others`, `several headers`, `various status codes`.

Any hit outside a quoted curl output **halts the report**. The finding is replaced with the literal observed value — quoted JSON body, listed header keys, exact status line — or dropped. Paraphrase is forbidden; the wire is the truth.

Then route by what came back:

| Observation | Route |
|---|---|
| Cross-tenant case returned `2xx` | **CRITICAL leak.** Halt, surface as a blocker, route to `/security-audit`. Never downgraded to "dev mode". |
| Idempotency replay created a fresh resource | Idempotency broken → `/fix-bug`. |
| `500` with no body | `/log-tail correlation:<id>` to capture context, then `/fix-bug`. |
| Status green but the body diverges from the DTO | Phantom success → `/fix-bug`. A `200` is not a pass. |
| Edits not reflected in responses | Stale dev server → restart and re-run. A phantom pass is not a pass. |

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
