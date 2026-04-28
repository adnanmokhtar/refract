---
description: Audit distributed transactions / sagas / event flows for stuck instances, missing compensations, dropped events, idempotency violations. Reports per-flow with verdict + recovery action.
---

# /audit-distributed-tx

Distributed transactions go wrong silently. Sagas stuck waiting on missing events; events arrive twice and process twice; compensations skipped because of an early-return. This command finds them.

## Phases applied

1, 2, 3, 4, 6 (skips Update/Improve — read-only audit + recovery proposals).

## When to use

- Weekly minimum for high-throughput event-driven systems.
- After a release touching saga / event handler code.
- After incidents that touched distributed flow.
- Pre-incident: when DLQ is growing unexpectedly.

## Phase 1 — Understand

- Flows in scope: orders / signups / billing / shipping / etc.
- Saga implementation: Temporal / Step Functions / custom orchestrator / choreography-only.
- Event broker: Kafka / SQS / EventBridge / RabbitMQ / Cloud Pub/Sub.

## Phase 2 — Organize

Five concerns audited:

1. **Stuck sagas / workflows** — stuck > N hours waiting on event / activity.
2. **DLQ depth** — per-handler dead-letter count + age.
3. **Compensation correctness** — sagas that failed but compensations weren't run.
4. **Idempotency violations** — duplicate-side-effect signal.
5. **Schema-version drift** — events with unknown versions.

## Phase 3 — Retrieve

- **Temporal**: query for workflows in `Running` state > N hours.
- **Step Functions**: list executions in `RUNNING` > threshold.
- **Custom orchestrator**: query saga ledger / state table.
- **Choreography**: harder — need event-flow tracing across services. Use OpenTelemetry trace context.
- DLQ depth + oldest message age from broker (SQS GetQueueAttributes / Kafka consumer-group lag).
- Application logs / traces for failed-without-compensation patterns.

Read project's:
- `ai/patterns/saga-*.md` — declared sagas.
- `ai/patterns/event-handlers.md` — declared handlers.

## Phase 4 — Generate

```
## Distributed-tx audit — <date>

### Stuck sagas / workflows

| Saga | Instance | Stuck since | Step | Cause |
|---|---|---|---|---|
| place-order | wf-9f2a | 3d | scheduleShipping | Shipping service returned `INTERNAL_ERROR` 14× |
| place-order | wf-7c1e | 18h | chargePayment | Payment activity never invoked — orchestrator lost progress? |
| onboard-tenant | wf-3d4b | 2d | sendWelcomeEmail | SES quota exceeded; activity stuck retrying |

Total stuck: 14 instances across 4 saga types.

### DLQ depth

| Handler | DLQ depth | Oldest message | Trend |
|---|---|---|---|
| onOrderCreated | 230 | 6 days | growing |
| onPaymentSucceeded | 47 | 12 hours | stable |
| onSubscriptionRenewed | 8 | 2 hours | new alarm |

**`onOrderCreated` DLQ growing for 6 days unattended** — investigate poison-message class.

### Compensation correctness

Detected sagas that failed mid-flow:

| Saga instance | Failed at step | Compensations run | Missing |
|---|---|---|---|
| place-order/wf-2a3b | scheduleShipping | inventory: ✓ payment: ✓ | none |
| place-order/wf-8c1d | scheduleShipping | inventory: ✗ payment: ✓ | **inventory release missing** — investigate |
| onboard-tenant/wf-5f9e | createBillingProfile | tenant created: ✗ | **rollback skipped** — orphan tenant |

**3 sagas failed without full compensation. 2 require manual recovery.**

### Idempotency violations

Suspicious double-side-effect signals:

| Handler | Event ID | Side effect ran | Notes |
|---|---|---|---|
| onOrderCreated | order-94f3a | 2× | 2 confirmation emails sent for one order |
| onPaymentSucceeded | pay-1bc4e | 2× | Inventory released twice; potential double-stocking |

**Investigate**: idempotency key construction OR broker re-delivery (consumer ack failure).

### Schema-version drift

Events with versions outside known set:

| Event topic | Unknown version | Count last 24h |
|---|---|---|
| OrderCreated | v3 | 1,247 |
| PaymentRequested | v2 | 89 |

Producer for OrderCreated upgraded to v3 yesterday; handlers still expect v1/v2 → events skipped + alarmed.

### Recovery actions

| Action | Severity | Owner | Timeline |
|---|---|---|---|
| Manual: release inventory for 2 orders (wf-8c1d, etc.) — retry compensation | HIGH | platform-team | today |
| Investigate `onOrderCreated` DLQ poison message class | HIGH | notifications-team | today |
| Update OrderCreated handler to support v3 schema | HIGH | notifications-team | today |
| Investigate `onPaymentSucceeded` double-delivery (broker config or code bug) | MEDIUM | payments-team | this week |
| Drain old DLQ entries via `/dlq-replay` after fixes | MEDIUM | platform-team | after above |

### System health
- Stuck sagas:        14   (target: < 5)
- DLQ depth (sum):    285  (target: trending zero)
- Compensation gaps:  3    (target: 0)
- Idempotency violations: 2 (target: 0)
- Schema-version drifts: 2  (target: 0)

Verdict: **YELLOW** — stuck sagas + idempotency violations need fix THIS week.
```

## Phase 6 — Validate

After recovery actions:
- Re-run audit; counts drop.
- Specific sagas show resolved (compensated successfully).
- DLQ drained where appropriate.
- Idempotency root cause fixed (verified by replaying historical events without re-effect).

## Output format

```
## /audit-distributed-tx complete

Stuck sagas: <count>
DLQ depth: <sum>
Compensation gaps: <count>
Idempotency violations: <count>
Schema drifts: <count>

Verdict: GREEN / YELLOW / RED

Report: ai/audits/distributed-tx-<date>.md
Recovery actions: <count> (P0: <count>, P1: <count>)
```

## Hard rules

- **Stuck-saga threshold documented per saga type.** Some legitimately wait days (manual approval); others should never be > 1 hour.
- **DLQ replays go through `/dlq-replay`, not direct broker manipulation.** Audit trail.
- **Manual compensation runs documented in `ai/runbooks/saga-recovery.md`.**
- **Idempotency violations open an ADR if root cause is design-level.**
- **Schema-version drift surfaces as alert, not just audit finding.**

## Failure modes

- Audited but didn't validate that "stuck" sagas ARE actually stuck (some legitimately long-running).
- Drained DLQ before fixing the bug → events fail again, repopulate DLQ.
- Manual compensation run for the wrong order ID → incorrect refund.
- Schema-version drift fixed in handler but producer was rolled back → handler now drops valid events.

## Related

- `add-saga` command — what this audits.
- `add-event-handler` command — what this audits.
- `dlq-replay` skill — drain mechanism.
- `ai/patterns/event-sourcing.md`.
- `@event-sourcing-architect` agent.
