# templates/examples/

Reference implementations and worked examples loaded ON DEMAND only — never imported from the orchestrator's hot path.

## Why this exists

Before the M2 split, the monolith carried inline examples that were paid for on every invocation. Examples belong here so the orchestrator stays lean.

## Conventions

- One file per example: `<topic>.md`.
- Each example self-contained (no cross-imports between examples).
- Examples are loaded on demand: an agent that needs a concrete reference reads the file directly, or a maintainer cites the path when explaining a pattern. (A dedicated `/setup-project --show-example <topic>` flag is *not yet implemented* — agents access the directory directly via Read.)
- Examples are NEVER auto-loaded into Tier 1 / Tier 2 context.
- The directory currently ships zero `.md` examples — pack `_examples/` directories cover the per-pack examples; this directory is reserved for cross-pack worked examples once the catalog grows.
