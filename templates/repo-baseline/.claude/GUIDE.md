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

See `.claude/rules/` (and `.claude/rules/README.md` for the two-tier model). Claude Code loads every rule in `.claude/rules/` without `paths:` frontmatter at launch, every session; the project `CLAUDE.md` `@`-imports list the always-on set for review. **Path-scoped rules** (those with `paths:` frontmatter, e.g. `migration-safety.md`) load when Claude reads a matching file, and `inject-path-rules.sh` adds them before an edit of one, so they cost nothing until you work on a file they govern. The always-loaded budget is CI-guarded by `scripts/check-rule-budget.sh`.

## Hooks

- `post-edit-check.sh` — PostToolUse on Edit/Write/MultiEdit. Lints the edited file.
- `format-on-save.sh` — PostToolUse on Edit/Write/MultiEdit. Auto-formats via the project's formatter.
- `auto-test.sh` — PostToolUse on Edit/Write/MultiEdit. Runs the matching test file; silent on success. **Opt-in:** `touch .claude/.auto-test`.
- `pre-edit-guard.sh` — PreToolUse on Edit/Write/MultiEdit. Blocks `.env`, secrets/keys/certs, generated + minified output, lock files, build output, binaries, and edits to hook scripts themselves.
- `secret-scan.sh` — PreToolUse on Edit/Write/MultiEdit. Blocks writes that introduce high-confidence credentials (API keys, tokens, private keys, connection strings).
- `inject-path-rules.sh` — PreToolUse on Edit/Write/MultiEdit. **Context-only** (never blocks): injects a `paths:`-scoped rule from `.claude/rules/` when you edit a file it governs, once per session. See `.claude/rules/README.md`. Opt out: `.no-path-rules`.
- `guard-destructive.sh` — PreToolUse on Bash. Blocks push-to-protected-branch, force-push (allows `--force-with-lease`), `rm -rf` on `/`/`~`/`$VAR`, `DROP`/`DELETE`-without-`WHERE`/`TRUNCATE`, `curl|sh`, `dd`/`mkfs`, `chmod 777`, accidental `publish`. Configurable via `CLAUDE_PROTECTED_BRANCHES`.
- `test-lane.sh` — PreToolUse on Bash. Heavy test runs take turns, one per machine, so parallel agents cannot exhaust its memory; light runs stay parallel. Blocks a full-suite or e2e command (`npm test`, `pytest`, `go test ./...`, `playwright test`, …) that is not going through the lane and prints the exact re-run line: `.claude/hooks/test-lane.sh run '<command>'`, which waits for a free slot, runs, and exits with the command's status. Not gated: one named test file, a type-check, a lint. A green full-suite run records the exact tree it passed on, so `verify-gate.sh` accepts it instead of running the suite a second time. Lane: `/tmp/claude-<uid>/test-lane` (`CLAUDE_TEST_LANE_DIR`); **Tune:** `CLAUDE_TEST_LANE_SLOTS=<n>` on a machine with RAM for more than one suite. **Opt out:** `touch .claude/.no-test-lane`.
- `build-graph.py` (global, `~/.claude/scripts/`) — **not a hook, you call it.** Assembles this project's import graph from `rank-source-files.py` and answers traversal questions the `ai/` tree cannot: `--who-breaks <path>` (every file that reaches it, capped at `--limit`, with the per-hop shape stated first), `--neighbors`, `--path A B`, `--central`. Derived cache at `.claude/_graph.json` (gitignored), fingerprinted on every source file's size+mtime **and on the resolver's own**, so both an edit and a framework upgrade rebuild it. Setup builds it for you (`run-preflight.sh` step 5/5). TS/JS, Vue/Svelte (`<script>` block only), Python and Dart (`package:<self>/` via pubspec `name`); `tsconfig`/`jsconfig` `paths` aliases resolved. An empty answer means no edge RESOLVED, never "safe to change" — and under a file-based router (Nuxt/Next/SvelteKit/Remix) a page or route file having no importers is CORRECT, because the framework reaches it by path; `--stats` discloses that when it applies.
- `inject-blast-radius.sh` — PreToolUse (Edit|Write|MultiEdit). **Context-only, never blocks.** When an edit touches a file that at least 5 files import DIRECTLY, injects the dependent count, the per-hop shape and the direct importers, read from `.claude/_graph.json`. Once per file per session. The threshold is on direct importers because transitive reach covers ~90% of files in a monorepo and would fire on every edit. The graph is deliberately allowed to be stale — it goes stale on the first edit of a session — so the injected text says so and points at `build-graph.py --who-breaks` for a fresh answer. **Opt out:** `touch .claude/.no-blast-radius`. **Tune:** `BR_MIN=<n>`.
- `recall-inject.sh` — UserPromptSubmit. **Context-only** (never blocks): BM25-searches this project's existing `ai/` memory with your prompt and injects the top 3 matching POINTERS (`path:line`), once per row per session. Stores nothing and adds no sink — the index is a derived cache at `.claude/_memory-index.json` (gitignored). **Opt-in:** `touch .claude/.recall`. See `/recall` for the manual query.
- `session-start.sh` — SessionStart. Prints branch, uncommitted count, last 5 commits, `ai/status.md` Recent Changes, learning queue.
- `notify.sh` — Notification. Native OS notification (macOS/Linux/WSL) when Claude needs attention.
- `verify-gate.sh` / `update-session-log.sh` — Stop hooks (verify gate + session-log append). The gate runs the suite through `test-lane.sh` when it ships, and skips it when the agent's own green run already covered this exact tree. The session-log entry also records the harness's own `session_id` + `transcript_path` as POINTERS — the transcript itself is never copied into the repo. The first prompt (≤120 chars) is recorded only under the `.recall` opt-in.

Opt-in flags (create the file in `.claude/`): `.auto-test`, `.recall`. Opt-out flags: `.no-guard-destructive`, `.no-test-lane`, `.no-pre-edit-guard`, `.no-secret-scan`, `.no-format`, `.no-path-rules`. Fixture tests: `bash tests/hooks/run.sh` (in the config repo).

## Settings

`settings.json` — allow/deny lists + hook wiring. Safety deny-list is mandatory; do not remove entries.
