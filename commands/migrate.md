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
/migrate <modules-root>/orders/            # explicit path
/migrate "everything except admin"         # exclusion-by-description
```

## What happens internally

The agent does ALL of this silently — you don't see it:

1. **Scan** — reads V1 + V2 source for the scope. Builds a feature inventory + dead-code reachability check (skips dead V1 code per discipline). Handles deep nav tree (tabs, sub-tabs, modal-shell tabs — not just routes). For each leaf-component pair, run the validator's `extract_inventory_primitives <file> <PROJECT_KIND>` helper to extract a stack-aware structural inventory: counts of form fields, dropdowns, buttons, click handlers, permission gates, tabs, route definitions, conditional renders (frontend); route handlers, DTO classes, auth guards, validators, service methods, exception throws, db queries, event emissions (backend); table definitions, foreign keys, indexes, constraints, migration files (data); screen counts, text inputs, navigation routes, native bridge calls, platform branches (mobile). The PROJECT_KIND from `_v2-anchors.md` selects the right primitive set automatically. Tier promoter: if ANY primitive's V2 count is < 70% of V1's count (V1 ≥ 5 instances), auto-promote tier from `trivial` → `standard`. Primitive-count differential is a stronger signal than raw LOC ratio because it tracks meaningful structure (a verbose V1 file with the same field count as V2 is parity, not drift).
2. **Resolve scope** — if `<scope>` is a description, semantic-resolve to V1 + V2 source paths via codebase-profile + idioms.
3. **Plan internally** — group features by dependency. Foundation first (auth, tenant, shared). Heavy-tier work isolated. NO phase output to user.
4. **Multi-agent parallel port** — dispatch one agent per feature. Each agent runs the per-feature loop: read V1 contract → port to V2 (V2 structure, V1 behaviour) → verify (lint, typecheck, scoped tests) → commit. For UI-leaf rows (v2_path with the project's UI-leaf extension per `_extracted-codebase.md § Stack`), the audit MUST emit per-axis enumeration tables with `<v1-path:line>` and `<v2-path:line>` citations on Form fields, UI affordances, Event handlers, and Per-button permission gates — regardless of PARITY or DRIFT verdict. Writing "clean" under an axis without the enumeration table is a Trusted-Summary failure and HALTS via `check_per_axis_enumeration`. PARITY claims pay MORE enumeration cost than DRIFT, because PARITY needs to convince the validator that the auditor actually compared the surfaces.
5. **Self-resolve common questions** — V1-parity is the default. Cosmetic deviations: V1 wins, no questions. Locale-key drift: V1 wins. V2-only-extras: removed unless an accepted ADR exists. Permission gates: match V1. **Navigation restructuring (page→tab, tab→page, tab addition, tab removal, sidebar reorder): V1 wins unconditionally.** A V2 tab that consolidates a V1 separate page, or a V2 page that splits a V1 tab, is drift — not an enhancement. Only an accepted ADR with `user_decision_quote` can keep it.
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
- `--re-detect-fields` — mechanical field-by-field diff per leaf-component pair (extracts every Vue `v-model`, React controlled-field binding, Svelte two-way bind, Angular `ngModel` / reactive forms, plain `<input>` / `<Dropdown>` / `<InputSwitch>` / `<TranslatedInput>` / `<FormField>` / schema-bound field from V1+V2) and emits the comparison table directly into the audit. Removes auditor judgement from the Form fields axis. Recommended ON for form-heavy modules.

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

Started: <YYYY-MM-DD>
V1 root: <v1-project-root>/
V2 root: src/

## Summary
- Total areas:   22
- Done:           5
- In progress:    1 (orders — paused mid-port)
- Pending:       14
- Blocked:        2 (cross-repo)

## Areas

### profile [done] (<YYYY-MM-DD HH:MM>, 8m 24s)
- Files walked: 28 (page + 4 tabs + 3 sub-tabs + 5 modals + 6 components)
- Findings closed: 24 / 27
- Halts: 3 (resolved by user)
- Commits: 24

### notifications [done] (<YYYY-MM-DD HH:MM>, 6m)
- ...

### domain-settings [in-progress]
- Started: <YYYY-MM-DD HH:MM>
- Paused at: 12 of 18 files
- Reason: time-boxed; resume by running `/migrate` again

### orders [pending]
- (will be processed next)

### auth [blocked]
- Reason: cross-repo (<sibling-api-repo> needs `/v2/auth/refresh` endpoint)
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
/migrate --ignore-ledger        # TRULY FRESH SCAN — act as if no migration was ever done
                                #   - Backs up ai/migration/ledger.md → ledger-<iso>.bak.md
                                #   - Backs up ai/migration/final-report.md → final-report-<iso>.bak.md
                                #   - Backs up ai/migrate/progress.md → progress-<iso>.bak.md
                                #   - Re-discovers V1 features from V1 source (NOT from ledger inventory)
                                #   - Re-derives V1 → V2 path mappings from source
                                #   - Re-pins V1 to HEAD (no stale SHA pin)
                                #   - Re-classifies tiers (trivial / standard / heavy) from audit triggers
                                #   - Runs the full per-feature audit loop on every discovered feature
                                #   - WRITES new ledger.md + final-report.md at end (replaces backed-up versions)
                                #   - KEEPS ADR pre-check (accepted intentional V2 improvements preserved; no silent revert)
                                #   - KEEPS 6-axis dead-V1 exclusion (no Zombie Port — dead V1 code still skipped)
                                #   - IMPLIES --re-audit semantics on every row
                                #   - Combinable with <scope>: /migrate the inventory module --ignore-ledger
                                #   - Use when: absolute belt-and-braces verification; suspect original audit was incomplete; treat the project as fresh-from-zero
                                #   - Cost: heavier than --re-audit; re-discovery adds ~30-50% wall-clock vs --re-audit on same scope
/migrate --re-audit             # IGNORE cached verdicts; re-detect EVERY feature
                                #   - Discards `verified` / `done` verdicts in ai/migration/ledger.md
                                #   - Discards ai/migration/final-report.md's authority to skip rows
                                #   - Re-dispatches the per-feature loop (DETECT → DECIDE → FIX → VERIFY → RECORD) on every row, not just pending
                                #   - Rows that re-verify clean stay `verified` (no code change)
                                #   - Rows whose V2 fingerprint diverges from V1 flip to `halted` and are re-fixed in the same run
                                #   - Use this when: ledger says done but you suspect drift OR detector improvements would surface new gaps OR V1 / V2 changed since the original audit
                                #   - Combinable with <scope>: /migrate the orders module --re-audit  (re-audit one area only)
/migrate --re-audit --include-superseded  # re-audit even rows marked `superseded` or `deprecated` (rare; typically dead V1 code)
/migrate --restart              # WIPE progress, start over from the beginning
                                #   - Backs up current progress to ai/migrate/progress-<iso>.bak.md
                                #   - Resets every area to pending
                                #   - Begins with the first pending area
                                #   - Does NOT revert any commits already made (use git for that)
                                #   - Does NOT touch ai/migration/ledger.md — that's the discipline ledger and survives across resets
                                #   - For "ignore ledger entirely AND re-audit", combine: /migrate --restart --re-audit
```

