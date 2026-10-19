# AI transfer register

Personal data that leaves Quill Desk for a model provider. One row per provider and purpose. Reviewed
by the DPO before a new feature sends a new data category. Last review: 2026-09-02.

| Provider (processor) | Path | Purpose | Data categories sent | Basis | Retention at the provider | DPA |
|---|---|---|---|---|---|---|
| OpenAI, through the company LLM proxy | `apps/api` gateway (`LLM_BASE_URL`) | assistant replies, help-widget answers, ticket tagging | ticket text, customer first name, order numbers | contract (support of the customer's own order) | zero data retention, enterprise agreement | DPA-2025-014 |
| Anthropic | `services/rag` (`ANTHROPIC_API_KEY`) | KB drafting, triage, copilot answers | ticket text, KB article text | legitimate interest (service quality) | 30 days, standard API terms | DPA-2025-021 |

Not covered: phone numbers, dates of birth, postal addresses, internal agent notes, payment data.
A feature that needs one of these opens a DPIA first.
