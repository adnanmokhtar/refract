# Business domain (Tier 2)

Compact domain glossary for feature work. **Auto-filled** at `/setup-project` from `~/.claude/templates/business-domains/<detected>/glossary.md` when a business domain is detected.

Last updated: <YYYY-MM-DD>

> **Provenance is mandatory in this file.** Every claim here is about the world outside the
> codebase — a person's goals, a company's strengths, what a customer will pay for — and none of
> it can be read off the repo. Nothing checks it later, and every downstream decision inherits it.
> So each claim carries exactly one marker:
>
> | Marker | Meaning |
> |---|---|
> | `[found: <source>]` | Read from something real and nameable — a doc in this repo, a URL with a date, a transcript, a ticket. Name it. |
> | `[inferred: <basis>]` | Derived from something in the repo. The basis is mandatory: say what it was derived from. |
> | `[unconfirmed]` | Nobody here knows. This is the honest default, not a failure — it becomes a question for the team. |
>
> **A model's recollection is not a source.** `extract-business-context` names this exact failure:
> *"inferring a persona from a logo, a KPI from a hunch, a competitor from training-data memory —
> is the failure mode downstream files inherit forever."* An unmarked claim is invalid; downgrade
> to `[unconfirmed]` rather than dress a guess as a fact. `/setup-project-health` counts these and
> lists every `[unconfirmed]` as a question waiting on a human.


## Domain

- **Detected domain**: <ecommerce | healthcare | fintech | ... | unknown>
- **One-line summary**: <what this product does for whom>

## Primary entities

| Entity | Definition | Notes |
|--------|------------|-------|
| <EntityA> | <definition> | |
| <EntityB> | <definition> | |

## Vocabulary

- **<term>**: <definition>
- **<term>**: <definition>

## Regulatory / compliance hooks

- <None | GDPR | HIPAA | PCI | SOC2 | ...> — <one line how it affects the codebase>

## Detection signals (for agents)

- <signal keywords or patterns that map to this domain>

## See also

- `ai/business-flows.md` — operational flows
- `ai/core/glossary.md` — may mirror or extend this after setup
- `ai/runtime/domain-anti-patterns.md` — domain-specific traps
