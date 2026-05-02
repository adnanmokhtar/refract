---
description: One command V1→V2 port. Deep multi-agent execution. Takes optional scope (whole project OR specific module/page/area). NO phases visible, NO ADRs surfaced, NO ledger talk, NO mid-run questions. Internally runs scan + plan + audit + port + verify in parallel waves with V1 as the production reference (V1 wins on behaviour, V2 wins on structure). Output is brief: features ported, commits, diff stats, test status. The simple-surface alternative to the /migration-scan → /migration-plan → /migration-fast cycle.
kind: command
pack: orchestration
---

# /migrate [<scope>]

## What this does

**Single command. Deep V1+V2 scan + deep compare + port everything to V2.** Whole project or scoped. Multi-agent parallel internally.

The agent:
1. **Scans V1 codebase deeply** — every page, route, endpoint, tab, sub-tab, modal, sidebar item, in-page navigation surface (deep nav tree, not just top-level routes).
2. **Scans V2 codebase deeply** — same depth.
3. **Deep compares** V1 vs V2 — feature by feature, surface by surface, line by line where needed. NOT a summary check; reads source.
4. **Ports everything missing or divergent** to V2, **following V2's structure** (V2's wrappers, primitives, layering, naming).
5. **V1 wins on behaviour**: if V1 has a button, V2 gets the button. If V1 has a permission gate, V2 gets the gate. If V1 returns null, V2 returns null.
6. **V2 wins on structure**: V2's shared components, V2's service layer, V2's lifecycle hooks, V2's idioms.
7. **Doesn't leave anything** — every live V1 feature gets a V2 home. Only dead V1 code (zero callers across all 6 reachability axes) is skipped, with explicit notation.

You see: what got ported, commits, diff stats, test status. NO phases, gates, halts, ADRs, ledger states surfaced.

## When to use

- "Migrate everything from V1 to V2." → `/migrate`
- "Migrate the orders module." → `/migrate the orders module`
- "Migrate just the auth flow." → `/migrate the auth flow including login signup`
- "Re-port the sidebar." → `/migrate the sidebar`

## When NOT to use

- For a single feature with specific control needs → use `/find-and-fix <id>` (advanced).
- For staged-rollout migration with reviewer approval per phase → use the detailed `/migration-fast <N>` flow.
- Mid-feature work / dirty tree → finish first.

## Args

- `<scope>` (optional) — natural-language description OR explicit path. If omitted: whole project.

Examples:
```
/migrate                                   # whole project (every V1 feature)
/migrate the orders module                 # one module
/migrate the auth flow                     # multi-page flow
/migrate src/modules/orders/               # explicit path
/migrate "everything except admin"         # exclusion-by-description
```

## What happens internally

The agent does ALL of this silently — you don't see it:

1. **Scan** — reads V1 + V2 source for the scope. Builds a feature inventory + dead-code reachability check (skips dead V1 code per discipline). Handles deep nav tree (tabs, sub-tabs, modal-shell tabs — not just routes).
2. **Resolve scope** — if `<scope>` is a description, semantic-resolve to V1 + V2 source paths via codebase-profile + idioms.
3. **Plan internally** — group features by dependency. Foundation first (auth, tenant, shared). Heavy-tier work isolated. NO phase output to user.
4. **Multi-agent parallel port** — dispatch one agent per feature. Each agent runs the per-feature loop: read V1 contract → port to V2 (V2 structure, V1 behaviour) → verify (lint, typecheck, scoped tests) → commit.
5. **Self-resolve common questions** — V1-parity is the default. Cosmetic deviations: V1 wins, no questions. Locale-key drift: V1 wins. V2-only-extras: removed unless an accepted ADR exists. Permission gates: match V1.
6. **Halt only on genuine blockers**:
   - Cross-repo dependency (V2 backend route shape changed; needs upstream PR).
   - V1 source genuinely unreadable (broken submodule, missing file).
   - Security-sensitive contract break (auth bypass) — surfaces for user to decide.
   - Otherwise: just port.
7. **Re-detect after each fix** — gaps_in == gaps_closed. Internal mechanic.
8. **Capture parity tests** internally for non-trivial features. User doesn't author them.
9. **Update ledger silently** — recorded for audit trail, not surfaced.

## Pre-requisites

- V1 + V2 source roots set in `_v2-anchors.md` (or `migration-discipline.md` project-specific block).
- `_extracted-idioms.md` OR `codebase-profile.md` populated.
- Mechanical CI green (lint, typecheck, build, tests).
- Working tree clean (or `--allow-dirty`).
- `_v2-anchors.md` should set `v1_status: production-stable` if V1 is in maintenance-only mode (skips V1-side verification halts).

## Optional flags

- `--dry-run` — shows what would be ported, no edits.
- `--allow-dirty` — proceed with uncommitted changes.
- `--max-parallel=<N>` — cap concurrent feature dispatch (default: 6 for trivial, 3 for standard, 1 for heavy).
- `--exclude=<scope>` — exclude specific areas (e.g., `--exclude=admin,internal-tools`).
- `--include-dead` — port dead V1 code too (default: skip per discipline).
- `--surface-blockers` — show every halted row, not just the brief end summary. Use for debugging.

## Progress tracking (multi-day workflow)

Each command writes a single progress file you can refer to across days:

**`ai/migrate/progress.md`** — single source of truth for migration progress.

### How it works

