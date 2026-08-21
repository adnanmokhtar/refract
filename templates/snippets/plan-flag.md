---
purpose: Universal `--plan` handoff flag — one canonical definition every command links to instead of restating Phase 3.5. Keeps simple-surface commands simple while honouring the universal-flag contract.
imported-by: every operational command (optimize / refactor / audit / add-feature / fix-bug / migrate / polish / align / …).
---

# `--plan` — universal handoff flag

Every operational command accepts `--plan`. It is **opt-in**: a normal run (no flag) behaves exactly as documented and surfaces no extra ceremony. `--plan` only changes behaviour when the user explicitly passes it.

## Behaviour when `--plan` is set

1. Run the command's **read-only** phases — Understand → Organize → Retrieve (1–3): parse args, scope the work, read the right context. **Make no edits.**
2. Follow **canonical Phase 3.5** (see `templates/canonical-command-template.md` § "Phase 3.5 — Handoff"): expand the mini-plan into a full plan an external tool (or human) could implement.
3. Write it to `.claude/plans/<command>-<short-slug>-<YYYYMMDD-HHmm>.md`, compute the Plan ID, print the path + Plan ID + a one-line summary.
4. **Exit before Phase 4 (Generate).** Do not edit code, do not update `ai/status.md`, do not append to the changelog — nothing was implemented yet.

The plan file is the cross-tool handoff artifact: hand it to Cursor / OpenCode / Aider / a teammate, **execute it in-place with `/execute-plan <file>`** (the Claude-native executor — defaults its sub-agents to Sonnet, so an Opus planning pass hands off cleanly), or audit drift afterwards with `/verify-plan <file>`. The full loop is `<command> --plan` → `/execute-plan` → `/verify-plan`.

## Spelling / aliases

- `--plan` is the universal spelling. Every operational command MUST accept it — and *accept* means a **Phase 3.5 body that writes the file and exits**, not a banner line at the top of the file. A command that does not carry that body must not advertise the flag (see § Where it is real today).
- Audit-class commands (`/audit`, `*-audit`) historically expose `--plan-only`; treat `--plan` as an accepted **alias** of `--plan-only` for those commands, and `--plan-only` as an accepted alias of `--plan` everywhere else. Same *behaviour* either way — produce the plan, change nothing — but **not the same artifact**: an audit-class command's own ranked plan (`ai/audit/plan.md`) is a closure-verb checklist in that command's format and `/execute-plan` rejects it as malformed. Under the universal spelling those commands MUST also write the eight-header file to `.claude/plans/`. An alias that produces an artifact the executor cannot read is a handoff loop that cannot complete.

### Executing a plan

- **`/execute-plan <file>`** is the Claude-native executor (repo-baseline command): it implements a saved plan's Steps + Outputs, honours its Constraints, runs its Verification, and auto-invokes `/verify-plan`. Its executor sub-agents default to **Sonnet** — pair it with an Opus planning pass.
- **`<command> --from-plan <file>`** is the equivalent per-command / adapter spelling of the same "implement from a saved plan" entry (e.g. how the OpenCode adapter exposes it). Both consume the same tool-agnostic plan file and run only the implementation phases (4-6). `/execute-plan` is the preferred Claude form.

## Where it is real today (this repo's global set)

`--plan` is only as real as the command file's own Phase 3.5 body — no harness implements it for you. Current state of `commands/`:

- **Implemented** (a named handoff section that writes the file and exits before Generate): `/align`, `/optimize`, `/polish`, `/refactor`, `/audit` (universal spelling writes the eight-header file *in addition to* its ranked `ai/audit/plan.md`), `/delegate` (the composed brief *is* the plan).
- **Pending** — do not advertise the flag for these until the body exists: `/roadmap`, `/unify-surfaces`, `/task`, `/scaffold-project`, `/setup-project-adapters`, `/setup-project`. **None of the six advertises `--plan` today**, so none is currently the dead flag this list exists to prevent. `/setup-project` did carry `--plan` in its invocation examples with no handoff body; that line was deleted rather than left to grade `fail` under `commands/setup-project-health.md` § per-adapter `--plan` check — its write-nothing preview is `--diff`. `/setup-project-adapters` mentions `--plan` only to TRANSLATE other commands' flag into each adapter (its § "`--plan` flag translation"), which is not self-advertisement.
- **Exempt by contract**: `/do` (a router — the routed command owns the flag), `/refine-prompt` (output-only; its entire product is already a written artifact), `/setup-project-health` (read-only; there is nothing to plan).

This list exists because of the failure mode `templates/canonical-command-template.md` § "Phase 3.5 — Handoff" already names: a banner advertising `--plan` on a command whose body has no Phase 3.5, so the flag parses, nothing branches, and the command implements anyway. Keep the list current when a command gains or loses the body.

## What `--plan` is NOT

- It is **not** the default. Simple-surface loop commands (`/optimize`, `/refactor`, `/add-feature`, `/fix-bug`) still run fully and silently without it — surfacing phases/terminology in a normal run is a separate anti-pattern this flag does not introduce.
- It does **not** add a confirmation pause to normal runs. Only `--plan` itself stops before Generate.
