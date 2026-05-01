---
name: ai-cost-discipline
description: AI cost discipline
kind: rule
---

# AI cost discipline

## Hard rule

Every LLM call MUST set `max_tokens` (or the SDK's equivalent output cap), MUST be metered (input tokens + output tokens + computed `cost_usd` recorded on the persisted row at write time), and MUST NOT use a flagship model on the per-message hot path. No exceptions, no "temporary" bypass — costs compound silently and at scale every extra 100 input tokens × millions of messages × per-tenant multiplier = real money.

## Must

- **Set `max_tokens` (output cap) on every call.** Default for chat replies: 300–500. For structured extraction: match the schema. CI MUST reject `messages.create(...)` / `chat.completions.create(...)` / equivalent without an explicit cap.
- **Cap total input** ≤ 3000 tokens per call unless the prompt-eval suite documents the trade-off. System prompt + strategy ≤ 500 combined. Dynamic context (products, settings) ≤ 1500 — summarise when exceeded. Conversation history ≤ 800 — window to last N turns; drop older.
- **Default to the cheapest model that passes the prompt-eval suite** (typically Haiku / Gemini Flash / GPT-mini). Escalate only if a feature genuinely requires stronger reasoning, with the choice recorded in an ADR.
- **Record `input_tokens`, `output_tokens`, `cost_usd`** on the persisted row at write time. Cost is computed from a versioned pricing table (`<pricing-path>`, e.g. `infrastructure/<provider>/pricing.<ext>`). Never recompute on read.
- **Cap conversation history** with an explicit `limit` on the recency query — `messages.recent(conversationId, limit=10)`. CI MUST reject calls with a missing or `> 10` limit unless an ADR documents the case.
- **Cap dynamic-list context** (products, search hits, RAG chunks) at a documented size (e.g. ≤ 40 items). The cap lives in the prompt builder, not at every call site.
- **Per-tenant cost alert** wired to billing dashboard — soft notify on plan-overrun, hard suspend on hard-limit breach.
- **Pricing table changes are versioned** — historical rows keep the price actually paid; new rows use new price. Commit message references the provider's pricing-changelog date.

## Must not

- LLM call without an output cap (`max_tokens` / equivalent).
- Unbounded conversation history (full thread on every turn).
- Embed secrets / PII / payment data / auth tokens in the prompt.
- Retry without an explicit policy + cap (prevents runaway billing on a 5xx storm).
- Use a flagship model (Opus / GPT-4-class / Gemini Pro) on the per-message hot path. Reserve flagships for offline tooling (quality grading, analysis, eval).
- Compute cost on read from current pricing — decouples record from truth; pricing changes rewrite history.
- Track tokens only in logs. Logs rotate; rows don't.
- Round cost to 2 decimal places on the persisted row — loses cents over millions of calls. Store ≥ 6 decimal places.
- Charge tenants based on "messages sent" — token variance is 10×.
- Hardcode pricing constants outside the canonical pricing module (`<pricing-path>`).

## Should

- Use prompt caching (provider-side) for stable system / strategy prompts — easy 40–60% input-cost reduction once available in the SDK.
- Serialise dynamic context once per (tenant, version), cache by version, bump version on writes. Target > 95% cache hit on context between consecutive messages of the same conversation.
- Offer a Haiku-tier model per tenant plan; only the paid tiers get Sonnet-class reasoning.
- Embeddings-based retrieval: include only the top-N most-relevant chunks per call rather than the whole catalogue.
- Sample full-prompt logging (debug level only, PII-redacted, ≤ 1% of traffic) — enough for forensics, not enough to leak.
- Track cost-per-tenant-per-day in a materialised view; publish margin (price charged − cost summed) to the finance dashboard.
- Run prompt evaluations (`<commands-path>/prompt-eval.md`) before every prompt change to catch regressions in quality OR cost.

## Review checklist (PRs touching prompt builders / LLM clients)

- [ ] Every `messages.create` / `chat.completions.create` / equivalent has an explicit output cap.
- [ ] Every list interpolated into a prompt is capped (products ≤ 40, history ≤ 10, etc.).
- [ ] No flagship model identifier on the per-message hot path (`opus`, `gpt-4-`, `gemini-1.5-pro`); reserved for `<offline-tools-path>`.
- [ ] No prompt string concatenation outside the canonical prompt-builder (raw template strings in feature code = drift).
- [ ] No PII / secrets / payment data embedded in the prompt.
- [ ] Cost is computed at write time and persisted; reads aggregate, not recompute.
- [ ] Pricing table updates only in `<pricing-path>`; commit message links the provider changelog.
- [ ] Prompt-eval suite (`<commands-path>/prompt-eval.md`) was run; results attached to the PR description.

## Anti-patterns

- **Implicit max_tokens** — provider default is generous (4k–8k tokens). One unbounded reply burns the budget for thousands of capped calls.
- **Full conversation on every turn** — token cost grows linearly with turn count. Window the history.
- **Cost-on-read** — `computeCostUsd(row.input, row.output)` at query time. The stored cost IS the truth; reads aggregate.
- **Pricing constants hardcoded across files** — silent drift when provider updates prices. One source of truth in `<pricing-path>`.
- **Float cost rounded to cents** — drift over millions of calls. Store ≥ 6 decimals; round only at display.
- **Flagship model on hot path** — "just for now". 10× cost. Move to a tier model with eval coverage.
- **Logs as the cost ledger** — rotate / drop / get aggregated away. Persist on the row.
- **Retry without cap** — provider 5xx storm × exponential backoff with no max-attempts = bill spike. Cap attempts (≤ 3 typical).
- **PII in prompt** — user emails / phones / addresses interpolated into system prompts get to provider logs and (sometimes) training. Redact at the prompt-builder boundary.

## Enforcement

- `<commands-path>/token-audit.md` (slash: `/token-audit`) — monthly + before any prompt change. Flags calls without `max_tokens`, missing meter rows, flagship-model identifiers on hot paths, prompt concatenation outside the builder, full-prompt info-level logging.
- `<commands-path>/prompt-eval.md` — runs golden-cases against the real provider; gates every prompt-builder change.
- `<agents-path>/prompt-reviewer.md` — review gate on prompt + LLM-client changes.
- CI grep on `messages.create(` / `chat.completions.create(` / `generateContent(` / equivalent MUST find an explicit output-cap argument; missing → fail.
- Per-tenant daily-cost alert wired to billing dashboard (soft-notify → hard-suspend on plan-overrun).
- TODO: `scripts/validate-llm-call-sites.sh` to AST-scan for missing output caps and ban flagship-model identifiers outside `<offline-tools-path>`.

## Cross-references

- `<patterns-path>/ai-cost-tracking.md` — pricing table shape, write-time cost computation, reports, soft + hard limits.
- `<commands-path>/token-audit.md` — scanner (cost leaks).
- `<commands-path>/prompt-eval.md` — golden-case eval against the real provider.
- `<agents-path>/prompt-reviewer.md` — review gate.
- `<adr-path>/<NNN>-llm-provider-and-model-tier.md` — ADR pinning provider + per-feature model tier.
- `<adr-path>/<NNN>-prompt-cache-strategy.md` — ADR for the prompt-cache + context-versioning strategy.
