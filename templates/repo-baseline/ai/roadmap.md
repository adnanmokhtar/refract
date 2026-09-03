# Roadmap

Phased delivery — high level only; detailed steps live in `ai/runbooks/phase-*-plan.md` (created per phase).

> **Read by:** sequencing / planning decisions. **Load trigger:** "what's next", phase planning, or deciding whether a request fits the current phase vs the parking lot.

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


## Current phase

- **Phase**: <P1 MVP | P2 | ...>
- **Timebox**: <dates or relative>
- **Link**: `ai/runbooks/phase-<N>-<slug>-plan.md` <or TBD>

## Completed

- <milestone> — <date>

## Next two phases (preview)

### Phase <N+1>: <name>

- **Goal**: <one line>
- **Key deliverables**: <bullets>

### Phase <N+2>: <name>

- **Goal**: <one line>

## Deferred / parking lot

- <item> — <why deferred>

## See also

- `ai/status.md` — in-flight work
- `ai/project-goals.md` — mission alignment
