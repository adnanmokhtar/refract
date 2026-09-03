# `.claude/plans/` — handoff artifacts between planning + implementation

This directory holds **plan files**: structured markdown specs produced by `<command> --plan`. They are the contract between a planning tool (typically Claude Code, in this project's setup) and an implementing tool (Claude Code, OpenCode, Cursor, Aider, a human, or any combination).

## Workflow

```
1. /add-feature "..." --plan        →  writes .claude/plans/<command>-<slug>-<timestamp>.md
2a. /execute-plan <plan-file>       →  Claude-native executor; implements Steps+Outputs, honours
                                        Constraints, runs Verification (executors default to Sonnet)
2b. <or hand off to any tool>       →  OpenCode / Cursor / Aider / a human reads the file + implements
3. /verify-plan <plan-file>         →  diffs actual filesystem vs plan; reports drift; decides verdict
                                        (/execute-plan auto-invokes this at the end)
```

Step 2a is the "Opus plans, Sonnet executes" path: author the plan under Opus (or `opusplan` plan mode), then `/execute-plan` it — its executor sub-agents run on Sonnet. Step 2b is the cross-tool path: the file is self-contained, so any tool or model can implement it.

## Naming convention

```
.claude/plans/<command>-<short-slug>-<YYYYMMDD-HHmm>.md
```

Examples:
- `add-feature-prescription-filter-20260427-1430.md`
- `fix-bug-tenant-leak-on-list-20260428-0915.md`
- `refactor-auth-middleware-20260429-1030.md`

## Plan ID

Every plan has a short hash in its frontmatter (`Plan ID: phc-7f4a`). Use it when:
- Cross-referencing the plan from commits, PRs, or other docs.
- Looking up the plan via `/verify-plan --plan-id <id>`.

## File format (the contract)

Every plan must have these sections:

| Section | Purpose |
|---|---|
| `## Goal` | Objective (the WHY) + the single acceptance criterion (observable "done") + out-of-scope / non-goals |
| `## Context` | Module, layer, conventions, cross-cutting rules, failure-catalog warnings |
| `## Approach` **(optional)** | Chosen design + why + alternatives considered + key risk (omit when the Steps are self-evident) |
| `## Inputs` | Files the implementing tool reads BEFORE doing anything |
| `## Outputs` | Files to CREATE / MODIFY / DELETE — the spec |
| `## Constraints` | DON'T-style rules (`/verify-plan` audits these) |
| `## Steps` | Ordered execution recipe |
| `## Known unknowns` **(optional)** | Decisions deferred to implementation time |
| `## Verification` | Lint / typecheck / test / curl commands to run after implementing |
| `## Status` | Checkboxes the implementing tool ticks off |

**The order above is the contract for a WRITER, and it is not cosmetic.** `## Constraints`
sits before `## Steps` because the executor reads top-down and every Step is bound by them:
`/execute-plan` calls Constraints "hard", halts when a Step as written would breach one, and hands
the **full list** to every parallel sub-agent along with only that agent's slice of the Steps. A
recipe read before its prohibitions is a recipe read twice. The two optional sections have fixed
positions for the same reason — `## Approach` explains the choice before the mechanics, and
`## Known unknowns` sits before `## Verification` because an unresolved one can stop the run
(`/execute-plan` Phase 4: no stated criterion → stop and ask), so it must be read before anyone
starts checking whether the work passed.

**Readers stay tolerant.** `/execute-plan` and `/verify-plan` validate PRESENCE, not order, so a
plan saved before this ordering — or hand-written in another sequence — still runs. Emitting the
order is the generator's job; accepting any order is the executor's.

`/verify-plan` validates this structure; a missing **required** header = malformed plan. The eight required sections are **Goal**, Context, Inputs, Outputs, Constraints, Steps, Verification, Status. `## Approach` and `## Known unknowns` are optional: a plan with them is valid; a plan without them is valid. (`## Goal` is what makes the plan an *implementation* plan and not just a diff recipe — it states what success is, separate from the mechanical `## Verification` commands.)

## Lifecycle

- **Live**: in `.claude/plans/<file>.md` — current handoff target.
- **Fulfilled**: after `/verify-plan` reports `PLAN FULFILLED`, optionally moved to `_archive/<file>.md` (kept for audit trail; gitignored by default).
- **Drifted**: appended with `## Drift notes` section + linked corrections; user decides next step.
- **Violated**: appended with `## Violation log`; either re-implement or write ADR justifying override.

## Gitignore

By default, `.claude/plans/*.md` is gitignored (plans are per-engineer working artifacts, not shared history). This `README.md` is committed; everything else stays local.

If your team wants plans tracked (e.g., as PR-attached design docs), unset the gitignore for the directory and commit plans alongside features.

## Why a directory and not a single file

Concurrent planning: an engineer can have an active feature plan, an active bug-fix plan, and an active refactor plan in flight simultaneously. Each is a separate file with its own Plan ID. `/verify-plan --latest` resolves the most-recent unfulfilled plan; `--plan-id` resolves any specific one.

## When NOT to use --plan

- Trivial changes (one-line fixes, typo corrections) — direct implementation is faster.
- Exploration / spike work where the plan would change as you go — plan formality slows discovery.
- Read-only commands (`/log-tail`, `/find-module`, `/check-health`) — there's nothing to implement.

The plan workflow is for **non-trivial, decomposable, verifiable** work where the spec is worth writing down. Use judgment.
