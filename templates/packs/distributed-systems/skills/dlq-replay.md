---
description: Replay messages from a dead-letter queue back to a primary handler. Selective (filter by criteria) or full. Idempotency-safe; rate-limited; observable; reversible (re-DLQ on failure).
---

# Skill: dlq-replay

DLQ messages don't fix themselves. After fixing the root cause, the messages need replay. This skill does it safely.

## When to use

- Root cause of a poison message resolved (handler bug fixed, schema drift addressed, downstream service recovered).
- Periodic DLQ drain (after audits).
- Disaster recovery: events lost during outage, replay from a buffered store.

## When NOT to use

- Root cause NOT fixed → replay just re-poisons.
- Without idempotency in handlers → replay causes duplicate side effects.
- During peak load → replay competes with live traffic; do off-peak.

## Procedure

### 1. Confirm root cause fixed

Before replay:
- The bug that caused the original failure is shipped to production.
- Tests confirm the failing message class now processes successfully.
- Idempotency in the handler has been verified (replay safe).

If unclear: don't replay; sample one message manually first.

### 2. Inventory the DLQ

| Broker | Inspection |
|---|---|
| AWS SQS DLQ | `aws sqs receive-message --queue-url <dlq>` (with `VisibilityTimeout`) |
| Kafka __consumer_offsets / DLQ topic | `kafka-console-consumer --topic <dlq> --from-beginning` |
| RabbitMQ DLQ | Management UI or `rabbitmqctl list_queues` |
| EventBridge | DLQ is SQS — same as above |
| Cloud Pub/Sub | gcloud pubsub subscriptions pull |

Per message: occurred_at, attempt count, failure reason (if attached), payload.

### 3. Categorize messages

Group by failure class:
- **Same root cause** — replay all together.
- **Different root cause** — investigate; not all are safe to replay.
- **Bug-on-bug** — once resolved one, the underlying message may surface a second bug.

### 4. Sample replay (always first)

Pick ONE message. Submit it back to the primary topic / queue. Verify:
- Handler processes successfully.
- Side effect runs.
- Idempotency checks pass (re-delivery within sample run = no duplicate effect).

If sample fails: STOP. Don't bulk replay.

### 5. Bulk replay (after sample passes)

Rate-limited. Don't dump 10,000 messages at once.

```bash
# AWS SQS — pseudo-code
while [ $(aws sqs get-queue-attributes --queue-url $DLQ --attribute-names ApproximateNumberOfMessages --query 'Attributes.ApproximateNumberOfMessages' --output text) -gt 0 ]; do
  msg=$(aws sqs receive-message --queue-url $DLQ --wait-time-seconds 5 --max-number-of-messages 1)
  receipt=$(echo $msg | jq -r '.Messages[0].ReceiptHandle')
  body=$(echo $msg | jq -r '.Messages[0].Body')
  attrs=$(echo $msg | jq -r '.Messages[0].MessageAttributes // {}')

  # Send to primary
  aws sqs send-message --queue-url $PRIMARY --message-body "$body" --message-attributes "$attrs"

  # Delete from DLQ after primary accepts
  aws sqs delete-message --queue-url $DLQ --receipt-handle $receipt

  # Rate limit (e.g., 10 msg/sec)
  sleep 0.1
done
```

For Kafka: use a one-off consumer that reads from DLQ topic and produces to primary topic. Be aware of partition-key preservation (the original message's key may matter for downstream ordering).

### 6. Monitor replay impact

While replay runs:
- Handler error rate — should not spike.
- Processing latency P95 — should not balloon.
- DLQ count — should drop.
- Side-effect counters (orders processed / emails sent / etc.) — should rise.

If error rate spikes during replay: STOP. Root cause may not be fully fixed.

### 7. Verify replay outcome

After completion:
- DLQ near zero.
- Side effects produced as expected (verify a sample).
- No duplicate effects (idempotency held).
- Handler error rate back to baseline.

## Output format

```
## /dlq-replay — <handler / topic>

### DLQ before
- Depth: <N>
- Oldest: <duration>
- Failure classes: <list>

### Sample replay
- Sample message: <id>
- Handler outcome: success / failure
- Idempotency: held / violated

### Bulk replay
- Rate limit: <msg/sec>
- Started: <timestamp>
- Ended: <timestamp>
- Replayed: <N>
- Failed during replay (back to DLQ): <M>

### Outcome
- DLQ after: <K>
- Side effects produced: <verified-count>
- Handler error rate during replay: <% delta from baseline>

### Follow-up
- <M> messages failed again — root cause: <description>; ADR or ticket: <link>
- DLQ remaining: <K>; require investigation OR are different failure classes.

Report: ai/audits/dlq-replay-<handler>-<date>.md
```

## Inputs

- DLQ name / topic.
- Primary queue / topic.
- Rate limit.
- Filter criteria (optional — replay messages matching attribute X / time range).

## Outputs

- Replay report.
- Updated DLQ (drained or partially drained).

## Hard rules

- **Sample first.** Never bulk-replay without verifying ONE.
- **Root cause confirmed fixed.** If not, replay re-creates DLQ contents.
- **Rate limit.** Never dump bulk; stress runs over normal traffic.
- **Idempotency verified.** Without it, replay is duplication.
- **Audit trail.** Replay logged: who, when, how many, outcome.
- **Don't replay from a backup older than retention.** Compliance / GDPR concerns if PII in old events.

## Failure modes

- Replayed before fix → messages back in DLQ; cycle repeats.
- Idempotency NOT enforced → side effects duplicated (double email, double charge).
- Bulk replay during peak → live traffic latency degrades.
- Replayed messages out-of-order → consumer downstream sees inconsistent state.
- Partition key NOT preserved (Kafka) → downstream ordering broken.
- Forgot to delete from DLQ after replay → messages re-replay forever.

## Related

- `add-event-handler` — produces what this drains.
- `audit-distributed-tx` — finds DLQs needing drain.
- `add-saga` — saga compensations sometimes hit DLQ; replay carefully.
- `ai/runbooks/dlq-recovery.md` (project-specific) — cite the project's actual DLQ procedures.
