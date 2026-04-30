---
name: structured-logging
description: Pattern: Structured Logging
kind: ai-pattern
pack: observability
---

# Pattern: Structured Logging

> **Hard rule:** Every log is JSON with `timestamp`, `level`, `message`, `traceId`, and structured context fields; no string interpolation of variables into the message. PII (emails, names, tokens, full card numbers) and stack traces in user-visible responses are forbidden — they go to logs only, redacted per policy.

**When to apply**
- A service runs in production where logs are aggregated (Datadog, Loki, ELK, CloudWatch).
- An incident retro shows logs were unsearchable or PII leaked through them.
- A new request-scoped value (tenant, feature flag, A/B bucket) needs to appear in every line for that request.

**When NOT to apply**
- Local dev console output where readability beats queryability — use a pretty printer.
- A short-lived script that prints to stdout once.

**Halt conditions / mandatory cites**
- Each log call MUST cite the structured fields it emits at `<path:line>` — no `JSON.stringify` of arbitrary objects.
- Any field that may contain PII MUST cite the redaction helper or schema policy.
- A doc proposing `logger.info(\`user ${u.email} did X\`)` is a bug — reject; use structured fields.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this is enough context".
- If the logger library + correlation-ID propagation aren't extracted, halt.

Logs as queryable data, not grep targets.

## Baseline

Every log line is a JSON object with:
```json
{
  "timestamp": "2026-04-24T18:32:11.123Z",
  "level": "info",
  "message": "order.created",
  "reqId": "abc-123",
  "tenantId": "tnt-42",
  "userId": "usr-99",
  "operation": "POST /orders",
  "durationMs": 42,
  "context": "OrdersService"
}
```

## Library choices (by stack)

- **Node**: Pino (fast, structured by default) > Winston.
- **Python**: structlog > logging with JSON formatter.
- **Go**: zerolog / slog (1.21+).
- **Rust**: tracing + tracing-subscriber.
- **Java**: Logback + logstash-encoder.
- **Ruby**: Ougai / lograge.
- **PHP**: Monolog + JsonFormatter.

## Levels (use correctly)

| Level | Meaning | Alerts? |
|---|---|---|
| `error` | Operation failed, user-impacting | YES |
| `warn` | Recovered / degraded, investigate later | sometimes |
| `info` | Significant business event (order placed, user signed up) | no |
| `debug` | Developer diagnostic | never in prod |

## Required fields

Every log line must have:
- `timestamp` (UTC, ms precision, ISO-8601)
- `level`
- `message` — short identifier, not free-form prose
- `reqId` / `traceId` — correlation id
- For multi-tenant: `tenantId`

Additional per domain: `userId`, `orderId`, `paymentId`, `webhookId`, etc.

## Redaction

NEVER log:
- Passwords / tokens / API keys
- Card numbers, CVV
- Full phone numbers (`+20XXXXXXXXXX` → `+20*****XXXX`)
- Full email (`john@example.com` → `j**@example.com`)
- Full names with other PII on the same line

Redaction at the log library level — not "remember not to log it":
```ts
// Pino example
const logger = pino({
  redact: {
    paths: ['password', 'token', '*.password', '*.token', 'card.number'],
    censor: '[REDACTED]',
  },
});
```

## Transport

- Dev: pretty-print to stdout.
- Prod: JSON to stdout → collected by Docker/K8s log driver → shipped to central sink (Datadog / Loki / CloudWatch / OpenSearch).
- NEVER write to local files in prod (ephemeral containers lose them; size bombs disk).

## Query patterns

With structured logs, common queries:
- All errors for a tenant in the last hour: `level:error AND tenantId:tnt-42`
- Full request trace: `reqId:abc-123`
- Slow operations: `durationMs:>1000`
- Per-endpoint error rate: `operation:"POST /orders" AND level:error`

## Forbidden

- `console.log` in committed code.
- Unstructured strings in prod logs.
- Logging objects that might contain secrets (log explicit fields only).
- Logging inside hot loops without rate limiting.
- Writing logs to local files in containers.
