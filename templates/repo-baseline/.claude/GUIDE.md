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

- `fix-bug.md` — universal reproduce → failing-test → fix → verify workflow. `--plan` handoff; `--fast` emergency-hotfix mode.
- `execute-plan.md` — implement a saved `--plan` file; auto-invokes `/verify-plan`.
- `verify-plan.md` — audit an implementation against its plan; halts on drift.
- `ship.md` — package the working tree into a reviewed PR (stage → commit → push → PR), confirm-gated, never-stage guard, `--cleanup` for stale branches.
- `catchup.md` — reseat context after `/clear`: reconstruct branch state (read mode) or write the `.claude/HANDOFF.md` note (`handoff` mode).

## Skills

_None yet. Add under `.claude/skills/<name>/SKILL.md`._

## Rules

See `.claude/rules/` (and `.claude/rules/README.md` for the two-tier model). The four foundational rules load every session because the project `CLAUDE.md` `@`-imports them (`@.claude/rules/<name>.md`) — files in `.claude/rules/` are not auto-loaded on their own. **Path-scoped rules** (those with `paths:` frontmatter, e.g. `migration-safety.md`) are the exception: `inject-path-rules.sh` injects them on-match instead, so they cost nothing until you edit a file they govern. The always-loaded budget is CI-guarded by `scripts/check-rule-budget.sh`.

## Hooks

- `post-edit-check.sh` — PostToolUse on Edit/Write/MultiEdit. Lints the edited file.
- `format-on-save.sh` — PostToolUse on Edit/Write/MultiEdit. Auto-formats via the project's formatter.
- `auto-test.sh` — PostToolUse on Edit/Write/MultiEdit. Runs the matching test file; silent on success. **Opt-in:** `touch .claude/.auto-test`.
- `pre-edit-guard.sh` — PreToolUse on Edit/Write/MultiEdit. Blocks `.env`, secrets/keys/certs, generated + minified output, lock files, build output, binaries, and edits to hook scripts themselves.
- `secret-scan.sh` — PreToolUse on Edit/Write/MultiEdit. Blocks writes that introduce high-confidence credentials (API keys, tokens, private keys, connection strings).
- `inject-path-rules.sh` — PreToolUse on Edit/Write/MultiEdit. **Context-only** (never blocks): injects a `paths:`-scoped rule from `.claude/rules/` when you edit a file it governs, once per session. See `.claude/rules/README.md`. Opt out: `.no-path-rules`.
- `guard-destructive.sh` — PreToolUse on Bash. Blocks push-to-protected-branch, force-push (allows `--force-with-lease`), `rm -rf` on `/`/`~`/`$VAR`, `DROP`/`DELETE`-without-`WHERE`/`TRUNCATE`, `curl|sh`, `dd`/`mkfs`, `chmod 777`, accidental `publish`. Configurable via `CLAUDE_PROTECTED_BRANCHES`.
- `build-graph.py` (global, `~/.claude/scripts/`) — **not a hook, you call it.** Assembles this project's import graph from `rank-source-files.py` and answers traversal questions the `ai/` tree cannot: `--who-breaks <path>` (every file that reaches it, capped at `--limit`, with the per-hop shape stated first), `--neighbors`, `--path A B`, `--central`. Derived cache at `.claude/_graph.json` (gitignored), fingerprinted on every source file's size+mtime so an edit rebuilds it. TS/JS + Python only; `tsconfig`/`jsconfig` `paths` aliases resolved. An empty answer means no edge RESOLVED, never "safe to change".
- `inject-blast-radius.sh` — PreToolUse (Edit|Write|MultiEdit). **Context-only, never blocks.** When an edit touches a file that at least 5 files import DIRECTLY, injects the dependent count, the per-hop shape and the direct importers, read from `.claude/_graph.json`. Once per file per session. The threshold is on direct importers because transitive reach covers ~90% of files in a monorepo and would fire on every edit. The graph is deliberately allowed to be stale — it goes stale on the first edit of a session — so the injected text says so and points at `build-graph.py --who-breaks` for a fresh answer. **Opt out:** `touch .claude/.no-blast-radius`. **Tune:** `BR_MIN=<n>`.
- `recall-inject.sh` — UserPromptSubmit. **Context-only** (never blocks): BM25-searches this project's existing `ai/` memory with your prompt and injects the top 3 matching POINTERS (`path:line`), once per row per session. Stores nothing and adds no sink — the index is a derived cache at `.claude/_memory-index.json` (gitignored). **Opt-in:** `touch .claude/.recall`. See `/recall` for the manual query.
- `session-start.sh` — SessionStart. Prints branch, uncommitted count, last 5 commits, `ai/status.md` Recent Changes, learning queue.
- `notify.sh` — Notification. Native OS notification (macOS/Linux/WSL) when Claude needs attention.
- `verify-gate.sh` / `update-session-log.sh` — Stop hooks (verify gate + session-log append). The session-log entry also records the harness's own `session_id` + `transcript_path` as POINTERS — the transcript itself is never copied into the repo. The first prompt (≤120 chars) is recorded only under the `.recall` opt-in.

Opt-in flags (create the file in `.claude/`): `.auto-test`, `.recall`. Opt-out flags: `.no-guard-destructive`, `.no-pre-edit-guard`, `.no-secret-scan`, `.no-format`, `.no-path-rules`. Fixture tests: `bash tests/hooks/run.sh` (in the config repo).

## Settings

`settings.json` — allow/deny lists + hook wiring. Safety deny-list is mandatory; do not remove entries.
