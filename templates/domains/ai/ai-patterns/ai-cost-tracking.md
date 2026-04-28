# Pattern: AI cost tracking

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
