# Users and personas

Who uses the system and what they need.

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


## Primary persona

- **Name / role**: <e.g. Pharmacist, Merchant admin>
- **Goals**: <bullets>
- **Pain points**: <bullets>
- **Technical literacy**: <low | medium | high>

## Secondary personas

| Persona | Goals | Notes |
|---------|-------|-------|
| <name> | <...> | |

## Anti-personas (explicit)

- <Who this product is NOT optimized for — avoids scope creep>

## Permission / role model (high level)

- <How roles map to features — link to auth module when known>

## See also

- `ai/business-flows.md` — flows by actor
- `ai/core/stakeholders.md` — stakeholder view from business domain
