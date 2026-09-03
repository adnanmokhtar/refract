# Business flows (Tier 2)

Primary user and operational flows. **Auto-filled** at `/setup-project` from `~/.claude/templates/business-domains/<detected>/core-flows.md` when a business domain is detected.

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


## Flow catalog

### <Flow name> (P0 | P1 | P2)

- **Actor**: <role>
- **Trigger**: <event>
- **Happy path**: <3–5 bullets>
- **Invariants**: <what must always hold>
- **Failure modes**: <what can go wrong>

### <Flow name>

- **Actor**: <...>
- **Trigger**: <...>
- **Happy path**: <...>

## Cross-cutting concerns

- **AuthN / AuthZ**: <how flows enforce identity and permission>
- **Multi-tenant** (if applicable): <tenant boundary in each flow>

## See also

- `ai/business-domain.md` — entities and vocabulary
- `ai/runbooks/` — step-by-step operational guides per phase
- `templates/business-domains/<domain>/feature-checklist.md` — product checklist source
