# ai/dynamic/

Session-scoped state — the parts of the knowledge base that change between sessions. Distinct from `ai/core/` (immutable) and `ai/patterns/` (changes rarely).

## What goes here

### Always-present (continuous-learning files)

- `learned-patterns.md` — emerging patterns being watched for promotion to `ai/patterns/`.
- `drift-log.md` — code-vs-convention divergence findings.
- `interaction-log.md` — high-level summary of completed AI-assisted tasks.
- `feedback-learned.md` — user corrections taken (project-scoped mirror of global feedback memory).
- `decisions-pending.md` — informal decisions waiting to graduate to formal ADRs.
- `vocabulary.md` — project terms whose meaning is not the obvious one; promoted to `ai/core/glossary.md` at 2 independent sightings.

### Session-driven (seeded + appended)

- `session-log.md` — stub header in `repo-baseline`; auto-appended by the `Stop` hook (`update-session-log.sh`). Each session adds a brief entry: timestamp, branch, files changed.
- `changelog.md` — stub header in `repo-baseline`; appended by `post-commit-learn.sh` / `post-merge-learn.sh` and curated periodically.
- `todos.md` — active tasks across sessions. Promoted to issues / runbooks when bigger.
- `decisions.md` — session-local working notes (informal scratch). Use `decisions-pending.md` for actual decisions awaiting ADR.

## How to use

- **Read** at session start (the `session-start.sh` hook surfaces the latest entries).
- **Write** as you work — append-only is the default.
- **Prune** monthly — these files grow without bound otherwise.

## Distinction from formal records

| File here | Promoted to |
|---|---|
| `decisions.md` entry survives a week → still relevant | Formal ADR in `ai/decisions/` |
| `todos.md` task spans multiple sessions | Issue tracker / runbook |
| `changelog.md` of meaningful API change | `ai/status.md` Recent Changes section |

This folder is the WORKING DRAFT; permanent knowledge lives in `core/`, `decisions/`, `patterns/`, `runbooks/`.

## Hook behavior

- `update-session-log.sh` (Stop hook) appends to `session-log.md` if 5+ files changed.
- `session-start.sh` (SessionStart hook) reads the last few entries to brief the new session.

## Empty?

`session-log.md` / `changelog.md` ship with placeholder headers so hooks can append immediately. Other session-driven files (`todos.md`, `decisions.md`, …) may still be created lazily by hooks or humans.
