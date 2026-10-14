---
description: "Runtime lane of /ds-audit: stuck sagas, DLQ depth, compensation gaps, unknown event versions on named live sources."
kind: command
pack: distributed-systems
allowed-tools: [Read, Write, Grep, Glob, Bash, Task]
---

# /audit-distributed-tx --live=<source=target,…>

**Runtime only: stuck instances, DLQ depth, compensation gaps and drift, read from live sources you name. Code defects — ack order, missing reserves, dual writes, retries, locks, workflow determinism, contracts — are `/ds-audit`.** This command is the procedure `/ds-audit --runtime` runs; it keeps its name for existing users. It counts what the running system shows, and it never reads code for a defect class, so a clean run here says nothing about the code.

## Premise

A runtime count is evidence of a defect, not the defect. Two confirmation emails for one order prove a duplicate happened; the cause — a reserve keyed on a delivery handle, a check-then-act dedupe, a redelivery after a stall — is a code row that `/ds-audit` finds and `/ds-fix` closes. This command reads the live state **read-only**, from targets the user named, and hands each count to the agent or detector that explains it.

- **Named targets only.** Every source comes from `--live` (`redis=<url>`, `rabbitmq=<mgmt-url>`, `kafka=<bootstrap>`, `sqs=<profile>@<region>`, `nats=<url>`, `temporal=<address>`, `db=<read-only DSN>`), with credentials from the user's environment. A source not named prints `NO-DATA(<source>)` for every row that needs it.
- **No default context, no default profile.** The first line of every Bash block that may run a cluster or cloud tool is `SCAN=$(mktemp -d "${TMPDIR:-/tmp}/dtx.XXXXXX"); export KUBECONFIG="$SCAN/empty-kubeconfig"; : > "$KUBECONFIG"` — an empty scratch kubeconfig, so no tool can reach a default context. A cloud CLI runs only with the profile `--live` named (`--profile <profile> --region <region>`), and the run first prints `aws sts get-caller-identity --profile <profile>` so the account is on the record. An unset or unnamed profile halts that source, never falls back.
- **Read-only.** No send, receive-and-delete, purge, ack, redrive, `XCLAIM`, compensation run or workflow signal. Replaying dead letters is the `dlq-replay` skill, run after the fix ships.

## Phases applied

1, 2, 3, 4, 6 (skips Update/Improve — read-only count + routing).

## When to use

- After an incident that touched a distributed flow: how many instances, messages and effects it left behind.
- When a DLQ or a failed set grows unexpectedly.
- On a schedule for high-throughput event-driven systems, beside a periodic `/ds-audit` of the code.
- NOT: "is this consumer idempotent", "does this relay lose events", "is this workflow deterministic" → `/ds-audit`.

## Phase 1 — Understand

- The flows in scope and their declared stuck thresholds (some legitimately wait days on a human).
- The saga runtime: a durable engine (Temporal, Step Functions, Durable Functions, Inngest, Restate), a custom orchestrator with a saga-state table, or choreography.
- The broker and each source's `--live` target. A source with no target is `NO-DATA(<source>)` from here on.

## Phase 2 — Organize

Five counts:

1. **Stuck instances** — running longer than the flow's threshold, grouped by the step they wait on.
2. **DLQ depth** — per handler or queue: depth, oldest age, trend; for BullMQ the failed set.
3. **Compensation gaps** — failed instances whose completed steps were not all compensated.
4. **Duplicate-effect signals** — one business id with two effects (two emails, two refunds, two stock moves).
5. **Unknown event versions** — events whose version no handler declares.

## Phase 2.5 — Hand each count to its owner

A count is routed, never diagnosed here.

- **Stuck instances (1)** — dispatch `@workflow-orchestrator` on any flow whose stuck instances share a step, with the stuck-instance table. It separates "waiting on a human" from "stranded by a deploy" and names the `workflow-scan` § to run.
- **Compensation gaps (3)** and **duplicate effects (4)** — each names the code question for `/ds-audit`: `workflow-scan` § 4–§ 6 for a gap, `messaging-scan` § 2 / `dual-write-scan` § 4 for a duplicate. Money, stock or credit duplicates are security `logic-race-scan` § 4 when that pack is installed.
- **Unknown event versions (5)** — dispatch `@event-sourcing-architect` with the drift table; it decides upcaster, handler fix or producer rollback, and names `event-contract-scan` § 1 for the contract gate.

Skip a dispatch when its count is zero or `NO-DATA` — an agent run against an empty table produces a confident report about nothing.

## Phase 3 — Retrieve (read-only; each command only on a `--live` target)

```bash
SCAN=$(mktemp -d "${TMPDIR:-/tmp}/dtx.XXXXXX"); export KUBECONFIG="$SCAN/empty-kubeconfig"; : > "$KUBECONFIG"   # first line, always
# Kafka — lag, members, churn per group
kafka-consumer-groups.sh --bootstrap-server "$KAFKA" --describe --group "$GROUP"
# RabbitMQ — unacked, consumers, DLX and delivery-limit arguments, queue type
rabbitmqctl list_queues name type messages_unacknowledged consumers arguments
# SQS — depth, oldest age, redrive policy, retention of the source and of the DLQ
aws sts get-caller-identity --profile "$PROFILE"
aws sqs get-queue-attributes --profile "$PROFILE" --region "$REGION" --queue-url "$DLQ_URL" --attribute-names All
# NATS JetStream — AckPolicy, MaxDeliver, redelivered count
nats consumer info "$STREAM" "$CONSUMER"
# Redis Streams — pending entries and their idle time
redis-cli -u "$REDIS" XPENDING "$STREAM" "$GROUP"
redis-cli -u "$REDIS" XINFO GROUPS "$STREAM"
# Temporal — one execution's history (flag form unverified: research catalog 2026-10-14)
temporal workflow show -w "$WORKFLOW_ID" --output json
```