- **First run** (file doesn't exist) → command builds the inventory + writes the progress file with every area marked `pending`. Then runs the first area.
- **Subsequent runs** → command reads the progress file, picks the next `pending` area (or uses your `<scope>` arg to override), does the work, updates the file. Already-`done` areas are skipped automatically.
- **`/migrate --status`** → read-only progress report. No work done. Tells you what's done, what's pending, what's blocked.

### Progress file shape

```markdown
# Migration progress

Started: 2026-05-02
V1 root: ../tenant-portal/
V2 root: src/

## Summary
- Total areas:   22
- Done:           5
- In progress:    1 (orders — paused mid-port)
- Pending:       14
- Blocked:        2 (cross-repo)

## Areas

### profile [done] (2026-05-02 14:32, 8m 24s)
- Files walked: 28 (page + 4 tabs + 3 sub-tabs + 5 modals + 6 components)
- Findings closed: 24 / 27
- Halts: 3 (resolved by user)
- Commits: 24

### notifications [done] (2026-05-02 15:10, 6m)
- ...

### domain-settings [in-progress]
- Started: 2026-05-03 09:00
- Paused at: 12 of 18 files
- Reason: time-boxed; resume by running `/migrate` again

### orders [pending]
- (will be processed next)

### auth [blocked]
- Reason: cross-repo (capsolah-api needs `/v2/auth/refresh` endpoint)
- Tracking: ai/migration/cross-repo-tasks.md XR-007
```

### Daily workflow

```
Day 1:  /migrate                # picks first pending area (e.g., profile), does it
Day 2:  /migrate                # picks next pending (notifications), does it
Day 3:  /migrate                # continues...
...
Day N:  /migrate --status       # see overall progress
        /migrate                # finish remaining
```

You can also override:
```
/migrate the orders module      # skip ahead; do orders specifically
/migrate --status               # just check progress, no work
/migrate --resume               # pick up the in-progress area
/migrate --reset profile        # mark profile as pending again (re-run it)
/migrate --refresh              # RE-SCAN V1 + V2, MERGE into existing progress.md
                                #   - If progress.md missing: builds it from scratch (same as first run)
                                #   - If progress.md exists:
                                #     * new V1 features (added since last scan) → appended as `pending`
                                #     * removed V1 features (no longer in V1 source) → marked `archived` (kept for history)
                                #     * existing rows (done / in-progress / blocked / pending) → preserved untouched
                                #     * dead-V1 reachability re-checked; newly-dead rows flip to `deprecated`
                                #   - Updates Summary counts to reflect new totals
                                #   - NO port work performed; safe to run anytime
/migrate --restart              # WIPE progress, start over from the beginning
                                #   - Backs up current progress to ai/migrate/progress-<iso>.bak.md
                                #   - Resets every area to pending
                                #   - Begins with the first pending area
                                #   - Does NOT revert any commits already made (use git for that)
```

## What you see (output)

End-of-run, the user sees ONE summary block:

```
Migration complete

Scope:               the orders module
Features ported:     12
  src/modules/orders/pages/OrderListPage.vue
  src/modules/orders/pages/OrderDetailsPage.vue
  src/modules/orders/components/OrderForm.vue
  ... (9 more)

Commits:             12 (one per feature)
Diff:                +847 / -1240 = -393 lines
Tests:               124/124 passing (3 new parity tests)
Wall-clock:          14m 23s

Skipped:             2 features (dead V1 code — no callers)
  F087 (legacy-pdf-export)
  F112 (unused-bulk-import)

Blockers (1):        F045 (order-bulk-update) — needs capsolah-api refund endpoint shape
                     → routed to /cross-repo-task XR-007

Next: /migrate the next thing  OR  inspect commits via git log --oneline
```

That's it. No phases, no gates, no halts list, no ADR prompts.

## What you DON'T see

- "Phase 3 of 7 starting"
- "Halt #11 fired on F042; please review"
- "ADR-022 drafted; flip Status: proposed → accepted to continue"
- "Ledger drift detected; rerun /migration-status"
- "Tier promotion needed for F058; halted"

All of that happens internally. The agent makes the decisions per discipline (V1 wins by default; cosmetic differences auto-fix; security-sensitive surfaces). You only see results.

## Genuinely-blocked rows

If a feature genuinely can't be ported (cross-repo dependency, V1 source unreadable, security-sensitive contract break needing user input), it surfaces in the "Blockers" section of the summary with ONE line per blocker explaining why + what to do next. No multi-page halt files.

For each blocker, the agent suggests the resolution path (e.g., "→ routed to /cross-repo-task" or "→ needs ADR for security boundary change").

## Hard rules (internal — invisible to user)

The agent applies these silently:

- V1 is the production reference. No "verify V1 is correct" halts.
- V1 wins on observable behaviour; V2 structure wins on layout / wrappers / lifecycle hooks.
- Dead V1 code is not ported (per discipline § What counts as dead V1 code).
- One commit per feature. Net-lines ≤ 0 for structural ports; functional ports cite idioms.
- Re-detect after every fix (gap-count parity).
- No silent assumptions — every claim cites V1 or V2 source.

These run internally. User doesn't see the policing.

## Failure modes

- **Pre-flight fails** (mechanical red, dirty tree, missing oracle) → halts the whole run with one-line "fix this first" message. No deep work attempted.
- **All features blocked** (cross-repo / unreadable source) → halts; surfaces blockers list.
- **Wall-clock cap** (default 60 min for whole-project, 30 min for scoped) → pauses; surfaces what was done; user re-runs to continue.

## Related (advanced — for power users)

If you want phase-by-phase control, ledger inspection, ADR drafting, or per-feature debugging, these still exist:

- `/migration-scan` — inspect feature inventory.
- `/migration-plan` — see the phasing.
- `/migration-fast <N>` — run one phase.
- `/migration-recheck <description>` — focused area re-port.
- `/find-and-fix <id>` — single feature.
- `/cross-repo-task` — manage cross-repo blockers.
- `/migration-status` — read the ledger.

`/migrate` dispatches all of these silently. Use the detailed commands when you need fine-grained control.
