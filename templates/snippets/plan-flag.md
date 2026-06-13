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

The plan file is the cross-tool handoff artifact: hand it to Cursor / OpenCode / Aider / a teammate, or re-enter it later with `/verify-plan <file>` to audit drift.

## Spelling / aliases

- `--plan` is the universal spelling. Commands MUST accept it.
- Audit-class commands (`/audit`, `*-audit`) historically expose `--plan-only`; treat `--plan` as an accepted **alias** of `--plan-only` for those commands, and `--plan-only` as an accepted alias of `--plan` everywhere else. Same behaviour either way: produce the plan, change nothing.

## What `--plan` is NOT

- It is **not** the default. Simple-surface loop commands (`/optimize`, `/refactor`, `/add-feature`, `/fix-bug`) still run fully and silently without it — surfacing phases/terminology in a normal run is a separate anti-pattern this flag does not introduce.
- It does **not** add a confirmation pause to normal runs. Only `--plan` itself stops before Generate.
