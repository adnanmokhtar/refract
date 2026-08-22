---
description: Trace a request / event / job lifecycle through every layer — controller → service → repo → external calls → response. Produces a visual call chain with file:line pointers, failure modes per step, and observability gaps.
---

# /trace-flow

Diagnostic / read-only command. Produces a call chain + gap report, does not modify code.

## The Premise (read this first, internalize, do not deviate)

**Pattern almost always repeats.** A trace through one flow is rarely an isolated reading. If this webhook lacks a circuit breaker, the other 4 webhooks in the repo almost certainly do too. If this controller forgets to propagate the correlation id, the sibling controllers built off the same template forgot too. If this external call has no timeout, the `axios` import line was almost certainly copy-pasted into 6 other files. The trace's value is doubled when a finding is checked against sibling flows — surfacing one missing circuit breaker is a ticket; surfacing five is a project-wide ADR.

**The agent's job is exactly this:**
1. Walk the named flow end to end with `file:line` cited at every hop.
2. For every gap surfaced (missing timeout, missing tenant filter, missing observability), **grep the codebase for the same shape across sibling flows** and report the cluster, not just the singular finding.
3. Distinguish singular gaps (1 instance) from systemic gaps (≥2 instances) in the report — they get different follow-ups.

**The agent does NOT:**
- Stop at "missing circuit breaker on Meta Send" without checking the other 4 external clients in the repo. **Check siblings; surface the cluster.**
- Use words like `the service`, `the repo`, `somewhere downstream`. **Every step has a file:line — never a noun without a path.**
- Map the whole app — ONE flow per invocation. **Cluster discovery is grep, not re-trace.**
- Promise gaps "will be addressed elsewhere" without naming the follow-up command. **`/fix-bug`, `/add-telemetry`, ADR — pick one per gap.**
- **Emit a latency, p95, throughput, cost or index-effectiveness figure the walk did not obtain.** This command reads source; source does not contain measurements. An invented `p95: ~8ms` in an output this persuasive is believed. **Every number carries its source or is emitted as `unmeasured` — see § Provenance rule.**

**The agent ONLY escalates to the user when:**
- The flow's entry point cannot be resolved (controller method ambiguous, multiple matches).
- A sibling-flow grep surfaces ≥3 instances of the same gap — that's project-wide and warrants ADR consideration before piecemeal fixes.
- Tenant isolation is broken at any hop — halt for `/security-audit`.

## Cluster halt (mechanical gate, all tiers)

**For every gap surfaced in the trace, check sibling flows for the same shape via grep.** A gap's severity is a function of its cluster size, not its singular presence.

Halt rule: if any gap has cluster count > 1 across sibling flows, the agent MUST surface every instance, not just the one in the traced flow. Output format:

