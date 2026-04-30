# /migration-doctor

## The Premise (read this first)

**Find real ledger / artifact issues. No hand-waves.** Every finding cites `<repo>/<ledger-row>` or `<repo>/<artifact-path>`. Aggregating to vagueness ("a few rows look stale") is the failure mode this command exists to prevent — that's the same Trusted-Summary pattern the migration pack outlawed.

**Mechanical halt** — the doctor refuses to write findings that:
- Contain `etc.`, `...`, `several`, `a few`, `mostly`, `appears` without a per-row anchor.
- Aggregate counts without listing the underlying rows ("3 stale audits" must list which 3).
- Compare repos without naming both repos and the divergent fields.

Read-only. Never modifies ledgers, audits, or code.

Cross-repo health check for every SahlCart project that has a migration ledger. Runs `validate-migration-artifacts.sh` across all 7 repos, aggregates results, surfaces drift between repos.

## When to use

- **After cutting a release branch** — confirm every repo's migration state is consistent.
- **Before approving a phase exit** in any repo — sibling repos may have downstream impact.
- **Weekly health pass** — surface stale audits, drifted oracles, uncovered failure modes.
- **When a sibling DTO changes** — confirm dependent repos haven't silently regressed.

## What it checks

For each registered SahlCart repo with `ai/migration/ledger.md`:

1. **Per-feature gate**: invoke `~/.claude/scripts/validate-migration-artifacts.sh --all --quiet` in the repo. Captures per-feature pass/fail count + every failure message.

2. **Cross-repo dependency consistency**: parse each ledger row's `dependency:` field (if present); if a row depends on another repo's feature, confirm that other feature's row is `done` OR `intentional-break`.

3. **Sibling drift detection** (frontend pairs only — `tenant-portal` ↔ `tenant-portal-v2`, `master-portal` ↔ `master-portal-v2`):
   - Same feature ID with different `parity_test` state for >7 days.
   - Audit declares parity-clean in one repo but the sibling shows divergence.

4. **Shadow SLA check**: any feature in `state: V2-shadow` for >30 days flagged for cutover decision.

5. **Stale audit aggregate**: count of audits where `audit_date` predates `git log -1 -- <v2_path>` by >7 days.

6. **Workspace orchestrator drift**: `_extracted-codebase.md § Migration` references that no longer resolve (file moved/renamed).

## Repos checked

Per `PROJECTS.md`:

- `capsolah-api/` — V1 API (no ledger expected; reads contract surfaces consumed by frontends)
- `claude-v2/` — V2 API (hex-purity check; ledger if present)
- `tenant-portal/` — V1 frontend (no ledger expected)
- `tenant-portal-v2/` — V2 frontend (full ledger + audits)
- `master-portal/` — V1 frontend (no ledger expected)
- `master-portal-v2/` — V2 frontend (ledger if present)
- `store/` — storefront (no migration; sibling reference only)

A repo without a ledger is skipped silently with a count entry.

## Output format

```
Migration health report — <UTC ISO date>

Per-repo summary:
  Repo                    | Features | Done | Failed | Stale | Shadow>30d
  ──────────────────────  ┼ ──────── ┼ ──── ┼ ────── ┼ ───── ┼ ──────────
  tenant-portal-v2        |       45 |   12 |      0 |     2 |          0
  master-portal-v2        |       38 |    8 |      1 |     0 |          0
  claude-v2               |       60 |   15 |      0 |     5 |          2
  ──────────────────────  ┼ ──────── ┼ ──── ┼ ────── ┼ ───── ┼ ──────────
  Total                   |      143 |   35 |      1 |     7 |          2

Cross-repo dependencies:
  ✓ tenant-portal-v2:F040 → claude-v2:auth-login (done)
  ✗ master-portal-v2:F012 → claude-v2:audit-log (V1-only — blocker)

Stale audits (>7 days vs v2_path):
  - claude-v2:F050 audit_date=2026-04-01; v2_path last touched 2026-04-22
    (re-audit OR re-pin v1_commit)

Shadow >30d:
  - claude-v2:F022 V2-shadow since 2026-03-15 — cutover decision overdue
  - claude-v2:F023 V2-shadow since 2026-03-15 — cutover decision overdue

Sibling drift:
  ✓ tenant-portal ↔ tenant-portal-v2: no divergence detected

Verdict: HEALTHY (1 blocker)
   Run /sync-contract claude-v2:audit-log → master-portal-v2 to clear F012's blocker.
```

## Behaviour

1. Walk `PROJECTS.md` to enumerate registered repos + their root paths.
2. For each repo with `ai/migration/ledger.md`:
   - `cd <repo>` (subshell only — never `cd` in main shell)
   - Run `~/.claude/scripts/validate-migration-artifacts.sh --all --quiet`
   - Capture exit code + last 200 lines of output
3. Parse each ledger to extract `dependency:` fields; resolve cross-repo references.
4. For frontend siblings: read both ledgers + sibling-feature mapping; surface divergence.
5. Print the aggregated report.

## Refusal rules

- This command does NOT write. If the user asks "fix X", refuse and direct them to the per-repo `/migration-phase` or `/port-feature`.
- Surface every issue; do not auto-resolve.
- If a registered repo is not present at the expected path, log + continue (don't halt).

## Related

- `/migration-phase <N>` (per-repo) — runs a phase
- `/migration-gate <N>` (per-repo) — verifies a phase exit
- `/cross-repo-task` (workspace) — multi-repo task orchestrator
- `/sync-contract <api-feature>` (workspace) — propagates API contract change to dependent frontends
- `/workspace-audit` (workspace) — broader workspace shape audit (canonical-shape.md compliance)
- `~/.claude/scripts/validate-migration-artifacts.sh` — the per-repo validator this command aggregates
