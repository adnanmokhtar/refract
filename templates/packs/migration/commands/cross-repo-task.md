---
description: Track and drive cross-repo blockers in V1↔V2 migration. When a feature port halts because the V2 backend route shape changed, a sibling repo needs an update, or an external dependency must ship first — this command registers the blocker, names the upstream owner, and provides a workflow to drain it. Without this, cross-repo halts orphan rows in the ledger indefinitely.
kind: command
pack: migration
---

# /cross-repo-task <subcommand>

## The Premise (read this first)

**Cross-repo blockers are real and inevitable.** Real migrations span > 1 repo: the frontend port needs a backend route added; the backend port needs the frontend to stop calling a deprecated endpoint; the V2 cutover needs a sibling service to update its consumer code. When a port halts with `reason: cross-repo`, the row enters limbo without a tracking surface — until this command.

This is the **registry + workflow** for cross-repo blockers. Subcommands:

```
/cross-repo-task register <feature-id> <description> [--upstream=<repo>] [--owner=<name>]
/cross-repo-task list [--status=<open|landed|abandoned>]
/cross-repo-task update <task-id> --status=<status> [--evidence=<url>]
/cross-repo-task close <task-id> --evidence=<url>
/cross-repo-task drain                       # re-runs blocked rows whose tasks are landed
```

Tasks live at `ai/migration/cross-repo-tasks.md` (managed-block; one row per task).

## When to use

- A feature port halts with `reason: cross-repo` — register the blocker so it's tracked.
- The upstream PR / change has landed — update the task status to drain blocked rows.
- Weekly review of blockers — `/cross-repo-task list --status=open` to see what's stuck.

## When NOT to use

- A blocker INSIDE the same repo — that's a regular halt; resolve via `/migration-park` or fix.
- A blocker that's NOT a port-blocker (e.g., a refactor desire) — file a regular ticket.
- A blocker that's actually a feature decision — escalate to ADR via `/draft-phase-adrs`.

## Subcommands

### `register <feature-id> <description>`

Registers a new cross-repo blocker. Args:
- `<feature-id>` — the migration ledger row that's blocked (e.g., `F042`).
- `<description>` — what's needed upstream (e.g., "<upstream-api-repo> needs `GET /v2/orders/<id>/payments` endpoint added").

Flags:
- `--upstream=<repo>` — name of the upstream repo (e.g., `<sibling-api-repo>`). Used for tracking + dispatch.
- `--owner=<name>` — name / handle of the person who owns the upstream change. Required for follow-up.
- `--severity=<low|medium|high|critical>` — default `medium`. Critical = blocking V1 retirement.
- `--upstream-pr=<url>` — if a PR is already open upstream, link it.

Side effects:
1. Generates a task ID (e.g., `XR-001`).
2. Writes the task to `ai/migration/cross-repo-tasks.md` (managed-block).
3. Updates the blocked feature's ledger row with `cross_repo_task: <task-id>`.
4. Sets the feature row's `status: halted` if not already, with `halt_reason: cross-repo (XR-001)`.
5. Surfaces a remediation message — what the upstream owner needs to do, how to update the task when the upstream lands.

Example:
```
/cross-repo-task register F042 "<upstream-api-repo> needs POST /v2/orders/<id>/refund endpoint" \
  --upstream=<sibling-api-repo> \
  --owner=alice \
  --severity=high
```

Output:
```
Task XR-003 registered:
  Feature blocked:    F042 (order-refund)
  Upstream:           <sibling-api-repo> (owner: alice)
  Severity:           high
  Description:        <upstream-api-repo> needs POST /v2/orders/<id>/refund endpoint
  Status:             open

Ledger updated:
  F042: status=halted, halt_reason=cross-repo (XR-003)

Next:
  - Notify owner@<sibling-api-repo> (alice).
  - Track upstream PR via /cross-repo-task update XR-003 --upstream-pr=<url>
  - When upstream lands: /cross-repo-task close XR-003 --evidence=<merged-pr-url>
  - To drain blocked rows after closure: /cross-repo-task drain
```

### `list [--status=<filter>]`

Read-only. Lists all cross-repo tasks with their state.

```
Cross-repo task registry — 2026-05-02

Open (3):
  XR-001 [high]    F042 → <sibling-api-repo>: <upstream-api-repo> needs ... (3d ago, owner: alice)
  XR-002 [medium]  F058 → <v1-deprecation-target>: deprecation header on /api/v1/orders (8d ago, owner: bob)
  XR-003 [low]     F112 → docs-site: V2 endpoint URLs updated (2d ago, owner: carol)

Landed (5):
  XR-004 [high]    F015 → <sibling-api-repo>: tenant-context middleware (closed 2026-04-28)
  ...

Abandoned (1):
  XR-006 [low]    F098 → <v1-deprecation-target>: cleanup (abandoned — V1 retirement scheduled instead)

Total: 9 (3 open / 5 landed / 1 abandoned)
Blocking phase 4 advance: XR-001
```

### `update <task-id> --status=<status> [--evidence=<url>]`

Updates a task's status. Status values:
- `open` — initial state.
- `in-flight` — upstream PR is open and being worked.
- `landed` — upstream PR merged; downstream rows can be drained.
- `abandoned` — decision was made not to proceed (record reason in the update).

