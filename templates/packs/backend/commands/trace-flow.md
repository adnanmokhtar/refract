---
description: Trace a request / event / job lifecycle through every layer — controller → service → repo → external calls → response. Produces a visual call chain with file:line pointers, failure modes per step, and observability gaps.
---

# /trace-flow

Diagnostic / read-only command. Produces a call chain + gap report, does not modify code.

## Phases applied

1, 2, 3, 6, 7. Phases 4 (Generate) + 5 (Update) are N/A — no code, no docs written; output is a findings report. Phase 6 here = "validate the trace is complete and accurate". Phase 7 = capture any patterns / drift surfaced.

## When to use / NOT to use

- USE: you're about to modify a flow and need to understand it first.
- USE: a bug spans layers and you need the chain.
- USE: onboarding a new engineer to a feature.
- USE: documenting an API-to-DB flow for an ADR.
- NOT: when you need a deep root-cause investigation (`/fix-bug` does that, dispatching trace as a sub-step).
- NOT: for the whole app — trace ONE flow at a time.

## Usage

```
/trace-flow <endpoint>                # e.g. POST /orders
/trace-flow <event-name>              # e.g. order.placed
/trace-flow <use-case-class>          # e.g. ProcessInboundMessageUseCase
/trace-flow <job-class>               # e.g. DailyBillingRollupJob
```

## Phase 1 — Understand (the ask)

- Parse the argument: endpoint, event, use-case class, or job class.
- Confirm scope: ONE flow only.
- Identify the entry-point type from the arg shape:

| Type | Entry |
|---|---|
| HTTP endpoint | controller method |
| Webhook | webhook controller + signature verifier |
| Event | event handler class |
| Queue consumer | consumer class |
| Scheduled job | job class / cron binding |
| gRPC | service method |
| CLI command | command class |

## Phase 2 — Organize (decompose the work)

Plan the trace walk:
1. Locate the entry point.
2. Walk the chain step-by-step (each call → file:line → side effects → errors → observability).
3. Identify external boundaries.
4. Identify gaps.
5. Synthesize the visual call chain + summary report.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

FLOW-SPECIFIC:
- The entry-point file (controller / handler / job).
- Every file the chain touches (services, repos, mappers, external clients).
- Relevant patterns: `webhook-flow.md`, `idempotency.md`, `multi-tenancy.md` (per signal).

EXISTING CODE walk-through:

For each step, identify:
- **File:line** of the call.
- **Type** (HTTP / DB query / cache / external API / event emit / job enqueue).
- **Inputs** (DTO, domain object, event payload).
- **Outputs** (typed return).
- **Side effects** (DB write, cache invalidation, event emission, external call).
- **Error modes** (what typed errors can be thrown + where caught).
- **Observability** (logs emitted, metrics incremented, trace span present).

Annotate every crossing of a process / service boundary:
- DB: which query, indexed how, expected latency.
- Cache: read / write, key shape, TTL.
- External API: which provider, timeout, retry, circuit breaker.
- Event publish: pattern, metadata, payload size.

## Phase 4 — N/A

Read-only diagnostic; no code generated.

## Phase 5 — N/A

