---
description: Deep V1↔V2 comparison. Reads BOTH codebases, understands structures, maps every V1 feature to its V2 location (existing or planned), identifies gaps, builds a fresh ledger. Run before /migration-plan. Pairs with --plan flag for plan-only mode.
kind: command
pack: migration
---

# /migration-scan

## The Premise (read this first)

**Read before writing. Cite real V1 paths, never invented.** The scan reads BOTH codebases — actual V1 source, actual V2 source — and writes a ledger row per real V1 feature. No paraphrasing, no "V1 probably has an orders module," no inferred entries from memory. Every ledger row's `v1_path` is a real file at the pinned commit; every `v2_path` is either an existing V2 file or `<unmapped>` (never a fabricated planned path). If V1 source is unreadable for a module, halt and surface — do NOT silently drop features.

The deep-comparison entry point. Run this FIRST in a V2 repo that needs to absorb V1.

**Trust nothing.** This command does NOT take any prior "ported" status as truth — every feature is freshly compared against V1 behavior. The ledger that comes out reflects current reality, not history.

## When to use

- Starting a V1→V2 migration for the first time.
- Resuming a partial migration that was abandoned (status drift).
- After major V2 architectural change — re-comparing what's still in parity.
- After major V1 change — checking what newly diverged.

## When NOT to use

- Greenfield project (no V1) → no migration; skip the migration pack entirely.
- Already-finished migration → use `/migration-final` instead.

## Project-specific anchors (Phase 4.6 fills these)

> - **V1 root**: `<extracted from .claude/_extracted-codebase.md § Migration>`
> - **V2 root**: `<this repo's root>`
> - **V1 framework + version**: `<extracted>`
> - **V2 framework + version**: `<extracted>`
> - **Cutover mechanism**: `<feature-flag | strangler proxy | DNS swap | blue-green | parallel-write | shadow-read>`
> - **Parity test runner**: `<vitest | jest | pytest | playwright | rspec | go test>`
> - **Existing migration commands** (skip-with-redirect map): `<populated from prior /setup-project --include=migration run>`

## Phase 1 — Understand (the ask)

Inputs (no user input needed for the standard path):
- V1 + V2 paths from project anchors above.
- Existing `ai/migration/ledger.md` (read-only — used to identify rows to keep, but every status will be reset to `unverified`).

