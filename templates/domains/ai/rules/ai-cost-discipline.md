# AI cost discipline

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