No knowledge files mutated by trace itself. (If the trace surfaces a missing pattern doc, mention it in Phase 7 follow-ups; don't write it inline.)

## Phase 6 — Validate (verify completeness of the trace)

- Every step has a file:line. NEVER "the service" without naming it.
- External boundaries annotated with timeout / retry / circuit-breaker status.
- Observability gaps called out explicitly per step.
- Tenant isolation verified end-to-end (no missing filter).
- Identify gaps:
  - Missing error handling.
  - Missing observability (no log / metric / span on an external call).
  - Missing idempotency (retryable operation without key).
  - Missing tenant filter.
  - Missing timeout.

## Phase 7 — Improve (feed the learning loop)

- If the trace surfaced a recurring pattern (e.g., 3+ flows missing circuit breakers): queue to `ai/dynamic/learned-patterns.md` as a project-wide concern.
- If the trace surfaced drift (file referenced in `ai/patterns/webhook-flow.md` no longer exists): append to `ai/dynamic/drift-log.md`.
- If gaps found warrant fixing: suggest follow-up commands (`/fix-bug`, `/add-telemetry`, `/add-feature`).
- Run `/learn-from-task` if the trace was substantial and surfaced new insights.

## Output — visual call chain

```
POST /webhooks/whatsapp
│
├─ [entry]  WhatsAppWebhookController.handle
│           src/modules/whatsapp/adapters/webhooks/whatsapp-webhook.controller.ts:42
│           Auth: @UseGuards(WebhookSignatureGuard)
│           Inputs: raw body + X-Hub-Signature-256 header
│           Observability: ✓ log entry, ✓ metric webhook_received_total
│
├─ [guard]  WebhookSignatureGuard.verify
│           src/modules/whatsapp/infrastructure/webhook-signature-guard.ts:18
│           HMAC-SHA256 against WHATSAPP_APP_SECRET
│           Failure → 401, metric webhook_signature_invalid_total
│           Gaps: ✓ no issues
│
├─ [parse] ProcessInboundMessageUseCase.execute
│           src/modules/whatsapp/application/use-cases/process-inbound-message.use-case.ts:24
│           │
│           ├─ [db read]  TenantRepository.findByWhatsappPhoneNumberId
│           │             src/modules/tenants/infrastructure/persistence/tenant.repository.impl.ts:42
│           │             SQL: SELECT * FROM tenants WHERE whatsapp_phone_number_id=$1 AND is_active=true
│           │             Indexed: idx_tenants_whatsapp_phone_number_id ✓
│           │             p95: ~8ms
│           │             Failure: TenantNotFoundError → 200 (don't leak existence)
│           │
│           ├─ [context] TenantContext.run(tenant, async () => { ... })
│           │             Wraps remaining execution with tenant scope.
│           │
│           ├─ [dedup]   MessageRepository.findByWhatsappMessageId (idempotency)
│           │             src/modules/messages/infrastructure/persistence/message.repository.impl.ts:58
│           │             Returns if already stored → return 200 without re-processing
│           │             Gap: ✓ proper idempotency
│           │
│           ├─ [db write] ConversationRepository.upsertByPhone
│           │              src/modules/conversations/infrastructure/persistence/conversation.repository.impl.ts:24
│           │              INSERT ... ON CONFLICT (tenant_id, customer_phone) DO UPDATE
│           │              Indexed: unique (tenant_id, customer_phone) ✓
│           │
│           ├─ [db write] MessageRepository.insertInbound
│           │              src/modules/messages/infrastructure/persistence/message.repository.impl.ts:32
│           │              INSERT ... RETURNING id
│           │              Unique constraint on whatsapp_message_id for dedup
│           │
│           ├─ [use-case] GenerateReplyUseCase.execute
│           │              src/modules/ai/application/use-cases/generate-reply.use-case.ts:18
│           │              │
│           │              ├─ [db read]  ProductRepository.findForTenant
│           │              │             p95: ~12ms (cached via Redis with 5min TTL)
│           │              │
│           │              ├─ [db read]  MessageRepository.findLastN(conversation_id, 10)
│           │              │             Composite index (conversation_id, created_at DESC) ✓
│           │              │
│           │              ├─ [prompt]   PromptBuilder.build
│           │              │             Assembles system + tenant ctx + strategy + history + user message.
│           │              │             Token budget: ≤ 3000 input, ≤ 300 output.
│           │              │
│           │              └─ [external] ClaudeClient.reply            ← CRITICAL BOUNDARY
│           │                             Anthropic API via @anthropic-ai/sdk
│           │                             Timeout: 3s (AbortController)
│           │                             Retry: 0 (idempotent via max_tokens, but calls cost $$)
│           │                             Metric: claude_call_duration_ms (histogram)
│           │                             Trace: span with tenant_id + model + input_tokens + output_tokens
│           │                             Failure: ClaudeTimeoutError → caller falls back to tenant.fallback_reply
│           │                             Gap: ✓ resilient
│           │
│           ├─ [external] WhatsAppSenderService.sendText  ← CRITICAL BOUNDARY
│           │              Meta Graph API v20 via fetch
│           │              Timeout: 5s
│           │              Retry: 1 (idempotent — per Meta docs with an idempotency header)
│           │              Metric: whatsapp_send_total{status}
│           │              Failure: log + metric + proceed (don't crash webhook)
│           │              Gap: ✗ no circuit breaker → if Meta is down for 30m, every request keeps timing out
│           │
│           └─ [db write] MessageRepository.insertOutbound (with tokens + cost)
│                         Subscriber: UsageMeter.record → usage_logs aggregated row update
│
└─ [response] 200 OK (always, unless signature/parse failure)
              Returned within ~3s budget for Meta's 5s timeout.
```

## Summary report

```
## /trace-flow — POST /webhooks/whatsapp

**Entry:** WhatsAppWebhookController.handle
**Exit:** 200 OK
**Latency:** p95 ~2.4s (synchronous — Phase 1)
**Cost per call:** ~$0.00007 (Haiku) + Meta send + DB

### External boundaries
| Call | Timeout | Retry | Circuit breaker | Trace | Metric | Fallback |
|---|---|---|---|---|---|---|
| Claude | 3s ✓ | 0 ✓ | ✗ | ✓ | ✓ | ✓ tenant.fallback_reply |
| Meta Send | 5s ✓ | 1 ✓ | ✗ | ✓ | ✓ | log only |

### Gaps found
1. **[MEDIUM]** No circuit breaker on Meta Send — an outage causes repeated 5s timeouts.
   Fix: opossum / cockatiel wrapper with 50% threshold, 30s cooldown.
2. **[LOW]** ProductRepository cache invalidation: 5min TTL may serve stale for up to 5min after a write.
   Fix: explicit invalidation on product write via subscriber.

### Tenant isolation
✓ TenantContext wraps all downstream. All queries filter by tenant.

### Observability
✓ Correlation id propagated through every log line.
✓ Trace spans on every hop.
✓ Metrics per call + per business event.
✗ No dashboard showing this flow end-to-end — consider adding.

### Phase 7 follow-ups
- Use this flow diagram in ai/patterns/webhook-flow.md (already present — update if stale).
- Address the 1 MEDIUM + 1 LOW gap (separate tickets / `/fix-bug` runs).
- If circuit-breaker absence appears in a 2nd flow → queue to `ai/dynamic/learned-patterns.md` as project-wide concern.

Status: COMPLETE — read-only trace, no files modified.
```

## Rules

- Name SPECIFIC files + line numbers — never "the service".
- External boundaries annotated with timeout / retry / circuit-breaker status.
- Observability gaps called out explicitly.
- Use for ONE flow at a time — don't try to map the whole app.
- Flag any path without error handling / idempotency / tenant filter.