Optional flags:
- `--scope=frontend` / `--scope=api` / `--scope=all` (default: `all`).
- `--include-deferred` — also re-scan features that were marked `deferred` in a prior run.
- `--since=<commit>` — incremental scan (M12). Only re-evaluate features whose V1 paths changed since the given commit. Existing ledger rows for unchanged features keep their current status (don't reset to `unverified`). Use on large repos (200+ features) where re-auditing everything is expensive. Without this flag, every row resets to `unverified` (the safe default for "trust nothing").
- `--include-deprecated=<re-scan|skip>` — when an existing ledger has rows with `status: deprecated`, decide whether to re-evaluate them (`re-scan`, e.g., the deprecation ADR was rejected) or skip them (`skip`, the default — deprecation is permanent).
- `--include-dead` — opt-out of the dead-code halt. Forces queueing of features that the 6-axis reachability check flagged as dead (zero callers across app source / tests / cron / route registration / infra / production telemetry). REQUIRES paired `--caller-evidence=<path:line>` for each forced row, OR a `caller_evidence:` field in each row's prior ledger note. Use sparingly — defeats the no-zombie-port rule. Logged in `ai/migration/_history.md` for audit trail.
- `--external-consumer=<feature-list>` — mark specific features as having external consumers (e.g., a public API consumed by a sibling repo, a library exported for downstream use). External-consumer features bypass axis 1 (V1 internal callers) but still require ≥ 1 axis to show alive. Comma-separated list of feature IDs.
- `--in-development=<feature-list>` — mark features as "in development, not yet wired up" — these look identical to dead code but ARE going to ship. Bypasses the dead-code halt for these specific IDs. Comma-separated.
- `--workspace` — produce a workspace-level ledger that aggregates per-repo ledgers in a multi-repo migration. Detects sibling repos via workspace-baseline's `PROJECTS.md` or `SIBLINGS.md`. (M12)

## Phase 2 — Organize (decompose the work)

Four parallel scans (Explore subagents, capped per `--max-subagents`):

1. **V1 inventory** — every page, route, endpoint, command, scheduled job, queue consumer.
2. **V2 inventory** — same shape, current state.
3. **V1↔V2 mapping** — for each V1 entry, identify the corresponding V2 entry (or absence).
4. **V1 dead-code reachability** — for each V1 feature in the inventory, run the 6-axis reachability check (per `migration-discipline.md § What counts as dead V1 code`):
   - Axis 1: app source callers (`git grep -F` for the feature's exported symbols / route paths / endpoint names across V1's app source, excluding the feature's own files + tests).
   - Axis 2: test references (same grep across V1's test directories; the feature's own unit test does NOT count as a caller).
   - Axis 3: cron / scheduler config references.
   - Axis 4: route / API / event-bus registration.
   - Axis 5: infra / deploy config references (Dockerfile, k8s, terraform, CI workflows).
   - Axis 6: production telemetry (if observability link exists in `_extracted-codebase.md`): zero invocations / zero log lines for ≥ 90 days.
   A feature is dead iff **all 6 axes** report zero (or axes 1–5 if telemetry is unavailable). Flag dead features for halt unless `--include-dead` / `--external-consumer` / `--in-development` covers the feature.

## Phase 3 — Retrieve (read the right context)

For each subagent's scan:
- Read framework/router config (e.g., `app/`, `pages/`, `urls.py`, `routes.rb`, NestJS modules).
- Read manifest (`package.json`, `requirements.txt`, etc.) for version + dependency surface.
- Sample 2-3 representative files per module to understand conventions in use.

For V2 specifically — also read:
- `ai/architecture.md` (declared module boundaries).
- `ai/conventions.md` (V2's naming + structure rules).
- `.claude/rules/migration-discipline.md` (parity contract).
- `ai/patterns/v1-patterns-crossref.md` (existing V1↔V2 mapping if present).

## Phase 4 — Generate (produce the output)

### Output 1: `ai/migration/scan-report.md`

Deep report with:

```markdown
# Migration scan report — <YYYY-MM-DD>

## V1 structure (detected)
- Framework: <name + version>
- Module layout: <description>
- Routing: <where routes live>
- Data layer: <ORM / repository pattern / raw>
- Conventions: <key naming + structure rules>

## V2 structure (detected)
- (same fields)

## Structural deltas (V1 → V2)
| Concern | V1 | V2 | Migration impact |
|---|---|---|---|
| Routing | <e.g. pages/> | <e.g. app/ App Router> | Every page has a route shape change |
| Data layer | <e.g. ActiveRecord> | <e.g. Prisma> | Every query rewrites |
| Auth | <e.g. Devise> | <e.g. NextAuth> | Cross-cutting; do first |
| ... | | | |

## Feature inventory
| ID | Feature | V1 path | V2 path (existing or planned) | V2 status | Parity test | Notes |
|---|---|---|---|---|---|---|
| F001 | auth-login | <v1/path> | <v2/path or planned> | unverified | missing | |
| F002 | order-create | <v1/path> | <v2/path or planned> | unverified | missing | |
| ... | | | | | | |

Total features: <N>
By domain: auth=<N>, tenant=<N>, orders=<N>, ...

## Dead V1 features (excluded from port queue)
> 6-axis reachability check at v1_commit_pinned: <sha>. Features with zero callers across all axes (app source / tests / cron / route registration / infra / production telemetry). Excluded from migration; deleted directly during V1 retirement. Override per-feature via /migration-scan --include-dead --caller-evidence=<path:line>.

| ID | Feature | V1 path | Axes (1-6) | Last invocation (telemetry) | Action |
|---|---|---|---|---|---|
| F087 | legacy-pdf-export | <v1/path> | 0/0/0/0/0/0 | never (or N/A) | status: deprecated; deprecation_reason: dead-v1-no-callers |
| F112 | unused-bulk-import | <v1/path> | 0/0/0/0/0/0 | 2025-08-12 (264 days ago) | status: deprecated; deprecation_reason: dead-v1-no-callers |
| ... | | | | | |

Total dead features: <D> (~<%> of inventory)
Forced-port via --include-dead: <F> (each has caller_evidence in ledger)
Marked --external-consumer: <E>
Marked --in-development: <I>

## Gaps identified
| Feature | Gap kind | Detail |
|---|---|---|
| <id> | missing-in-v2 | V1 has X, V2 has nothing |
| <id> | divergence | V2 implements but behavior differs from V1 |
| <id> | shape-only | V2 file exists but is empty / scaffold |

## Recommended phasing (input to /migration-plan)
- Phase 1 (foundation): auth, tenant, shared infra
- Phase 2 (core flow): orders, cart, checkout
- ... (justification per phase)

Dead features (above) are NOT in any phase — they're excluded from the port queue.
```

### Output 2: `ai/migration/ledger.md`

Flat YAML-ish ledger, one row per feature. Schema from `ai/patterns/migration-ledger.md`:

```yaml
- id: F001
  feature: auth-login
  domain: auth
  v1_path: <v1/path>
  v2_path: <v2/path>
  status: unverified              # never trust prior 'done'
  parity_test: missing
  v1_commit_pinned:
  reachability:                   # 6-axis dead-code check (added 2026-05-02)
    app_source_callers: <N>       # axis 1
    test_references: <N>          # axis 2
    cron_scheduler: <N>           # axis 3
    route_registration: <N>       # axis 4
    infra_deploy: <N>             # axis 5
    production_telemetry: <N | N/A>   # axis 6 (N/A if no observability link)
  notes: ""

- id: F002
  feature: order-create
  ...

# Example dead-code row (excluded from port queue)
- id: F087
  feature: legacy-pdf-export
  domain: reports
  v1_path: <v1/path/to/legacy_pdf.py>
  v2_path: <unmapped>
  status: deprecated
  deprecation_reason: dead-v1-no-callers
  dead_evidence: "6-axis check passed at v1_commit_pinned: abc123 (2026-05-02 scan)"
  reachability:
    app_source_callers: 0
    test_references: 0
    cron_scheduler: 0
    route_registration: 0
    infra_deploy: 0
    production_telemetry: 0       # last invocation > 90 days ago
  parity_test: skip
  notes: "Excluded from port queue. Will be deleted from V1 directly during retirement."
```

### Output 3: Update `ai/migration/_session-digest.md` (or equivalent)

One-line summary: scan complete, N features, M gaps, phases 1..K.

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/migration/scan-report.md` — managed-block markers; re-runnable.
- `ai/migration/ledger.md` — managed-block; existing user-added notes preserved by ID.
- `ai/index.md` — append-once entry pointing to the new ledger + scan report.

## Phase 6 — Validate (verify correctness)

- Every V1 entry has a row in the ledger (no V1 feature dropped).
- Every row has a `v2_path` set (existing OR planned — never blank).
- Every row has `status: unverified` (the contract — trust nothing).
- Cross-reference: every `feature` ID is unique and stable across re-runs.

If any check fails → halt + report.

## Phase 7 — Improve (feed the learning loop)

- If a structural delta surfaced that wasn't in `ai/architecture.md` → flag for ADR.
- If a recurring gap pattern appears (e.g., "every endpoint missing pagination") → flag for `ai/patterns/<name>.md`.
- If an entire V1 module appears to have no V2 home → that's an architectural decision; surface for the user, do NOT silently invent one.

## Output to user

```
Scan complete:
  Features inventoried:    <N>
  V1 → V2 mapped:          <M>
  Gaps found:              <G>
  Recommended phases:      <K>

Reports:
  ai/migration/scan-report.md   (deep analysis)
  ai/migration/ledger.md        (flat status table)

Next: /migration-plan      (consumes scan-report + ledger; produces phased plan)
```

## Mechanical halt — refuse to fabricate ledger rows

Every ledger row MUST trace to a readable V1 source file. Forbidden: writing a row with a `v1_path` that doesn't exist on disk; writing a row inferred from architecture docs or prior conversations without reading V1; using `...`, `etc.`, `and similar` in any row's `feature` or `notes` field. If a V1 module is unreadable (permissions, missing submodule, broken clone) → halt and report; do NOT skip silently and do NOT invent rows. Every row in the output must be re-derivable by another reader given the same V1 commit.

## Hard rules

- **Trust nothing** — every status reset to `unverified`. Even `done` rows from prior runs flip back. The user explicitly opted into this contract.
- **No silent ports** — this command DOES NOT write any code. It only inventories + maps. Porting happens in `/migration-phase`.
- **No drops** — every V1 feature must appear in the ledger. If a feature has no clear V2 home, the row exists with `v2_path: <unmapped>` and `notes: requires architectural decision`.
- **V2 is the new structure** — when mapping, the V2 path follows V2's conventions (App Router, new framework, new module boundaries), not V1's. The migration is not a lift-and-shift.

## Related

- `/migration-plan` — next command in the phased workflow.
- `/migration-status` — light read of the ledger after this command writes it.
- `ai/patterns/migration-ledger.md` — schema for the ledger this command writes.
- `ai/patterns/v1-patterns-crossref.md` — V1↔V2 mapping table this command consumes if present.
- `.claude/rules/migration-discipline.md` — the parity contract enforced downstream.