### Recovery flags — which one to use

| Symptom | Flag | Effect on `ai/migrate/progress.md` | Effect on `ai/migration/ledger.md` |
|--------|------|-----------------------------------|-----------------------------------|
| Reset area workflow only; keep audit history / ledger authority | `--restart` | Wiped (with backup) | **Untouched** |
| Full re-discovery + replace ledger + final report + progress (belt-and-braces) | `--ignore-ledger` | Backed up then replaced | **Backed up then replaced** |
| Re-run audits on existing ledger rows without wiping progress file semantics | `--re-audit` | Optional touch only | Discards cached “verified” semantics per command prose |
| Merge new V1 features into progress without porting | `--refresh` | Merged | **Untouched** |

**Warning:** `--ignore-ledger` deletes migration narrative authority in the ledger after backup — use when you intentionally want a from-zero audit. **`--restart` alone does not fix stale ledger rows.**

## What you see (output)

End-of-run, the user sees ONE summary block:

```
Migration complete

Scope:               the orders module
Features ported:     12
  <modules-root>/orders/<page-or-leaf>/<feature-list>.<ext>
  <modules-root>/orders/<page-or-leaf>/<feature-detail>.<ext>
  <modules-root>/orders/<components-or-equivalent>/<feature-form>.<ext>
  ... (9 more)

Commits:             12 (one per feature)
Diff:                +847 / -1240 = -393 lines
Tests:               124/124 passing (3 new parity tests)
Wall-clock:          14m 23s

Skipped:             2 features (dead V1 code — no callers)
  F087 (legacy-pdf-export)
  F112 (unused-bulk-import)

Blockers (1):        F045 (order-bulk-update) — needs <sibling-api-repo> refund endpoint shape
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

- **Validator gate is mandatory.** After every per-feature audit produces `ai/migration/audits/<feature>.md`, the agent MUST run `~/.claude/scripts/validate-migration-artifacts.sh --feature <feature>`. The validator's `check_section_0_evidence` halts the run if Section 0 (Navigation Inventory) doesn't contain Layer A route extraction + Layer B per-leaf grep evidence + Leaf-set diff table. A failed validator forces the auditor to re-emit the audit with proper evidence — the run cannot advance until evidence is present. This is the canonical anti-Trusted-Summary protection.
- **Halt #13 (Navigation Inventory) is non-negotiable.** Layer-A-only scans halt at audit time. Per-leaf template grep on every V1 + V2 leaf component is required.
- **`check_inventory_primitives_match` is mandatory.** For every audit, the validator runs `extract_inventory_primitives` on V1 + V2 leaf paths and halts when ANY primitive's count differs by > 30% AND the audit doesn't enumerate the gap with `<path:line>` citations in the relevant axis section. Stack-aware via `PROJECT_KIND`: frontend primitives map to "Form fields" / "UI affordances" / "Event handlers" / "Per-button permission gates" axes; backend primitives map to route-handler / DTO / auth-guard / validator / exception-throw axes. PARITY verdicts contradicted by primitive inventory halt unconditionally — the auditor must either re-classify as DRIFT or explain the count drop with citations (e.g., V1 had dead code, fields are legacy).
- **`check_per_axis_enumeration` (secondary)** still parses axis section headers and halts on hand-wave / shallow `clean` summaries with insufficient citations. LOC ratio is now a backup signal (warns at < 35% with V1 ≥ 400 LOC) — the primary auto-promote driver is primitive-count differential.
- **`check_adr_signoff_completed` is mandatory.** When an audit cites `(per ADR-NNN)` as proof-of-completion, the validator opens the ADR and halts if any sign-off checkbox is unchecked. Prevents the "ADR-as-plan-not-record" amplifier where an audit closes a finding by citing an accepted ADR whose described work was never executed.
- **Gap-count parity is mandatory.** `gaps_in == gaps_closed` enforced before any row advances from `halted` to `done`. Audit finds N drifts → fix step closes N drifts. Nothing left silently.
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
