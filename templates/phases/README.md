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

## Phases (canonical filenames)

- `phase-0-backup-extract.md` — REFRESH/REFINE backup + knowledge extract before any write.
- `phase-1-detect-mode.md` — flag parsing, mode detection (CREATE / ENHANCE / REFRESH / REFINE), env sanity.
- `phase-2-profile.md` — codebase signals, deep idiom extraction, business-domain inference, intent capture, profile-informed coverage gap check.
- `phase-3-plan.md` — decision engine: 4 inputs → track selection + tie-break + plan + user-approval gate.
- `phase-4-apply.md` — emit artifacts (CLAUDE.md, ai/, .claude/, adapters); body split into 4.0 / 4.1 / 4.2 / 4-templates / 4.6-DEEP / 4.7-DEEP / 4.8-DEEP sub-phase files.
- `phase-5-verify.md` — self-consistency checklist; refuse to report success on failure. Sub-phases: 5.0-retry / 5.1-baseline / 5.5-quality / 5-checklist.
- `phase-6-learn.md` — continuous learning loop wiring (curator agent, digest, budgets).