Adds evidence URL (PR link, deploy log, ADR link) to the task's history.

### `close <task-id> --evidence=<url>`

Shorthand for `update <task-id> --status=landed --evidence=<url>`. Surfaces:
- Confirmation that the task is closed.
- List of blocked features that can now be drained (`/cross-repo-task drain`).

### `drain`

For every closed task with `status: landed`:
1. Find the feature(s) blocked by that task (via ledger `cross_repo_task` field).
2. For each blocked feature, run `/find-and-fix <id>` to retry the port.
3. If the retry succeeds (gaps closed), the feature flips to `done` automatically.
4. If the retry still halts (new gap surfaced), the feature stays halted with the new halt reason.

Output:
```
Drain — 3 closed tasks, 5 blocked features

XR-004 (closed) blocked: F015, F019
  /find-and-fix F015 → SUCCESS (3 gaps closed)
  /find-and-fix F019 → SUCCESS (1 gap closed)

XR-007 (closed) blocked: F033
  /find-and-fix F033 → HALTED (new reason: parity-test-red, see ai/migration/halts/F033.md)

XR-009 (closed) blocked: F045, F047
  /find-and-fix F045 → SUCCESS
  /find-and-fix F047 → SUCCESS

Drained: 4 features  Halted (new reason): 1 feature
```

## Pre-requisites

- `ai/migration/ledger.md` exists.
- For `register`: the cited feature ID must exist in the ledger.
- For `update`/`close`/`drain`: the task ID must exist in the registry.

## Phase 1 — Understand (the ask)

Inputs depend on subcommand. The command parses args + reads the registry + ledger.

## Phase 2 — Organize (decompose the work)

Per subcommand:
- `register`: validate args → assign task ID → write registry + ledger → surface message.
- `list`: read registry → format output.
- `update` / `close`: validate task ID → update registry → emit history entry.
- `drain`: read landed tasks → for each, dispatch `/find-and-fix` per blocked feature in parallel waves (per-file lock applies).

## Phase 3 — Retrieve (read the right context)

- `ai/migration/cross-repo-tasks.md` — registry.
- `ai/migration/ledger.md` — feature inventory.

## Phase 4 — Generate (produce the output)

For `register`:

```yaml
# ai/migration/cross-repo-tasks.md (managed block)

- id: XR-003
  feature_blocked: F042
  upstream_repo: <sibling-api-repo>
  owner: alice
  severity: high
  description: "<upstream-api-repo> needs POST /v2/orders/<id>/refund endpoint"
  status: open
  registered_at: 2026-05-02T18:30Z
  upstream_pr: ""
  history:
    - 2026-05-02T18:30Z: registered (via /cross-repo-task register F042)
```

## Phase 5 — Update (persist changes)

- `ai/migration/cross-repo-tasks.md` — managed-block updates.
- `ai/migration/ledger.md` — `cross_repo_task: <task-id>` field on blocked rows; `status: halted`, `halt_reason: cross-repo (XR-NNN)`.
- `ai/migration/_history.md` — one line per task lifecycle event.

## Phase 6 — Validate (verify correctness)

- Every registered task has a feature_blocked that exists in the ledger.
- Every blocked feature has its `cross_repo_task` field populated.
- Every closed task has an evidence URL.
- No task is in both `open` and `landed` states (mutex).

## Phase 7 — Improve (feed the learning loop)

- If the same upstream repo accumulates 5+ open tasks, surface "consider a coordination meeting with that team."
- If a task has been open > 30 days, surface "stalled cross-repo blocker; escalate or abandon."
- If a task is closed but the drain step halts the same feature, the closure was premature — flag.

## Output to user

Per subcommand, see Examples above.

## Hard rules

- **No silent registration.** Every task lands in the registry with a task ID. No "I'll remember it" workflow.
- **Closure requires evidence.** No task can flip to `landed` / `abandoned` without `--evidence=<url>`.
- **Drain is idempotent.** Re-running `drain` on already-drained tasks is a no-op.
- **Cross-repo tasks survive `/migration-rollback`.** Rolling back a phase doesn't clear the cross-repo registry; tasks stay tracked across phases.
- **No upstream auto-execution.** This command does NOT push commits / open PRs / send messages to the upstream repo. It tracks; humans drive the upstream work.

## Failure modes

- **Feature ID not in ledger** — register halts with "feature not found; run `/migration-scan` to inventory."
- **Task ID malformed or missing** — update / close / drain halts with the task ID issue.
- **Multiple features blocked by same task** — handled (registry stores them as a list).
- **Task-blocking cycle** (XR-A blocks F1, XR-B blocks F2, F2 blocks XR-A) — surface as a cycle warning; user resolves manually.
- **Upstream owner unresolvable** — register surfaces "owner field empty; assign before drain works."

## Related

### Sibling commands in migration pack
- `/migration-scan` — surfaces features that may need cross-repo work.
- `/find-and-fix <id>` — re-runs a row when its blocker clears (called by `drain`).
- `/migration-park <id>` — alternative when blocker is too vague to register as a task.
- `/migration-status --blockers` — includes cross-repo blockers in the report.

### Patterns
- `ai/patterns/migration-ledger.md` — ledger schema (includes `cross_repo_task` field).

### Rules
- `.claude/rules/migration-discipline.md` — the discipline this command supports.
