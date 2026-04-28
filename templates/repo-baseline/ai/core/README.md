# ai/core/

The IMMUTABLE foundation — domain language, architecture invariants, base abstractions. Files here are the ground truth other docs reference.

## What goes here

- `glossary.md` — domain entities + vocabulary (populated from `business-domains/<domain>/glossary.md` if a business domain was detected).
- `entities.md` — top-level entity diagram + relationships (ERD-style or text).
- `stakeholders.md` — roles + their workflows (from `business-domains/<domain>/stakeholders.md`).
- `invariants.md` — system-wide rules that MUST hold (e.g., "every order has a tenant_id", "no PHI in logs").
- `architecture-overview.md` — high-level architecture if `ai/architecture.md` is too detailed for one-page reference.

## How to use

- New team member's first read.
- Reference from `CLAUDE.md`, `AGENTS.md`, agent prompts, ADRs.
- Update when domain language shifts (rare; major release events).

## Difference from `ai/patterns/`

- `core/` = **what** the system is (entities, vocabulary, invariants).
- `patterns/` = **how** to do things (data access pattern, error handling pattern, etc.).

## Empty?

If this folder is empty, `/setup-project` didn't detect a business domain. To populate:
- Run `/setup-project` with `--domain=<ecommerce|lms|fintech|...>` flag, OR
- Manually copy from `~/.claude/templates/business-domains/<your-domain>/glossary.md` and `stakeholders.md` here.
