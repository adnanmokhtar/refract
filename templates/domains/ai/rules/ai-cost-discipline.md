---
name: ai-cost-discipline
description: AI cost discipline
kind: rule
---

# AI cost discipline

## Hard rule

Every LLM call MUST set `max_tokens`, MUST be metered (input + output + cost on the persisted row), and MUST NOT use a flagship model on the per-message hot path. No exceptions, no "temporary" bypass.

LLM API costs compound. At scale, every extra 100 input tokens × millions of messages × per-tenant multiplier = real money.

## Model choice

- Default: the cheapest model that passes the prompt-eval suite (typically Haiku / Gemini Flash / GPT-mini).
- Escalate to a bigger model only if a feature genuinely requires stronger reasoning. Record the choice in an ADR.
- NEVER use a flagship model (Opus / GPT-4.1 / Gemini Pro) on the hot per-message path — reserve for tooling (offline analysis, quality grading).

## Input budget

- Total input ≤ 3000 tokens per call unless justified.
- System prompt + strategy ≤ 500 tokens combined.
- Dynamic context (products, settings) ≤ 1500 tokens. Summarize when exceeded.
- Conversation history ≤ 800 tokens. Window to last N turns; drop older.

## Output budget

- `max_tokens` ALWAYS set. For chat replies: 300. For structured extraction: match the schema.

## Caching

- Serialize dynamic context once, cache by tenant + version. Bump version on writes.
- Target >95% cache hit on context between consecutive messages of the same conversation.
- Pricing tables cached in constants, not fetched per request.

## Metering

- Every LLM call logs `input_tokens` + `output_tokens` + computed `cost_usd` on the persisted row.
- Monthly `/token-audit` or before any prompt change.
- Alert on per-tenant daily cost exceeding plan allowance (soft → notify; hard → suspend).

## Forbidden

- LLM call without `max_tokens`.
- Unbounded conversation history.
- Embedding secrets / PII in the prompt.
- Retry without explicit policy (prevents runaway billing).
- Flagship models on the hot path.

## Enforcement

- `/token-audit` command (monthly + before any prompt change) — flags calls without `max_tokens`, missing meter rows, flagship-model usage on hot paths.
- CI grep on `messages.create(` / `chat.completions.create(` MUST find an explicit `max_tokens` argument; missing → fail.
- Per-tenant daily-cost alert wired to billing dashboard (soft-notify → hard-suspend on plan-overrun).
- TODO: `scripts/validate-llm-call-sites.sh` to AST-scan for missing `max_tokens` and ban flagship-model identifiers outside `tools/offline/`.
