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

Four parallel scans (Explore subagents, capped per `--max-subagents`). **Scans 1–3 walk the FULL navigation tree** — not just top-level routes. Halt #13 in `migration-discipline.md` (Module/page audit missing navigation inventory) depends on this depth.

### Backend / API dir-walk completeness gate (added 2026-05)

For backend projects (`PROJECT_KIND in {backend-*, api-other}`), the "navigation tree" concept maps to **directory tree completeness**. The scan MUST account for every directory containing source code under `v1_root` — every module, submodule, controller cluster, cron handler, queue listener, infrastructure adapter. **This is a HARD HALT**: a V1 directory containing source code that is NOT mapped to either (a) a ledger row OR (b) the scan-report's "umbrella module excluded" list with a stated reason → halts the scan.

Mechanical procedure (run BEFORE writing scan-report):

1. `find $v1_root -type d -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*'` — enumerate every dir.
2. Filter to dirs containing source files (`*.ts`, `*.js`, `*.py`, `*.go`, `*.rb`, `*.java`, etc. per `_extracted-codebase.md § Stack`).
3. Cluster sibling subdirs into module roots (e.g., `apps/master/src/account/master-admin/` → module `master-admin`).
4. For each module root: produce ONE of:
   - A ledger row `F<NNN>` with `v1_path: <dir>` (the normal case),
   - An umbrella exclusion entry in scan-report § "V1 umbrella modules (excluded from ledger; structural-only)" with the reason (`reason: structural-only`, `reason: shared-library-no-features`, `reason: build-tooling-only`),
   - A dead-code entry per the 6-axis check (axes 1-5 zero) → status: `deprecated`.
5. Emit a count assertion in scan-report: `dir_walk_total: N; mapped_to_rows: M; umbrella_excluded: K; dead_excluded: L; N == M + K + L`.

The scan-report § "V1 structure (detected)" section MUST end with this count assertion. If `M + K + L != N`, halt with the unmapped paths listed.

**Why this matters**: an observed drift class (May 2026) had several V1 directories silently dropped from the ledger because the scan filtered on `.module.ts` (or equivalent module-marker file) presence, and the missed directories had alternative entry-point shapes — HTML/static policies, listener registration via decorator, listener-only sub-clusters under a sibling module, helper-service folders without their own framework module. Pure dir-walk + per-dir source-file presence test catches this; module-marker filtering doesn't.

1. **V1 inventory — DEEP NAV TREE (not just routes)**. Walk every clickable navigation surface, not just top-level routes:
   - Top-level routes (the obvious one — every entry in V1's router config).
   - **In-page tabs** — every instance of the project's tab primitive in V1 templates (concrete tag/component vocabulary varies by stack — see the project's frontend pack rule § Tab patterns). Each tab is a separate inventory entry, not a single "tabs container."
   - **Sub-tabs / nested tabs** — recursively enumerate every nested tab system (a tab containing another tabs container = leaf-level entries for each inner tab).
   - **Sidebar items** — every clickable item in the sidebar/menu/drawer config. Includes collapsible groups and nested items.
   - **Modal-shell tabs** — modals that have their own tab system (settings dialogs, "edit X" multi-step modals).
   - **Accordion groups** — if expanding/collapsing reveals distinct surfaces, each is an entry.
   - **Inner-routes** — child routes / nested routes / dynamic segment routes.
   - **Templates** — every leaf-component / view-template file in V1's view layer (any extension declared in the project's stack), not just "pages". A re-usable template that surfaces unique user-clickable affordances counts.
   - **CRUD action surfaces** — bulk-action menus, row-action dropdowns, context menus reachable from list pages.
   - **Unmapped components check (DEAD-CODE FILTER)** — for each module, list every component file in the module's views/pages folder. Cross-reference against the navigation tree: any file that is NOT (a) imported by a route, (b) rendered by a reachable tab array, (c) conditionally rendered by a reachable interaction state, is flagged as **unmapped / dead-code candidate**. Do NOT port these as standalone features. Example: a parent component defines conditional renders for values 2+3, but the tab array max is 1 — those child components are dead UI code, not standalone pages.
   For each clickable surface: capture the **full click path** from V1 root (e.g., "Settings → Appearance → Colors → Primary tab → Color picker") and the **leaf-level component / route**. The output is a tree, not a flat list — depth-N entries belong to depth-(N-1) parents.
   This is what the user means by "deep nav tree." The discipline halt #13 (Module/page audit missing navigation inventory) DEMANDS this — and it can only deliver if scan-time inventory captured it.

