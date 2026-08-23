---
name: structured-logging
description: "Pattern: Structured Logging"
kind: ai-pattern
pack: observability
---

# Pattern: Structured Logging

> **Hard rule:** Every log is JSON with `timestamp`, `level`, `message`, `trace_id`, and structured context fields; no string interpolation of variables into the message. The correlation ID reaches every line through **ambient context**, never through a threaded parameter. PII (emails, names, tokens, full card numbers) and stack traces in user-visible responses are forbidden — they go to logs only, redacted per policy.

**When to apply**
- A service runs in production where logs are aggregated (any centralised log backend — Datadog, Loki, ELK, CloudWatch, Splunk, etc.).
- An incident retro shows logs were unsearchable or PII leaked through them.
- A new request-scoped value (tenant, feature flag, A/B bucket) needs to appear in every line for that request.

**When NOT to apply**
- Local dev console output where readability beats queryability — use a pretty printer.
- A short-lived script that prints to stdout once.

**Halt conditions / mandatory cites**
- Each log call MUST cite the structured fields it emits at `<path:line>` — no whole-object dumps of arbitrary structures.
- Any field that may contain PII MUST cite the redaction helper or schema policy.
- A doc proposing string-interpolated log messages (e.g., a logger call concatenating `user ${u.email} did X` into the message) is a bug — reject; use structured fields.
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
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "request_id": "abc-123",
  "tenant_id": "tnt-42",
  "user_id": "usr-99",
  "operation": "POST /orders",
  "duration_ms": 42,
  "context": "OrdersService"
}
```

**Casing: one per project, mirrored from the sibling — with two fixed exceptions.** `trace_id` and
`span_id` are spelled that way by the OpenTelemetry log-correlation convention, and most backends
key their automatic log↔trace linking off those exact strings. A project that renames them to
`traceId` still has correlatable data and loses the automation, silently — nothing errors, the
"view trace" affordance just isn't there. If the rest of the project is camelCase, keep the rest
camelCase and keep these two snake_case; consistency with a convention beats internal symmetry when
the convention is what a tool reads.

## Library choices (by stack — pick one structured logger, not the language's default print)

Every mainstream language ecosystem has at least one structured logger with first-class JSON output (e.g., Pino / Winston for Node, structlog for Python, zerolog or `slog` for Go, `tracing` / `log` for Rust, Logback + JSON encoder for Java, Ougai / Lograge for Ruby, Monolog with JsonFormatter for PHP, Serilog for .NET, Logger with Logstash backend for Elixir). Pick the one already used in sibling services; if greenfield, pick one with structured-JSON-by-default to avoid a parallel formatter config.

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
- `trace_id` (+ `span_id` when tracing) and/or `request_id` — the correlation id
- For multi-tenant: `tenant_id`

Additional per domain: `user_id`, `order_id`, `payment_id`, `webhook_id`, etc.

## Correlation-ID propagation — the part that is actually hard

Deciding *which* field carries the correlation ID is trivial. Getting it onto **every** log line is
the whole difficulty of this pattern, and it is where implementations fail: the ID is present in the
controller, absent three frames down in a service, and absent everywhere in the background job the
request enqueued. Two mechanisms, and only one of them survives contact with a real codebase.

**Threading it as a parameter does not work.** It requires touching every function signature between
the edge and the log call, it is silently incomplete the moment someone adds a call path, and it
does not cross an async boundary at all. Treat any codebase doing this as having no correlation.

**Ambient (implicit) context is the mechanism.** Every mainstream runtime has one; the shape is
identical even though the name is not:

| Runtime | Primitive |
|---|---|
| Node.js | `AsyncLocalStorage` (`node:async_hooks`) |
| Python | `contextvars.ContextVar` |
| Go | `context.Context`, passed as the conventional first argument |
| Java / Kotlin | SLF4J **MDC** (thread-local; needs an executor decorator to cross threads) |
| .NET | `AsyncLocal<T>` (or logging scopes) |
| Ruby | thread/fiber-local storage |

The wiring is always the same three steps:

1. **Enter the context at the edge** — one middleware / interceptor that extracts `traceparent` (or
   mints an ID), opens the ambient scope, and holds it for the request's lifetime.
2. **Bind the logger to the context, not to the call site** — a child logger, a log processor, or a
   formatter hook that reads the ambient values on *every* emit. Once this exists, ordinary
   `log.info("order.created", {order_id})` calls carry correlation with no per-call-site knowledge,
   which is the only version that stays true as the codebase grows.
3. **Re-enter it at every async hop you own** — a queue publish writes the context into the message
   metadata; the consumer reads it back and opens a *new* ambient scope before doing anything else.
   This is the step that gets skipped, and its symptom is a trace that stops at the queue.

Go is the deliberate exception: it makes the context explicit as a first argument rather than
ambient. That is the same design, enforced by the compiler instead of by the runtime.

**Detector:** a log line inside a service or repository layer that carries no correlation field, in a
codebase whose edge middleware clearly sets one — that gap is a threading implementation, or an async
hop with no re-entry, and both are findings.

## Redaction

NEVER log:
- Passwords / tokens / API keys
- Card numbers, CVV
- Full phone numbers (`+20XXXXXXXXXX` → `+20*****XXXX`)
- Full email (`john@example.com` → `j**@example.com`)
- Full names with other PII on the same line

Redaction at the log library level — not "remember not to log it". Configure the project's logger with redaction paths for sensitive field names (e.g., `password`, `token`, nested variants `*.password`, `*.token`, payment fields like `card.number`); the censor renders as `[REDACTED]`.

## Transport

- Dev: pretty-print to stdout.
- Prod: JSON to stdout → collected by the runtime's log driver (container runtime, orchestrator log shipper, syslog, etc.) → shipped to the project's centralised log backend.
- NEVER write to local files in prod (ephemeral containers lose them; size bombs disk).

## Query patterns

With structured logs, common queries:
- All errors for a tenant in the last hour: `level:error AND tenant_id:tnt-42`
- Full request trace: `trace_id:4bf92f35...`
- Slow operations: `duration_ms:>1000`
- Per-endpoint error rate: `operation:"POST /orders" AND level:error`

## Migrating a project that logs to stdout today

Do not rewrite the call sites; that is a large diff that stalls and leaves half the codebase on the
old path. Three steps, in this order:

1. **Swap the sink behind a shim** the existing call signature still satisfies, so no call site
   changes. Every existing line becomes structured immediately, with a `message` and no context.
2. **Backfill the request-scoped fields inside the shim** from ambient context (above). The
   correlation ID, `tenant_id` and `duration_ms` appear on every line without anyone editing them.
3. **Only then** convert interpolated messages (`"user " + id + " did X"`) into event name +
   fields — mechanically, file by file, with a lint rule preventing new ones.

Steps 1–2 are one module and deliver most of the value; step 3 is the long tail and can run for
weeks without blocking anything.

## Detectors (what a reviewer flags)

- **Direct stdout / unstructured print in committed code** — the pack's most basic defect and the one a lint rule should own rather than a reviewer.
- **Interpolated message** — a variable concatenated into the message string instead of emitted as a field. Unqueryable by that value, and it is how PII escapes redaction (the redactor inspects fields, not the message).
- **Correlation gap below the edge** — an edge middleware sets a correlation ID and a service-layer log line has none: threading, or an async hop with no context re-entry.
- **`traceId` / `spanId` in camelCase** — correlatable data, no automatic backend linking, no error.
- **Whole-object log** — the entire user / request / config object passed to the logger. Leaks via fields nobody enumerated, and it defeats field-level redaction paths.
- **Log written to a local file in a container** — lost on restart, and a disk-fill risk.
- **Unrate-limited log inside a hot loop** — the ingestion bill and the dropped-buffer incident both start here.

## Forbidden

- Direct stdout / unstructured print calls in committed code (any language's `console.log` / `print` / `fmt.Println` / `puts` / `System.out.println`).
- Unstructured strings in prod logs.
- Threading the correlation ID as a function parameter instead of using ambient context.
- Logging objects that might contain secrets (log explicit fields only).
- Logging inside hot loops without rate limiting.
- Writing logs to local files in containers.

## References

- OpenTelemetry logs data model + trace correlation — `https://opentelemetry.io/docs/specs/otel/logs/data-model/`
- Node `AsyncLocalStorage` — `https://nodejs.org/api/async_context.html`
- Python `contextvars` — `https://docs.python.org/3/library/contextvars.html`
- Go `context` — `https://pkg.go.dev/context`
- SLF4J MDC — `https://www.slf4j.org/manual.html#mdc`