```
Gap: missing circuit breaker on external HTTP boundary
  Traced flow: WhatsAppSenderService.sendText (whatsapp-sender.service.ts:42)
  Sibling matches (grep for `fetch(` / `axios.` / `http.request` outside `lib/http-client.ts`):
    - SmsSenderService.sendSms          src/modules/sms/.../sms-sender.service.ts:31
    - PaymentProviderClient.charge      src/modules/payments/.../provider-client.ts:88
    - GeoLookupClient.lookup            src/modules/geo/.../geo-client.ts:24
  Cluster size: 4
  Severity: project-wide → ADR candidate, not piecemeal /fix-bug
```

Forbidden:
- Surfacing one finding when grep would show three.
- Saying "this pattern appears elsewhere" without naming each file.
- Describing a gap with `the service` or `the repo` — every reference is a path.

If the sibling grep returns zero matches, say so explicitly: `Cluster size: 1 (singular)`. Silence on cluster status is itself a hand-wave.

## Provenance rule (mechanical gate, all tiers)

**Everything this command emits is either read from source or measured. Nothing is estimated.** Reading a file yields structure — never latency, never cost, never how effective an index is. A number that appears anyway was invented, and it is the most dangerous line in the report precisely because the surrounding `file:line` citations make it look sourced.

| Claim | Admissible source (cite it inline) | Otherwise emit |
|---|---|---|
| Latency / p95 / p99 per hop | a metrics query actually run, a trace exemplar, or a timed local run — name which, with the window | `p95: unmeasured` |
| End-to-end flow latency | the same, on the entry-point span | `Latency: unmeasured (no span/metric on this flow — see Gaps)` |
| Cost per call | the provider's published price × token/request counts read from the code's own budget or a logged usage row — cite both halves | `Cost per call: unmeasured` |
| Index effectiveness | `EXPLAIN (ANALYZE, BUFFERS)` for that exact query | `index <name> present (plan not verified)` |
| Timeout / retry / breaker / TTL / page cap | **source is admissible** — these are literals; cite `file:line` | (must be citable — otherwise it is a gap, not an unknown) |

`unmeasured` is a first-class, honest output, and it is also a finding: a hot path with no way to measure it is an observability gap routed to `/add-telemetry`, not a blank to be filled with a plausible number.

**Halt: any figure in the report without an inline source and not marked `unmeasured` invalidates the run.**

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
- **tx:** — **which transaction this step belongs to**, and whether it is one. This axis decides correctness on any multi-write flow and is invisible in a chain drawn without it. Record `tx:<name>` (inside a transaction — cite the site that opened it), `tx:none`, or `tx:AMBIGUOUS` (a decorator/context is in scope but the write path leaves it — say so rather than guessing). Two writes with different `tx:` values are **not** atomic, whatever the code looks like; an external call carrying a `tx:` value is holding a DB connection across a network round-trip. Both are findings.
- **Error modes** (what typed errors can be thrown + where caught).
- **Observability** (logs emitted, metrics incremented, trace span present).

Annotate every crossing of a process / service boundary:
- DB: which query, indexed how (index name from the schema), and its `tx:` value. **Latency is not readable from source** — leave it `unmeasured` unless a measurement was actually run.
- Cache: read / write, key shape, TTL (`file:line` of the TTL literal).
- External API: which provider, timeout, retry, circuit breaker (each a literal at `file:line`), and its `tx:` value.
- Event publish: pattern, metadata, payload size (measured or `unmeasured`).

## Phase 4 — N/A

Read-only diagnostic; no code generated.

## Phase 5 — N/A

No knowledge files mutated by trace itself. (If the trace surfaces a missing pattern doc, mention it in Phase 7 follow-ups; don't write it inline.)

## Phase 6 — Validate (verify completeness of the trace)

- Every step has a file:line. NEVER "the service" without naming it.
- **Every step has a `tx:` value** — `tx:<name>`, `tx:none`, or `tx:AMBIGUOUS`. A write step with no `tx:` annotation is an incomplete trace, not a clean one.
- **Every quantitative claim carries an inline source or reads `unmeasured`.** Scan the drafted report for bare numbers before emitting it; this check exists because the exemplar is what gets copied.
- External boundaries annotated with timeout / retry / circuit-breaker status, each cited at `file:line`.
- Observability gaps called out explicitly per step.
- Tenant isolation verified end-to-end (no missing filter).
- Identify gaps:
  - Missing error handling.
  - Missing observability (no log / metric / span on an external call).
  - Missing idempotency (retryable operation without key).
  - Missing tenant filter.
  - Missing timeout.
  - **Split transaction** — two or more writes on this flow with different `tx:` values, or a partial-failure window between them with no compensation. Report both write sites and the state the system is left in when the second one fails.
  - **External call inside a transaction** — a step whose `tx:` is a named transaction and whose type is `external API`. The DB connection is held across someone else's network call; under load this exhausts the pool before it times out.
  - **Unmeasurable hot path** — a step emitted `unmeasured` because no metric or span exists. Route to `/add-telemetry`.

## Phase 7 — Improve (feed the learning loop)

- If the trace surfaced a recurring pattern (e.g., 3+ flows missing circuit breakers): queue to `ai/dynamic/learned-patterns.md` as a project-wide concern.
- If the trace surfaced drift (file referenced in `ai/patterns/webhook-flow.md` no longer exists): append to `ai/dynamic/drift-log.md`.
- If gaps found warrant fixing: suggest follow-up commands (`/fix-bug`, `/add-telemetry`, `/add-feature`).
- Run `/learn-from-task` if the trace was substantial and surfaced new insights.

## Output — visual call chain

Every hop carries a `file:line`, a `tx:` value, and — where a number appears at all — its source. The exemplar below is the template the agent copies, so it models the two rules that are easiest to violate: **no unsourced number** and **no write without a `tx:`**.

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
│           │             Indexed: idx_tenants_whatsapp_phone_number_id ✓ (plan not verified)
│           │             tx: none (read before the write transaction opens)
│           │             p95: unmeasured — no per-query histogram; see Gaps
│           │             Failure: TenantNotFoundError → 200 (don't leak existence)
│           │
│           ├─ [context] TenantContext.run(tenant, async () => { ... })
│           │             Wraps remaining execution with tenant scope.
│           │
│           ├─ [dedup]   MessageRepository.findByWhatsappMessageId (idempotency)
│           │             src/modules/messages/infrastructure/persistence/message.repository.impl.ts:58
│           │             Returns if already stored → return 200 without re-processing
│           │             tx: none
│           │             Gap: ✓ proper idempotency
│           │
│           ├─ [db write] ConversationRepository.upsertByPhone
│           │              src/modules/conversations/infrastructure/persistence/conversation.repository.impl.ts:24
│           │              INSERT ... ON CONFLICT (tenant_id, customer_phone) DO UPDATE
│           │              Indexed: unique (tenant_id, customer_phone) ✓
│           │              tx: AMBIGUOUS — no transaction opened on this path;
│           │                  this write and the two below are three separate commits
│           │
│           ├─ [db write] MessageRepository.insertInbound
│           │              src/modules/messages/infrastructure/persistence/message.repository.impl.ts:32
│           │              INSERT ... RETURNING id
│           │              Unique constraint on whatsapp_message_id for dedup
│           │              tx: none  ← ✗ SPLIT TRANSACTION with the upsert above
│           │
│           ├─ [use-case] GenerateReplyUseCase.execute
│           │              src/modules/ai/application/use-cases/generate-reply.use-case.ts:18
│           │              │
│           │              ├─ [db read]  ProductRepository.findForTenant
│           │              │             Cached via Redis, TTL 5min (product.cache.ts:19)
│           │              │             tx: none
│           │              │             p95: unmeasured
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
│           │                             tx: none ✓ (no DB transaction held across this call)
│           │                             Failure: ClaudeTimeoutError → caller falls back to tenant.fallback_reply
│           │                             Gap: ✓ resilient
│           │
│           ├─ [external] WhatsAppSenderService.sendText  ← CRITICAL BOUNDARY
│           │              Meta Graph API v20 via fetch
│           │              Timeout: 5s
│           │              Retry: 1 (idempotent — per Meta docs with an idempotency header)
│           │              Metric: whatsapp_send_total{status}
│           │              tx: none ✓ (no DB transaction held across this call)
│           │              Failure: log + metric + proceed (don't crash webhook)
│           │              Gap: ✗ no circuit breaker → if Meta is down for 30m, every request keeps timing out
│           │
│           └─ [db write] MessageRepository.insertOutbound (with tokens + cost)
│                         Subscriber: UsageMeter.record → usage_logs aggregated row update
│                         tx: none  ← ✗ third separate commit; if this fails after the
│                             external send succeeded, the customer got a reply we have no record of
│
└─ [response] 200 OK (always, unless signature/parse failure)
              Budget: Meta's documented webhook timeout (see provider docs, cite the version);
              actual end-to-end latency: unmeasured — no span on the entry point.
```

## Summary report

```
## /trace-flow — POST /webhooks/whatsapp

**Entry:** WhatsAppWebhookController.handle
**Exit:** 200 OK
**Latency:** unmeasured — no histogram or span on the entry point (see Gaps #1)
**Cost per call:** unmeasured — token budget is capped in source (`prompt-builder.ts:44`: ≤3000 in / ≤300 out) but no usage row or price source was read

### External boundaries

Every column here is a **literal read from source** — that is why the table is admissible without measurement. Cite the `file:line` of each value; a blank cell means "no such literal exists", which is a gap, not an unknown. Latency and cost are deliberately absent: they are not derivable from source (§ Provenance rule).

| Call | Timeout | Retry | Circuit breaker | Trace | Metric | Fallback | tx held? |
|---|---|---|---|---|---|---|---|
| Claude | 3s ✓ `claude-client.ts:31` | 0 ✓ | ✗ | ✓ | ✓ | ✓ tenant.fallback_reply | no ✓ |
| Meta Send | 5s ✓ `whatsapp-sender.service.ts:38` | 1 ✓ | ✗ | ✓ | ✓ | log only | no ✓ |

### Gaps found
1. **[HIGH]** **Split transaction across three writes** — `conversations` upsert (`conversation.repository.impl.ts:24`), `messages` inbound insert (`message.repository.impl.ts:32`) and `messages` outbound insert commit separately with no transaction and no compensation. A failure after the external send leaves a reply the customer received and we have no record of.
   Fix: wrap the pre-send writes in one transaction, keep the external call OUTSIDE it, and record the outbound message through an outbox row committed with the same transaction (`ai/patterns/transaction-boundary.md`, `outbox.md`).
2. **[MEDIUM]** No circuit breaker on Meta Send — an outage causes repeated timeouts at the configured 5s.
   Fix: a breaker wrapper around the client; threshold + cooldown per the project's resilience convention.
3. **[MEDIUM]** No metric or span on the entry point — this flow's end-to-end latency and cost cannot be stated, only guessed. That is why two lines above read `unmeasured`.
   Fix: `/add-telemetry` on the webhook controller (RED triad + span).
4. **[LOW]** ProductRepository cache invalidation: the 5min TTL (`product.cache.ts:19`) may serve stale for up to 5min after a write.
   Fix: explicit invalidation on product write via subscriber.

### Tenant isolation
✓ TenantContext wraps all downstream. All queries filter by tenant.

### Transaction boundaries
✗ Three writes, three commits, no transaction (Gap #1). External calls correctly sit outside any transaction.

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
- **Every number carries its source or reads `unmeasured`.** Source yields structure, not measurements.
- **Every step carries a `tx:` value.** Two writes in different transactions are not atomic, however adjacent they look.
- External boundaries annotated with timeout / retry / circuit-breaker status.
- Observability gaps called out explicitly.
- Use for ONE flow at a time — don't try to map the whole app.
- Flag any path without error handling / idempotency / tenant filter.
