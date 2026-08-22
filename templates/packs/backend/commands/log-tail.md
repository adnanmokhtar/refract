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
- Logs are plaintext with no structure — propose `/add-telemetry` *(observability pack, when co-installed; otherwise propose adopting the project's logger's structured mode directly)* and stop. A redirect must land somewhere.
- Correlation field name cannot be auto-detected after probing common keys — ask the user.
- `.level` is numeric and the logger's scale direction cannot be established — ask, do not guess (see Phase 2).

## Closure verbs (complexity → ceremony)

Default to the lightest tier that fits. Heavy ceremony is opt-in, not default.

| Tier | Triggers | Window | Output |
|---|---|---|---|
| **Trivial** (default) | One filter, short investigation, single-shot window. | Stream until SIGINT or `head -n 200`. | Line dump + cluster summary at exit (count per error signature, first/last ts). |
| **Standard** | Multi-filter compound (correlation + tenant + module), or post-incident reconstruction. | Bounded window (e.g., last 30min via `--since`). | Cluster summary + per-cluster representative line + cross-cluster correlation hint. |
| **Heavy** | Suspected cross-tenant leak OR active production-style incident replay in dev. | Full window with replay capture saved to `ai/dynamic/incident-<iso>.log`. | Cluster report + handoff package for `/fix-bug` (cluster signatures, file:line refs, correlation ids). |

**Default is trivial.** Most invocations are "what just broke" — single filter, short window, surface clusters. Heavy is opt-in for incident reconstruction.

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

**A zero-row window does not reach this gate.** Before reporting `Cluster size: 0`, the no-match ladder below must have run and produced a rung — a confident "nothing in the logs" on top of a filter that could never have matched is the worst output this command can produce.

## Reporting halts (all tiers)

- Halt on hand-waves: every finding quotes the actual log line + its timestamp + the correlation id used to filter.
- Halt if a "nothing found" verdict is returned without showing the exact `jq` (or `grep`) filter executed **and** the no-match ladder rung it resolved to.
- Halt if PII (phone, email, token, card fragment) appears in the report unredacted — sanitize before surfacing; a raw secret in a report is a leak, not a finding.
- Halt if this command was pointed at production logs — refuse and redirect to the central aggregator.

## No-match ladder (mechanical gate — runs whenever the filter returns zero rows)

The cluster halt demands a definite verdict, and the most common real outcome is that the filter matched nothing. **"Nothing found" is not a verdict; it is four different findings wearing the same face.** Walk the rungs in order and stop at the first that fires — the answer is the rung, not the silence.

| # | Check | If it fires | Verdict / next move |
|---|---|---|---|
| 1 | Does the window contain **any** lines at all (`tail -n 50 <source> \| wc -l`)? | Zero lines | Wrong source, or the process buffers stdout and nothing was ever written to the file. A foreground dev server needs `… \| tee logs/app.log`; a container needs `docker compose logs`, not the file. **Not a code finding — re-run against the right source.** |
| 2 | Do lines exist but the **predicate** matched none? Re-run the raw tail without the filter. | Lines present, filter empty | The predicate is wrong before the code is. Re-probe the level encoding (Phase 2) and the correlation field name (Phase 3); a numeric-level logger never matches a string-label predicate and vice-versa. Fix the filter and re-run before concluding anything. |
| 3 | Is the **correlation id absent from every line** in the window, including `info` lines? | Absent everywhere | The request never reached the code that logs. Check middleware / guard ordering and where the id is minted: an id generated *after* auth means a rejected request produces no id at all. Look for the edge-layer record instead (access log, reverse proxy, `4xx` counter). **Route to `/trace-flow <endpoint>` to find the first hop that should have logged.** |
| 4 | Is the id **present but the chain stops mid-flow** (entry logged, no exit, no error)? | Truncated chain | Something swallowed it. Name the last hop that logged, then read the next call site's `catch` / `except` / `if err != nil` — a bare catch that logs at `debug` or not at all is the usual answer. **Route to `/fix-bug` with the last-hop `file:line`.** |

Rung 3 and rung 4 are findings and get reported as such. Rungs 1 and 2 are operator errors in the tail itself — fix and re-run; reporting them as "nothing in the logs" is the false negative this ladder exists to prevent.

## When to use / NOT to use
- USE: endpoint returned 500 and you need context.
- USE: tracing a single request across modules via correlation id.
- USE: filtering one tenant's traffic during a multi-tenant bug investigation.
- NOT: against prod log aggregators (Loki / CloudWatch / Datadog) — too easy to misuse; dev only.
- NOT: as a substitute for proper structured logging if format is plaintext — propose `/add-telemetry` instead.

