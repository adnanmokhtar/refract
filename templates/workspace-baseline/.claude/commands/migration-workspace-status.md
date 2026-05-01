---
description: Aggregate per-repo migration ledgers into a workspace-level status report. Use in multi-repo workspaces where the migration spans frontend repo + API repo + worker repo, etc. Read-only — never writes.
kind: command
pack: workspace-baseline
---

# /migration-workspace-status

## The Premise (read this first)

**Cite real ledger rows. Don't aggregate to vagueness.** Every number in the workspace report traces to a parsed source — a specific row in a specific repo's `ai/migration/ledger.md`, with a specific status. Estimates ("about 30 features ported") are a bug; if you can't cite, halt.

**Mechanical halt** — refuse to emit any line that:
- Aggregates a count without the underlying repo + row list available on demand.
- Uses qualifiers (`approximately`, `roughly`, `most`, `a handful`) instead of exact counts.
- Reports a status without naming the repo it came from.

Read-only. Never modifies any ledger.

The cross-repo aggregator. When a migration spans multiple sibling repos, each one runs its own `/migration-scan` + `/migration-plan` + per-phase commands. This command rolls them up into one workspace view.

## When to use

- Workspace has 2+ sibling repos involved in the same V1→V2 migration (e.g., `<admin-v2>` for frontend + `<backend-v2>` for API).
- You need a single status view across repos for a stand-up / weekly report / leadership update.
- You're about to ship a phase that crosses repo boundaries (frontend + API together).

## Pre-requisites

- Workspace `PROJECTS.md` exists and lists the sibling repos.
- Each sibling repo has its own `ai/migration/ledger.md`.
- Sibling repos are accessible at the paths listed in `PROJECTS.md`.

## Phase 1 — Understand (the ask)

Inputs:
- Workspace `PROJECTS.md` — repo inventory.
- Each repo's `ai/migration/ledger.md` (per-repo).
- Each repo's `ai/migration/_history.md` (per-repo).

Optional flags:
- `--repo=<name>` — limit to one sibling.
- `--phase=<N>` — limit to one phase number.
- `--show-deprecated` — include deprecated rows in the output (default: hide).

## Phase 2 — Organize (decompose the work)

For each sibling repo:
1. Read its ledger.
2. Read its history.
3. Compute per-repo summary: counts by status, current phase, blockers.

Then aggregate:
- Cross-repo phase synchronization (if both repos are working on phase N — that's coordinated; if one is on phase 4 and the other on phase 7 — that's drift).
- Cross-repo dependencies (frontend feature F042 depends on API feature F101 — both must be done together).
- Aggregate stats.

## Phase 3 — Retrieve (read the right context)

- Read each ledger via `cat <repo>/ai/migration/ledger.md`. Don't write.
- Don't try to fix anything — this is read-only.

## Phase 4 — Generate (produce the output)

Print to stdout (no writes):

```
Workspace migration status — <YYYY-MM-DD>

Repos: 3
  <admin-v2>     (frontend)
  <backend-v2>            (api)
  workers-v2           (background jobs)

Per-repo summary:

| Repo              | Total | done | unverified | parked | deprecated | failed | Current phase |
|-------------------|-------|------|------------|--------|------------|--------|---------------|
| <admin-v2>  |   42  |  38  |     0      |    1   |     3      |   0    | 5 (passed)    |
| <backend-v2>         |   78  |  12  |    61      |    2   |     3      |   0    | 1 (in flight) |
| workers-v2        |   15  |   8  |     5      |    0   |     2      |   0    | 2 (in flight) |

Cross-repo dependencies blocking progress:
  - <backend-v2>/F101 (auth-token-refresh) blocks <admin-v2>/F042 (already done)  — OK
  - <backend-v2>/F203 (order-export-api) blocks <admin-v2>/F104 (port pending)    — BLOCK
                                                                                       <admin-v2> phase 6 cannot start until <backend-v2> phase 4 ships F203.

Phase synchronization:
  <admin-v2>:  done through phase 5
  <backend-v2>:         currently in phase 1 of 8
  workers-v2:        currently in phase 2 of 4
  Drift: <admin-v2> is 4 phases ahead of <backend-v2>. The frontend ports can't go to V2-only until matching API endpoints are done.

Stalled (no history entry in 14d):
  - workers-v2 phase 2 (last entry 2026-04-10) — owner: charlie
```

## Phase 5 — Update (persist changes to the knowledge base)

This command is **read-only**. No writes.

Optional: append one line to a workspace-level log if `WORKSPACE/.claude/_migration-status.log` exists. Otherwise no writes.

## Phase 6 — Validate (verify correctness)

- Every sibling repo listed in `PROJECTS.md` was reachable.
- Ledger format valid in each (frontmatter parses; required fields present).
- Cross-repo dependency references resolve (a `depends_on: <backend-v2>/F101` reference must point to a real row in <backend-v2>'s ledger).

## Phase 7 — Improve (feed the learning loop)

- If "drift" between repos is consistently >2 phases → flag for project planning. Either pause the leading repo, or fast-track the trailing one.
- If cross-repo blockers cluster on one repo → that repo is the critical path; allocate more resources.
- If a sibling repo's ledger is missing → flag for migration-pack install in that repo.

## Output to user

The table above, plus:
- One-line "what to do next" if a clear next step exists.

```
Recommended next: ship <backend-v2> phase 1 to unblock <admin-v2> phase 6.
```

## Hard rules

- **Read-only.** Never modifies any sibling repo.
- **No silent data fetching from outside the workspace.** Only reads files in repos listed in `PROJECTS.md`.
- **Cross-repo deps are advisory.** This command surfaces them; doesn't enforce. Each repo's own gate enforces locally.
- **Drift is a signal, not an error.** Some drift is normal (frontend often ahead of API or vice versa). Persistent drift > 3 phases is when to act.
