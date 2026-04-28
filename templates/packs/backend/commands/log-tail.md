---
description: Tail structured dev logs filtered by level, correlation id, or module.
---

# /log-tail [filter]

Diagnostic / read-only command. Streams JSON logs from the dev server with `jq` filtering. Phases 1, 3 dominate; 4 produces a live stream; 5-7 N/A.

## When to use / NOT to use
- USE: endpoint returned 500 and you need context.
- USE: tracing a single request across modules via correlation id.
- USE: filtering one tenant's traffic during a multi-tenant bug investigation.
- NOT: against prod log aggregators (Loki / CloudWatch / Datadog) — too easy to misuse; dev only.
- NOT: as a substitute for proper structured logging if format is plaintext — propose `/add-telemetry` instead.

## Filters
- `error` — level >= error.
- `correlation:<id>` — single request trace.
- `module:<name>` — logger source = name.
- `tenant:<id>` — single tenant's traffic.
- (no arg) — all logs.

## Phase 1 — Understand
- Parse filter arg (one of the above).
- Confirm scope: dev server only — refuse if user names a prod aggregator.

## Phase 2 — Organize
- Detect log source: file path / running process / Docker container.
- Detect log format: JSON vs plaintext.
- Build the right filter command for the detected source × format combo.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Log-source-specific:
- `CLAUDE.md` log path / process name / container name.
- One sample log line — `tail -n1 | jq .` to detect format.
- Correlation field name (`correlationId`, `request_id`, `traceId`, `x-correlation-id` — varies per logger).

## Phase 4 — Generate (the stream)
- JSON + level filter:
  ```bash
  tail -F logs/app.log | jq 'select(.level | IN("error","fatal","warn"))'
  ```
- JSON + correlation:
  ```bash
  tail -F logs/app.log | jq --arg id "$ID" 'select(.correlationId == $id or .request_id == $id)'
  ```
- JSON + tenant:
  ```bash
  tail -F logs/app.log | jq --arg t "$TENANT" 'select(.tenantId == $t or .tenant_id == $t)'
  ```
- Plaintext: `tail -F logs/app.log | grep -E "<pattern>"`.
- Stream until SIGINT. On exit, print line count + first/last timestamp.

## Phase 5-7 — N/A

Read-only diagnostic. No state changes, no knowledge persistence, no learning hook needed. If the tail surfaces a real bug, hand off to `/fix-bug`.

## Output format
```
## /log-tail — <filter> — <duration>

Phase 1 (Understand): filter = <arg>
Phase 3 (Retrieved): source = <file|process|container>; format = <json|plain>
Phase 4 (Streamed): <N lines from <ts> to <ts>>

Status: COMPLETE | HANDED OFF to /fix-bug

Open follow-ups:
  - <e.g. "500 with stack trace at OrdersController:42 — invoke /fix-bug">
```

## Failure modes
- Targeting prod aggregator → refuse.
- Embedded newlines in JSON stack traces break `grep` → always use `jq` when format is JSON.
- `tail -f` (lowercase) doesn't follow rotations → always use `-F`.
- Correlation field name mismatch → try `correlationId | request_id | traceId`; ask user if all miss.
- High-volume output overwhelms terminal → pipe through `head -n 200` for one-shot, `less +F` for paged following.
- Plaintext logs with no structure → propose `/add-telemetry` to switch the project to structured logging.

## Related

### Sibling commands in backend pack
- `/add-endpoint` — sibling command in backend pack
- `/add-feature` — sibling command in backend pack
- `/add-module` — sibling command in backend pack
- `/analyze-module` — sibling command in backend pack
- `/endpoint-test` — sibling command in backend pack
- `/fix-bug` — sibling command in backend pack
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
