# templates/phases/

One file per phase of the `/setup-project` execution flow.

## Contract

- Each phase file is ≤ 500 lines.
- Filename: `phase-{N}-{slug}.md` (e.g. `phase-2-detect.md`).
- Frontmatter:

  ```yaml
  ---
  phase: 2
  name: detect
  inputs: [user-prompt, repo-state]
  outputs: [project-profile.md, detected-tracks]
  exit-criteria: project-profile.md written; at least one track matched OR uncertainty flagged
  ---
  ```

- The orchestrator (`commands/setup-project.md`) imports these in order via `@templates/phases/...`.
- A phase MUST NOT cross-reference another phase by content — only by named output.

## Phases (populated in Milestone 2)

- `phase-1-bootstrap.md` — flag parsing, mode detection (new vs. existing), env sanity.
- `phase-2-detect.md` — codebase signals, business-domain inference, intent capture.
- `phase-3-decide.md` — decision engine: 4 inputs → track selection + tie-break.
- `phase-4-generate.md` — emit artifacts (CLAUDE.md, ai/, .claude/, adapters).
- `phase-5-audit.md` — self-consistency checklist; refuse to report success on failure.
- `phase-6-learn.md` — continuous learning loop wiring (curator agent, digest, budgets).
