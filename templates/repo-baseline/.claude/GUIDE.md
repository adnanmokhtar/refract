# .claude/ Guide

Single-page catalog of everything in this repo's `.claude/`.

## Scenarios → tool

| You want to... | Use |
|---|---|
| Run lint/type-check after editing | Automatic via `hooks/post-edit-check.sh` |
| Block writes to sensitive files | Automatic via `hooks/pre-edit-guard.sh` |
| Get a briefing at session start | Automatic via `hooks/session-start.sh` |

## Agents

_None yet. Add under `.claude/agents/<name>.md`._

## Commands

_None yet. Add under `.claude/commands/<name>.md`._

## Skills

_None yet. Add under `.claude/skills/<name>/SKILL.md`._

## Rules

See `.claude/rules/`. The four foundational rules load every session because the project `CLAUDE.md` `@`-imports them (`@.claude/rules/<name>.md`) — files in `.claude/rules/` are not auto-loaded on their own.

## Hooks

- `post-edit-check.sh` — PostToolUse on Edit/Write/MultiEdit. Lints the edited file.
- `pre-edit-guard.sh` — PreToolUse on Edit/Write/MultiEdit. Blocks `.env`, lock files, build output.
- `guard-destructive.sh` — PreToolUse on Bash. Blocks `rm -rf /`, force-push, hard-reset, etc.
- `session-start.sh` — SessionStart. Prints branch, uncommitted count, last 5 commits, `ai/status.md` Recent Changes.

## Settings

`settings.json` — allow/deny lists + hook wiring. Safety deny-list is mandatory; do not remove entries.
