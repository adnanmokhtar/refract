---
name: ai-cost-tracking
description: Pattern: AI cost tracking
kind: ai-pattern
---

# Pattern: AI cost tracking

> **Hard rule** — Record `input_tokens`, `output_tokens`, and `cost_usd` (computed at write time from a versioned pricing table) on every outbound model call. Never recompute cost on read; never trust client-supplied token counts.

**When to apply**
- Any product that calls an LLM provider on behalf of tenants/users.
- Margin/pricing/abuse-detection decisions depend on per-call cost.
- Pre-billing P1 phase where the data must accumulate before invoicing exists.

**When NOT to apply**
- Internal-only one-off scripts with no per-tenant accounting.
- Calls where the provider already bills per fixed unit and tokens are irrelevant.
- Embedded model usage (local inference) where cost is hardware time, not tokens.

**Halt conditions / mandatory cites**
- Show the pricing constants at `<path:line>` and the call site that reads them — refuse to ship if either is hand-waved.
- Show the SDK response field (`usage.input_tokens`, `usage.output_tokens`) being read at `<path:line>`. No "we'll log it from middleware" without a cite.
- Cite the column types for `input_tokens`, `output_tokens`, `cost_usd` at `<path:line>` (migration or entity). Float columns for cost = halt.
- Cite where cost is summed for limits/reports at `<path:line>`. If only logs hold token data, halt — logs rotate.
- Grep ban: do not approve "we track cost somewhere" without a concrete file:line for write + read.

## Why

Claude calls are the single biggest variable cost of this product. We need per-message token + USD accounting from Day 1 — even before billing (P2) — so we can reason about margin, price, and detect runaway tenants.

## What we record

Every outbound `messages` row gets:

- `input_tokens` — from Claude response `usage.input_tokens`.
- `output_tokens` — from Claude response `usage.output_tokens`.
- `cost_usd` — computed at write time from current prices (stored in `infrastructure/claude/pricing.ts`).

We store cost at record time, not compute-on-read. Pricing changes → new rows use new price; historical rows keep what was actually paid. This matches how real accounting works.

## Pricing table

Hard-coded constants, one source of truth, versioned when prices change:

```ts
// src/infrastructure/claude/pricing.ts
export const CLAUDE_PRICING = {
  'claude-sonnet-4-5': {
    inputPerMTok:  3.00,   // USD per 1M input tokens
    outputPerMTok: 15.00,
  },
  'claude-haiku-4-5': {
    inputPerMTok:  0.80,
    outputPerMTok: 4.00,
  },
} as const;

export function computeCostUsd(model: keyof typeof CLAUDE_PRICING, inputTokens: number, outputTokens: number): string {
  const p = CLAUDE_PRICING[model];
  const cost = (inputTokens * p.inputPerMTok + outputTokens * p.outputPerMTok) / 1_000_000;
  return cost.toFixed(6);   // 6 dp — we sum thousands of these
}
```

Update this file whenever Anthropic changes prices. Commit message references the Anthropic changelog date.

## Where the accounting happens

Inside `ClaudeClient.generate()`:

```ts
const response = await anthropic.messages.create({ ... });
return {
  text: response.content[0].text,
  inputTokens: response.usage.input_tokens,
  outputTokens: response.usage.output_tokens,
  costUsd: computeCostUsd(model, response.usage.input_tokens, response.usage.output_tokens),
};
```

The use-case forwards these onto the outbound `Message` — never a magic number, always from the Claude response.

## Soft + hard limits (Phase 2 preview)

Not enforced in P1, but the data collection enables it:

- Soft limit: daily tenant spend > `plan.soft_limit_usd` → flag in dashboard.
- Hard limit: monthly tenant spend > `plan.hard_limit_usd` → stop calling Claude, reply with a "we'll get back to you shortly" message, notify tenant admin.

## Reports we'll want (P2)

- Per-tenant, per-day tokens + cost (aggregation query on `messages`).
- Per-tenant margin: price charged – `SUM(cost_usd)`.
- Outlier detection: tenant with 10× median cost this week.

All derivable from `messages` alone — no separate table needed until aggregation gets expensive (P3+).

## Cost-saving levers (in order of when to pull)

1. **Cap `max_tokens` at 512** — done from day 1.
2. **Truncate products in context at 40** — done from day 1.
3. **Prompt caching** — constants (system + sales-strategy) cached cheaply. P2 implement; easy 40-60% input-cost reduction.
4. **Model selection per tenant** — offer Haiku tier for low-value conversations. P3.
5. **Embeddings-based product retrieval** — only include the 10 most-relevant products per message. P3+.

## Anti-patterns

- Computing cost from tokens + current pricing when reading (decouples record from truth).
- Rounding to 2 decimals (loses cents when summed over thousands of messages).
- Tracking tokens only in logs. Logs rotate; rows don't.
- Charging tenants based on "messages sent" alone — token variance is 10×.