- **BullMQ:** the failed and waiting counts from a read-only script using `queue.getJobCounts('failed', 'waiting', 'delayed')` against the named Redis, never from the app's own process.
- **Durable engine stuck list:** the engine's own list or visibility query over running executions older than the threshold. Temporal's list-query form is not verified in the research catalog; name it `[K?]` and print the command run.
- **Custom orchestrator:** a read-only query over the saga-state table, through the `db=` DSN.
- **Choreography:** stuck flows are visible only through traces or the saga-state ledger; with neither, the count is `NO-DATA(choreography: no ledger)`.
- **Declared flows:** `ai/patterns/saga-*.md` and `ai/patterns/event-handlers.md` *(project signal)*.

## Phase 4 — Generate

The block below is an **EXAMPLE** of the shape. Its placeholders are not data: every value in a real report comes from a command in Phase 3, with its source.

```
## Runtime lane — <date>   sources: kafka=<bootstrap> · sqs=<profile>@<region> · temporal=NO-DATA(temporal)

### Stuck instances                                   source: <command run>
| Flow | Instance | Stuck since | Waiting on | Threshold | → |
|---|---|---|---|---|---|
| <flow> | <instance id> | <duration> | <step> | <declared threshold> | @workflow-orchestrator |

### DLQ depth                                         source: <command run>
| Handler / queue | Depth | Oldest | Trend | → |
|---|---|---|---|---|
| <name> | <n> | <age> | <growing / stable / new> | /ds-audit messaging-scan §3 |

### Compensation gaps                                 source: <saga-state query>
| Instance | Failed at | Compensated | Missing | → |
|---|---|---|---|---|
| <instance id> | <step> | <steps> | <step> | /ds-audit workflow-scan §4–§6 |

### Duplicate-effect signals                          source: <query>
| Handler | Business id | Effect count | → |
|---|---|---|---|
| <handler> | <id> | <n> | /ds-audit messaging-scan §2 · dual-write-scan §4 |

### Unknown event versions                            source: <query>
| Topic / type | Version | Count (24 h) | → |
|---|---|---|---|
| <type> | <version> | <n> | @event-sourcing-architect |

### DLQ replay
not run (dlq-replay is a write lane)  |  not run (dlq-replay absent)
```

## Phase 6 — Validate

After the recovery actions and the code fixes `/ds-fix` closed:
- Re-run this lane on the same targets; each count moves the way the fix predicts, and the report prints both runs.
- A drained DLQ is checked with `dlq-replay`'s own Verify block (depth before and after, duplicates by business id, out-of-order count), never assumed.

## Output format

```
## /audit-distributed-tx complete (runtime lane)

Sources: <name=target | NO-DATA(<source>)>, one per line
Stuck instances: <count | NO-DATA>
DLQ depth: <sum | NO-DATA>
Compensation gaps: <count | NO-DATA>
Duplicate-effect signals: <count | NO-DATA>
Unknown event versions: <count | NO-DATA>
DLQ replay: not run (<reason>)

Verdict: GREEN / YELLOW / RED / NO-DATA     (runtime only — the code verdict is /ds-audit's)

Report: ai/audits/<YYYY-MM-DD>-distributed-runtime.md   (under /ds-audit --runtime: its own block in that report)
```

## Hard rules

- **Write is for the report path only** — `ai/audits/<YYYY-MM-DD>-distributed-runtime.md`. Nothing else in the tree, no broker, no engine, no database is written.
- **A missing `dlq-replay` never halts this command.** DLQ rows print `not run (dlq-replay absent)`; the counts still print.
- **Stuck thresholds are declared per flow.** Some legitimately wait days (manual approval); others should never pass an hour. No threshold → the flow's rows print `threshold undeclared`, never a verdict.
- **Every count cites its source** — the `--live` target and the command run. No source, `NO-DATA(<source>)`; never an estimate.
- **Manual compensation runs are documented in `ai/runbooks/saga-recovery.md`** and are run by a person, not by this command.
- **A design-level duplicate opens an ADR** after `/ds-audit` names the cause.

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the counts re-expressed as ONE ordered, numbered to-do — **MUST FIX** (duplicate effects, compensation gaps) → **SHOULD FIX** (growing DLQs, stuck instances past threshold) → **OPTIONAL** — each step carrying the flow, the count and its source + **Fix** (the `/ds-audit` detector § that finds the cause, then `/ds-fix`) + **Verify** (this lane re-run on the same targets, and the oracle `/ds-fix` names). Then the closing steps: `/ds-audit` on the code, `/ds-fix`, `dlq-replay` after the fix ships, re-run this lane, `/learn-from-task`. A clean run collapses to a single line ("No runtime anomalies on <sources> — code not audited here; run /ds-audit"). Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Reporting a runtime count as a code finding — the count is evidence; the cause is a `/ds-audit` row.
- Counting "stuck" instances that legitimately wait (manual approval) — the declared threshold decides.
- Draining a DLQ before the fix ships → the messages fail again and repopulate it.
- Reading with the default cloud profile or kube context → the wrong account, or a production cluster nobody named.
- Manual compensation run for the wrong instance id → an incorrect refund.

## Related

- `/ds-audit` — the code audit; `--runtime` runs this procedure as its runtime lane.
- `/ds-fix` — closes the code findings the counts point to.
- `dlq-replay` skill — the write lane that drains a DLQ once the cause is fixed.
- `add-saga`, `add-event-handler` commands — build the flows these counts watch.
- `@workflow-orchestrator` — dispatched on stuck instances that share a step.
- `@event-sourcing-architect` — dispatched on unknown event versions.