2. **V2 inventory** — same DEEP nav-tree shape; same recursion. Match V1's structure for comparability.

3. **V1↔V2 mapping** — for each V1 leaf-level entry (every tab, sub-tab, modal-tab, sidebar item, in-page navigation surface), identify the corresponding V2 entry (or absence). A V1 leaf with no V2 leaf is a `nav-drift` finding (see migration-discipline.md halt #13). NOT a feature mapping — a navigation mapping.

4. **V1 dead-code reachability + unmapped component filter** — for each V1 feature in the inventory, run the 6-axis reachability check (per `migration-discipline.md § Per-feature audit — 13 hard halts` halt 11) AND the unmapped-component filter from scan step 1:
   - Axis 1: app source callers (`git grep -F` for the feature's exported symbols / route paths / endpoint names across V1's app source, excluding the feature's own files + tests).
   - Axis 2: test references (same grep across V1's test directories; the feature's own unit test does NOT count as a caller).
   - Axis 3: cron / scheduler config references.
   - Axis 4: route / API / event-bus registration.
   - Axis 5: infra / deploy config references (Dockerfile, k8s, terraform, CI workflows).
   - Axis 6: production telemetry (if observability link exists in `_extracted-codebase.md`): zero invocations / zero log lines for ≥ 90 days.
   - **Axis 7 (frontend-specific, added 2026-05-03): navigation reachability** — the component/file is rendered by a reachable tab array, route, or interaction state. A component file that exists in the views folder but is only referenced by unreachable conditional branches (e.g., `selectedItem == 2` when the tab array max is 1) is **navigation-dead** and treated the same as a dead feature. This prevents the Zombie Tab Component anti-pattern.
   A feature is dead iff **all applicable axes** report zero (or axes 1–5 if telemetry is unavailable; axis 7 for frontend components). Flag dead features for halt unless `--include-dead` / `--external-consumer` / `--in-development` covers the feature.

## Phase 3 — Retrieve (read the right context)

For each subagent's scan:
- Read framework/router config (the project's router primitive — concrete file names / patterns vary by stack; see `_extracted-codebase.md § Stack` for the actual locations).
- Read the project's manifest / dependency descriptor for version + dependency surface.
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
| Routing | <V1 routing primitive> | <V2 routing primitive> | Every page has a route shape change |
| Data layer | <V1 ORM / data-access primitive> | <V2 ORM / data-access primitive> | Every query rewrites |
| Auth | <V1 auth primitive> | <V2 auth primitive> | Cross-cutting; do first |
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
- **Oracle drift detection** — at the end of every scan, compare the git hash of `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md` + `ai/patterns/v1-patterns-crossref.md` (if present) against the hashes recorded in the prior scan's `ai/migration/_session-digest.md`. If any oracle file's hash changed:
  1. Surface an "Oracle drift detected" section in `scan-report.md`:
     ```
     ## Oracle drift detected since last scan (2026-04-01)

     Changed oracles:
     - _extracted-idioms.md (hash abc → def): 3 idioms added (BaseCrudService refactored, useApiKeysCrud added), 1 modified (apiClient — interceptor changed), 0 removed.
     - ai/architecture.md (hash xyz → uvw): module boundary moved (orders → orders-v2 namespace).

     Affected ledger rows:
     - F042 (cited apiClient at notes:line) — interceptor change may affect parity tests; recommend /migration-recheck the orders module.
     - F058 (cited ai/architecture.md § orders) — module boundary moved; recommend /migration-replan --include-drifted.
     - ... (8 more)

     Recommended actions:
     - /migration-recheck <area>     # for specific drift impact
     - /migration-replan --include-drifted   # to re-phase affected rows globally
     ```
  2. Update `ai/migration/_session-digest.md` with new oracle hashes for next scan's drift detection.
  3. Do NOT auto-flip status of any row — surface the drift, let user decide.

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
