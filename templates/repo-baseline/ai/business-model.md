# Business model

Revenue, pricing, and commercial constraints that affect product and engineering.

> **Read by:** feature work that touches money, plans, or access. **Load trigger:** pricing / billing / entitlement / metering / quota / trial / refund work.

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


## Model type

<Subscription | Usage-based | Transaction fee | Marketplace take | Internal / cost center | ...>

## Pricing / tiers (if applicable)

| Tier | Price | Limits | Notes |
|------|-------|--------|-------|
| <...> | <...> | <...> | |

## Key commercial constraints

- <e.g. trial length, refund policy, billing cycle>
- <...>

## Engineering implications

- <e.g. metering, entitlements, invoice idempotency>

## See also

- `ai/project-goals.md` — mission and non-goals
- `ai/competitive-context.md` — positioning
