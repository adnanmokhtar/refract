# templates/examples/

Reference implementations and worked examples loaded ON DEMAND only — never imported from the orchestrator's hot path.

## Why this exists

Before the M2 split, the monolith carried inline examples that were paid for on every invocation. Examples belong here so the orchestrator stays lean.

## Conventions

- One file per example: `<topic>.md`.
- Each example self-contained (no cross-imports between examples).
- Examples are loaded by an explicit user request (e.g. `/setup-project --show-example <topic>`) or by an agent that needs a concrete reference.
- Examples are NEVER auto-loaded into Tier 1 / Tier 2 context.
