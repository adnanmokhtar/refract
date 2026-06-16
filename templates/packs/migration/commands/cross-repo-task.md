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
/cross-repo-task register <feature-id> <description> [--upstream=<repo>] [--owner=<name>] [--contract=<spec>]
/cross-repo-task list [--status=<open|in-flight|landed|abandoned>] [--stale]
/cross-repo-task update <task-id> --status=<status> [--evidence=<url>]
/cross-repo-task close <task-id> --evidence=<url>
/cross-repo-task reopen <task-id> --reason=<text>   # landed/abandoned → open; re-blocks the feature
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
- `--contract=<spec>` — the **exact shape** the downstream needs (endpoint path + method + request + response + error envelope, or the shared type/schema). Captured so `close`/`drain` can check the upstream actually delivered *this*, not just *something*. If omitted, the agent derives it from `<description>` and asks the user to confirm before writing the task.

Side effects:
1. Generates a task ID (e.g., `XR-001`).
2. Writes the task to `ai/migration/cross-repo-tasks.md` (managed-block), including the captured `expected_contract`.
3. Updates the blocked feature's ledger row with `cross_repo_task: <task-id>`.
4. Sets the feature row's `status: halted` if not already, with `halt_reason: cross-repo (XR-001)`.
5. **Generates a paste-ready upstream request** at `ai/migration/cross-repo-requests/<task-id>.md` — a ready-to-file issue / PR description the owner can use verbatim: the exact contract needed, **why** (which downstream feature(s) are blocked and what they can't do until it lands), acceptance criteria (the contract is the spec), and a back-reference to the task ID. This turns "notify the owner" into a concrete handoff instead of a verbal ask.
6. Surfaces a remediation message — points at the generated request file, names the owner, and shows the update/close/drain commands.

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

Upstream request generated:
  ai/migration/cross-repo-requests/XR-003.md  ← paste into the upstream issue/PR

Next:
  - Send the request file to alice@<sibling-api-repo> (it's ready to paste verbatim).
  - Track upstream PR via /cross-repo-task update XR-003 --upstream-pr=<url>
  - When upstream lands: /cross-repo-task close XR-003 --evidence=<merged-pr-url>
  - To drain blocked rows after closure: /cross-repo-task drain
```

### `list [--status=<filter>] [--stale]`

Read-only. Lists all cross-repo tasks with their state. `--stale` filters to open tasks untouched for > 30 days (the Phase 7 escalation threshold) so a weekly review can surface them on demand instead of only as a passive note.

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

**Closure is provisional, not a trust fall.** The evidence URL is recorded, but the real proof the upstream delivered the *right* shape is `drain` re-running `/find-and-fix` against the registered `expected_contract` — a parity halt there means the upstream landed *something*, not what was needed. So: `close` does not flip the feature to `done`; only a clean `drain` does. If `drain` halts on a just-closed task, the closure was premature → `reopen` it (see below) rather than leaving the feature silently stuck.

### `reopen <task-id> --reason=<text>`

Reverses a premature `close` / `abandoned`. Moves the task `landed|abandoned → open` and **re-blocks** its feature(s): the ledger row goes back to `status: halted, halt_reason: cross-repo (XR-NNN)`. `--reason` is required (e.g., "upstream PR merged but response shape omits `currency`; drain halted F042 on parity"). Without `reopen`, a premature closure leaves the feature in a false `done`/limbo state with no recovery path — this closes that hole. The reopen + reason is appended to the task history and `_history.md`.

### `drain`

For every closed task with `status: landed`:
1. Find the feature(s) blocked by that task (via ledger `cross_repo_task` field).
2. **Contract check first** — confirm the upstream actually shipped the task's `expected_contract` (the registered shape is present in the upstream's now-merged code / live API). If the registered contract is NOT satisfied, the closure was premature: surface it and suggest `/cross-repo-task reopen <task-id> --reason=...` instead of retrying a port that can't pass.
3. For each blocked feature whose contract check passed, run `/find-and-fix <id>` to retry the port.
4. If the retry succeeds (gaps closed), the feature flips to `done` automatically.
5. If the retry still halts (new gap surfaced), the feature stays halted with the new halt reason. If the halt is a parity mismatch against `expected_contract`, prompt `reopen` — the upstream landed *something*, not the agreed shape.

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
- `register`: validate args → capture/confirm `expected_contract` → assign task ID → write registry + ledger → generate the upstream-request artifact → surface message.
- `list`: read registry → format output (apply `--status` / `--stale` filters).
- `update` / `close`: validate task ID → update registry → emit history entry.
- `reopen`: validate task ID is `landed`/`abandoned` → move to `open` → re-block the feature(s) in the ledger → append reason to history.
- `drain`: read landed tasks → contract-check each → dispatch `/find-and-fix` per satisfied blocked feature in parallel waves (per-file lock applies); prompt `reopen` for any whose contract isn't satisfied.

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
  expected_contract: "POST /v2/orders/{id}/refund {amount:int, currency:str} -> 201 {refund_id:str, status:str}; 409 on already-refunded"
  request_artifact: ai/migration/cross-repo-requests/XR-003.md
  status: open
  registered_at: 2026-05-02T18:30Z
  upstream_pr: ""
  history:
    - 2026-05-02T18:30Z: registered (via /cross-repo-task register F042)
```

`expected_contract` is the shape `drain` checks before retrying a port; `request_artifact` is the paste-ready upstream request generated at register time.

## Phase 5 — Update (persist changes)

- `ai/migration/cross-repo-tasks.md` — managed-block updates (incl. `expected_contract`, `request_artifact`).
- `ai/migration/cross-repo-requests/<task-id>.md` — the paste-ready upstream request (written at register; the only file outside the managed block).
- `ai/migration/ledger.md` — `cross_repo_task: <task-id>` field on blocked rows; `status: halted`, `halt_reason: cross-repo (XR-NNN)`. `reopen` restores this halt after a premature close.
- `ai/migration/_history.md` — one line per task lifecycle event (register / update / close / reopen / drain).

## Phase 6 — Validate (verify correctness)

- Every registered task has a feature_blocked that exists in the ledger.
- Every registered task has a non-empty `expected_contract` and a `request_artifact` file on disk.
- Every blocked feature has its `cross_repo_task` field populated.
- Every closed task has an evidence URL.
- No task is in both `open` and `landed` states (mutex).
- A feature is `done` only via a clean `drain`, never via `close` alone — `close` records evidence, `drain` proves the contract.

## Phase 7 — Improve (feed the learning loop)

- If the same upstream repo accumulates 5+ open tasks, surface "consider a coordination meeting with that team."
- If a task has been open > 30 days, surface "stalled cross-repo blocker; escalate or abandon." (`list --stale` surfaces these on demand.)
- If a task is closed but the drain step halts the same feature on a contract mismatch, the closure was premature — auto-suggest `reopen <task-id> --reason=...` and do not leave the feature in a false-done state.

## Output to user

Per subcommand, see Examples above.

## Hard rules

- **No silent registration.** Every task lands in the registry with a task ID. No "I'll remember it" workflow.
- **Contract captured at registration.** No task without an `expected_contract` — it's what makes closure verifiable instead of a trust fall.
- **Closure requires evidence.** No task can flip to `landed` / `abandoned` without `--evidence=<url>`.
- **`done` only via `drain`.** `close` records that the upstream merged; only a clean `drain` (contract satisfied + parity green) flips the feature to `done`. A premature `close` is recovered with `reopen`, never left as a false-done.
- **Open tasks block V1 retirement.** `/migration-final` reads this registry and forces INCOMPLETE while any cross-repo task is `open`/`in-flight` (a `critical` one most obviously — but any open blocker means a feature isn't truly ported). Drain or abandon-with-evidence every task before retirement.
- **Drain is idempotent.** Re-running `drain` on already-drained tasks is a no-op.
- **Cross-repo tasks survive `/migration-rollback`.** Rolling back a phase doesn't clear the cross-repo registry; tasks stay tracked across phases.
- **No upstream auto-execution.** This command generates a paste-ready request **file** for the human to send; it does NOT push commits / open PRs / message the upstream repo. It tracks and drafts; humans drive the upstream work.

## Failure modes

- **Feature ID not in ledger** — register halts with "feature not found; run `/migration-scan` to inventory."
- **Task ID malformed or missing** — update / close / drain halts with the task ID issue.
- **Multiple features blocked by same task** — handled (registry stores them as a list).
- **Task-blocking cycle** (XR-A blocks F1, XR-B blocks F2, F2 blocks XR-A) — surface as a cycle warning; user resolves manually.
- **Upstream owner unresolvable** — register surfaces "owner field empty; assign before drain works."
- **Contract not derivable** — if `--contract` is omitted and the description is too vague to derive a concrete shape, register halts and asks for the contract rather than writing an unverifiable task.
- **Upstream landed a different shape** — `drain`'s contract check fails; the task is flagged premature-close and `reopen` is suggested. The feature is NOT marked done.
- **`reopen` on a task that's already `open`** — no-op with a note (idempotent).

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