## Filters
- `error` — error and above, per the level encoding resolved in Phase 2 (never a hardcoded predicate).
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
- **Detect the level encoding — never assume it.** `level` is not a string in every logger, and a predicate built for the wrong encoding matches zero rows forever while looking correct. Probe first:

  ```bash
  tail -n 50 <source> | jq -r '.level | type' | sort -u
  ```

  | Probe returns | Predicate | Why |
  |---|---|---|
  | `number` | `select(.level >= 50)` (add `>= 40` to include warn) | Pino's numeric scale — `trace=10, debug=20, info=30, warn=40, error=50, fatal=60`. A string-set predicate matches none of these. |
  | `string` | `select((.level \| ascii_downcase) as $l \| $l == "error" or $l == "fatal" or $l == "warn")` | Label-formatted loggers. Downcase because some JSON handlers emit the label uppercase (`"level":"INFO"`). |
  | `number`, non-Pino logger | **Establish the scale direction from that logger's own docs before filtering.** Numeric scales are not all ascending; on a descending scale `>= 50` selects everything *except* errors. If the direction cannot be established, escalate — do not guess. |
  | more than one type | Two log sources are interleaved in this file. Separate them before filtering; a mixed-encoding predicate silently drops one of them. |
  | `null` / field absent | The level lives under another key (`severity`, `levelname`, `lvl`). Probe `keys` on one line before building anything. |

- Build the filter command for the detected source × format × level-encoding combo.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Log-source-specific:
- `CLAUDE.md` log path / process name / container name.
- One sample log line — `tail -n1 | jq .` to detect format.
- Correlation field name (`correlationId`, `request_id`, `traceId`, `x-correlation-id` — varies per logger).

## Phase 4 — Generate (the stream)

**The filter mechanism is OWNED by the `log-tail` skill — this command dispatches it, it does not re-implement it.** Same split as `/add-module` → `module-scaffold`: the command owns the gates (cluster halt, no-match ladder, reporting halts) and the skill owns the `jq` recipes, the source-tail invocations, and the logger-specific gotchas. Two copies of a filter predicate is exactly how this command shipped a level filter its own skill's documented logger could never match.

Dispatch [`templates/packs/backend/skills/log-tail/SKILL.md`](../skills/log-tail/SKILL.md) with the resolved inputs: **source** (file / container / process), **format** (json / plaintext), **level predicate** (from the Phase-2 probe — pass the predicate, not the word "errors"), **correlation / tenant field names** (from Phase 3), and the window bound.

Then:
- Stream until SIGINT (or the one-shot window completes). On exit, print line count + first/last timestamp.
- **Zero rows → run the no-match ladder before reporting anything.**
- ≥1 row → group by signature and run the cluster halt.

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
- **Level predicate built for the wrong encoding** → matches zero rows forever and the cluster halt then reports a confident `Cluster size: 0`. Probe `type(.level)` in Phase 2; never hardcode.
- Log timestamps are UTC while the terminal is local — convert before correlating with a user-reported time, or the window looks empty.
- PII (phone, email, token) in log lines → redact before the line reaches the report.
- Targeting prod aggregator → refuse.
- Embedded newlines in JSON stack traces break `grep` → always use `jq` when format is JSON.
- `tail -f` (lowercase) doesn't follow rotations → always use `-F`.
- Correlation field name mismatch → try `correlationId | request_id | traceId`; ask user if all miss.
- High-volume output overwhelms terminal → pipe through `head -n 200` for one-shot, `less +F` for paged following.
- Plaintext logs with no structure → propose `/add-telemetry` to switch the project to structured logging.

## Related

### Sibling commands — where the boundary falls
- `/trace-flow` — the static counterpart: it reads the path a request *would* take; this one reads what the running process actually emitted. Use both when they disagree.
- `/endpoint-test` — pairs with this command on a `500` with no body: that one reproduces the call, this one recovers the context behind it.
- `/fix-bug` — where every confirmed signal goes. This command produces evidence and correlation ids, never a fix.

### Patterns
- `ai/patterns/error-handling.md` — the log/error-code correlation this command reads back out of the stream.

The other pack patterns are not read on this axis and are deliberately not listed.

### Rules
- `.claude/rules/backend-principles.md`
- `.claude/rules/concurrency-discipline.md`
