---
name: log-tail
description: Tail structured logs from the dev server, filtered by correlation id / level / module. Used when an endpoint misbehaves or a trace needs following.
---

# log-tail

Stream structured JSON logs (Pino / Winston / zerolog / structlog) with `jq` filters scoped to one request, level, module, or tenant.

## When to use

- Endpoint returns 500 — find the stack trace + upstream calls in the same trace ID.
- Webhook receiver isn't firing — confirm payload arrived.
- Tenant reports "slow" — filter by their tenant ID and look for outliers.
- After enabling debug logs for one module without a global level change.

## Prerequisites

- Dev server logging in JSON (check the project's actual logger lib from extraction — Pino / Winston / zerolog / structlog / log15 / etc.).
- `jq` installed.
- One of: log file, container name, or running PID.

## Procedure

1. Identify log source from `CLAUDE.md` or running process:
   ```bash
   # File-based
   ls -1 logs/*.log 2>/dev/null
   # Container
   docker compose ps --services
   # Foreground process — pipe its stdout (redirect at start: `bun run start:dev | tee logs/app.log`)
   ```
2. Tail with the right command:
   ```bash
   tail -F logs/app.log                # file
   docker compose logs -f api          # container
   ```
3. Apply filter via `jq`:
   ```bash
   # Errors only (Pino: trace=10, debug=20, info=30, warn=40, error=50, fatal=60)
   tail -F logs/app.log | jq -c 'select(.level >= 50)'
   # Single request trace
   tail -F logs/app.log | jq -c 'select(.reqId == "abc-123" or .req.id == "abc-123")'
   # One module
   tail -F logs/app.log | jq -c 'select(.context == "OrdersService")'
   # One tenant
   tail -F logs/app.log | jq -c 'select(.tenantId == "tenant_42")'
   # Slow requests
   tail -F logs/app.log | jq -c 'select(.responseTime > 500)'
   ```
4. For unstructured fallback, swap `jq` for `grep -E`:
   ```bash
   tail -F logs/app.log | grep -E 'ERROR|FATAL|reqId=abc-123'
   ```
5. Pretty-print one event when investigating:
   ```bash
   tail -n 200 logs/app.log | jq 'select(.reqId=="abc-123")' | jq -s '.'
   ```

## Output

```
[2026-04-24T09:14:02.123Z] ERROR  OrdersService  req=a1b2c3  tenant=t_42  failed to create order: validation error
[2026-04-24T09:14:02.124Z] ERROR  ExceptionFilter req=a1b2c3 tenant=t_42 ValidationError: items[0].sku must not be empty
   at CreateOrderDto.validate (src/orders/dto/create-order.dto.ts:34)
   at OrdersController.create (src/orders/controllers/orders.controller.ts:58)
[2026-04-24T09:14:02.125Z] INFO   HttpLogger     req=a1b2c3 tenant=t_42 POST /orders 400 2ms
```

## False positives / gotchas

- Multi-line stack traces break naive `tail | grep` — Pino keeps them as a single JSON line; some loggers don't.
- Time zones: log timestamps may be UTC while CLAUDE is in local time — convert when correlating with user-reported timestamps.
- PII: phone numbers, emails, tokens may be in logs — redact before sharing (`jq` with `.user.phone |= sub("(\\d{3})\\d+(\\d{3})";"\(.1)***\(.2)")`).
- `tail -f` (lowercase) drops the file on rotation; `tail -F` follows the rename — always use `-F` for long sessions.
- Dev only — never tail prod logs from this skill; use the central log aggregator.
