---
description: Tail structured dev logs filtered by level, correlation id, or module.
---

# /log-tail [filter]

Diagnostic / read-only command. Streams JSON logs from the dev server with `jq` filtering. Phases 1, 3 dominate; 4 produces a live stream; 5-7 N/A.

## The Premise (read this first, internalize, do not deviate)

**Pattern almost always repeats.** The reason a developer runs `/log-tail` is that something looks broken once — but in production-style systems, "once" is almost never the truth. A 500 on an endpoint is rarely the only 500; a tenant whose request leaked is rarely the only tenant; a slow query is rarely a singleton. Stopping at the first matching line is the failure mode that ships a "fix" for the surface symptom while N more instances continue silently. The tail's value is in the cluster, not the spike.

**The agent's job is exactly this:**
1. Run the filter and stream until the user SIGINTs (or the one-shot window completes).
2. **Read the entire captured window**, not just the first match. Group lines by signature (error class + module + verb).
3. Surface every cluster — `5 instances of TenantContextMissingError in OrdersController over 12 minutes` — not just the most recent one.

**The agent does NOT:**
- Report the first matching line and stop. **Read the full window.**
- Collapse N occurrences into one line without surfacing the count. **Counts matter.**
- Drop a cluster because it "looks like the same bug." **Same bug at 47 occurrences vs 1 changes the priority by two tiers.**
- Treat a clean tail as proof of fix without running long enough to catch the cluster cadence. **Five minutes is not a window.**

**The agent ONLY escalates to the user when:**
- The user names a prod aggregator (Loki / CloudWatch / Datadog) — refuse, dev only.
- Logs are plaintext with no structure — propose `/add-telemetry` and stop.
- Correlation field name cannot be auto-detected after probing common keys — ask the user.

## Cluster halt (mechanical gate, all tiers)

**Before declaring the tail complete, scan the captured window for repeat signatures.** A signature = `(error class | log level + module | verb)` extracted from each line.

Halt rule: if any signature has count > 1 in the captured window, the agent MUST surface every instance of that signature, not just the first. Output format:

```
Cluster: TenantContextMissingError @ OrdersController.list
  Count: 5
  First: 2026-04-30T10:14:02Z
  Last:  2026-04-30T10:26:48Z
  Correlation ids: cor_abc, cor_def, cor_ghi, cor_jkl, cor_mno
  Sample line: { "level": "error", "msg": "...", ... }
```

Forbidden:
- Reporting only the first or last match when count > 1.
- Saying "and similar errors followed" — enumerate every correlation id.
- Collapsing a 47-instance cluster into "saw it a few times."

If the captured window has zero clusters (every line is unique), say so explicitly — silence on cluster status is itself a hand-wave.

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
