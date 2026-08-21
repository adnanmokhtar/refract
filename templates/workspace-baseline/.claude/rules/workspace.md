---
name: workspace
description: Workspace rules
kind: rule
---

# Workspace rules

> **Hard rule (TL;DR):** Cross-repo work follows the registry. Read every affected sibling's root `CLAUDE.md` before editing it. Define the contract first; every repo codes against it, not a paraphrase. The producer (API / shared lib) ships first and backward-compatible; consumers follow and are verified against the shipped shape. Each repo commits separately. No assumed state, no cross-repo commits, no breaking a shape a third repo depends on.

Apply when Claude is rooted at the workspace parent directory.

## Commands

The workspace baseline ships these workspace-level commands (in `.claude/commands/`). They are documented here — this rule is the workspace baseline's command index (the main `docs/COMMANDS.md` covers the project-level `/setup-project` surface, not these):

- `/project-map` — dump the workspace registry or locate a concept across sibling repos.
- `/sync-contract` — after an API contract change, derive the diff from the producer repo, classify each field additive-or-breaking, enumerate consumers across every registered sibling, and propose synced edits. Reports, never applies.
- `/cross-repo-task` — orchestrate a feature spanning multiple sibling repos: contract-first, dependency-ordered, end-to-end verified (producer ships first + backward-compatible; consumers follow).
- `/migration-doctor` — find real ledger / artifact issues across the workspace's per-repo migration ledgers; every finding cites `<repo>/<ledger-row>` or `<repo>/<artifact-path>` (no hand-waves).
- `/migration-workspace-status` — aggregate per-repo migration ledgers into a workspace-level status report; read-only.

## Read-before-edit across repo boundaries

- Per-repo `.claude/rules/` do NOT auto-load across boundaries.
- Before editing any file inside a sibling repo, **first `Read` that repo's root `CLAUDE.md`**. It's your only signal for per-repo conventions at this level.

## Scope

- Only edit files in the registered sibling repos (see `PROJECTS.md`).
- Don't touch sibling directories outside the registry without explicit approval.

## Contract-first

- **Write the contract before any consumer code.** The exact shape of each changed boundary — path + method + request + response + error envelope, or the shared type / schema — is defined and approved first. Every repo codes against that artifact, never a paraphrase or a remembered shape.
- **Classify every contract change `additive` or `breaking`.** A breaking change to a contract consumed by a repo not in scope halts — version it (new endpoint / `/v2`) or widen scope. Never silently change a shape a third repo depends on; grep the workspace for all consumers first.
- **Verify the consumer against the producer's shipped shape**, not the spec on paper — generated/checked types, a real call, or a contract test. A green consumer build alone doesn't prove the shapes match: a hand-written client type compiles happily against a field the producer stopped sending. When no such mechanism exists, the change is `unverified` — report that state rather than implying a check that never ran.

**Tooling for the two halves of this seam** — each present only when its pack is installed in the repo you are standing in:

- `/sync-contract` (here, workspace level) — the fan-out: one producer change → every registered consumer.
- `@api-contract-sentry` (*frontend pack*, inside a consumer repo) — the deep local walk for ONE consumer: every affected client, generated type, store, and page with `<path:line>`.
- `api-contract.md § Evolution rules` (*backend pack*, inside the producer repo) — the additive-vs-breaking classification both of the above defer to.

None is a hard dependency. Absent, the rules above still stand and the work is manual — grep every consumer for the endpoint path, the type name, and the field name, and list what you found. **The same three rules apply inside a single repo** that holds both a producer and a consumer package: `ai/conventions.md § Cross-stack contract verification` carries them there, because a fullstack repo has this seam without the repo boundary that makes it visible.

## Sequencing

- **Producer first, consumers after.** Contract changes go in the shared lib / API repo (in dependency order if more than two repos); consumers build against the new contract.
- **Producer ships backward-compatible (or behind a version/flag).** PRs in different repos can't merge atomically — so a breaking change that requires both to land at once is forbidden. Additive-first lets each consumer PR merge on its own schedule.
- If a frontend-only change would require an API change, flag and stop — don't patch the frontend around a missing API change.
- A new dependency in any repo gets a dependency review before install — no silent cross-repo dependency growth.

## i18n (if multiple locales)

- Any user-facing string added to a frontend MUST be added to BOTH locales.
- Across frontends, prefer the SAME key name for the same concept.

## Commits

- Each sibling has its own git remote.
- Don't commit across repos in one step. Edit all affected repos, then commit each separately.
- Leave commit approval to the user.

## Don't

- Commit across repos
- Skip reading per-repo `CLAUDE.md`
- Code a consumer against an assumed / paraphrased contract instead of the approved artifact
- Ship a breaking contract change that requires two repos' PRs to merge at once
- Silently change a shape a third (out-of-scope) repo depends on
- Add a dependency in any repo without a review
- Assume siblings use the same patterns (v1 vs v2, Options vs Composition API, etc.)
- Apply a frontend change that depends on an unshipped API change
