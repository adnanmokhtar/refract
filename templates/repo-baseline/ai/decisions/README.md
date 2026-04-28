# ai/decisions/

Architecture Decision Records (ADRs). One file per decision. Append-only — past decisions aren't deleted, they're superseded by new ADRs.

## What goes here

- `0001-clean-architecture.md` — why we chose layered/hexagonal/clean over alternatives.
- `0002-multi-tenant-row-level.md` — multi-tenancy strategy.
- `0003-claude-as-ai-provider.md` — why Anthropic over OpenAI / others.
- `0004-postgres-over-mysql.md` — DB choice.
- ... and so on, sequentially numbered.

## When to write an ADR

Write an ADR when:
- Adopting a new framework / library / service.
- Choosing between two architectural options.
- Deprecating or replacing a major component.
- Setting a policy that will outlast the people in the room (security, retention, isolation).
- Resolving a recurring debate ("we picked X because..., here's why we won't relitigate").

## Format

See `_template.md` in this folder — copy it for any new ADR.

## Naming

- Zero-padded sequential: `0001-...`, `0002-...`, ... up through 9999.
- Kebab-case slug after the number: `0042-shard-by-tenant-hash.md`.
- Don't reuse numbers when superseding — write a new ADR + mark the old one Superseded.

## Lifecycle

- **Proposed** — under discussion; reference in PR for context but not yet binding.
- **Accepted** — current policy. Defaults follow this.
- **Deprecated** — no longer the default but no replacement yet (rare).
- **Superseded by ADR-<NNNN>** — there's a successor; read both for full context.

## Empty?

`repo-baseline` ships only `_template.md` + this README. **Numbered ADRs** appear after `/setup-project` (CREATE) or as your team records decisions — not every ADR example in the list above exists until authored. If empty except templates, run `/setup-project` on a greenfield prompt or add ADRs as decisions land.
