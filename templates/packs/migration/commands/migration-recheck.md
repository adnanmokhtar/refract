---
description: Independent V1↔V2 spot-check + fix. Accepts a natural-language description ("the sidebar", "the orders module", "customer tabs") OR explicit paths. Scans V1 + V2 source FRESH for the described area, audits parity, fixes drift in V2 to match V1. NO plan dependency, NO phase concept, NO required ledger row. Bypasses the full migration ceremony — just: find the area, audit, fix. Works whether or not the area is in the migration plan / ledger.
kind: command
pack: migration
---

# /migration-recheck <description-or-path> [<more>...]

## The Premise (read this first)

**This is your bypass-the-ceremony tool.** Forget the plan. Forget the phases. Forget whether a ledger row exists or not. You describe a code area; this command finds it in V1 and V2, audits parity fresh, fixes drift. One command, no chain.

What it does NOT do:
- ❌ Read the migration plan to figure out what to do.
- ❌ Care which phase the area belongs to.
- ❌ Require a ledger row to exist for the area.
- ❌ Require the area to have been scanned before.
- ❌ Require any prior `/migration-scan` or `/migration-plan` run.

What it DOES:
- ✅ Resolve your description to actual V1 + V2 source paths (semantic understanding via codebase-profile + idioms).
- ✅ Run a **fresh parity audit** between V1 and V2 source for the area — no cache lookup, no prior-audit reuse.
- ✅ Apply V1-parity edits to V2 (V1 wins on behaviour, V2 wins on structure — same discipline as the rest of migration).
- ✅ Verify (lint + typecheck + scoped tests + re-detect).
- ✅ Commit (one commit per logical fix).
- ✅ **Best-effort ledger update**: if a matching ledger row exists, update its status; if not, leave the ledger alone (no forced row creation unless you pass `--register-ledger`).

Examples:

- `/migration-recheck the sidebar`
- `/migration-recheck the orders module`
- `/migration-recheck the page builder`
- `/migration-recheck the customer tabs in the dashboard`
- `/migration-recheck the navigation header`
- `/migration-recheck <modules-root>/orders/` (paths still work)
- `/migration-recheck "the auth flow including login and signup"` (multi-concept descriptions)

Use this when:
- You want a fast, focused parity check on a specific area without ceremony.
- The area isn't in the migration plan (yet) but you need to re-check it now.
- You suspect drift in something marked done; want fresh verification.
- The full migration plan is paused / abandoned but you still want V1↔V2 parity for one area.

This is the **focused-area** companion to `/migration-fast <N> --re-audit` (which is phase-scoped). Use `/migration-recheck` when:
- You suspect drift in a specific module / page / route after a feature merge.
- You want to re-verify a code area independent of how it was phased originally.
- A bug report points at a UI surface and you want to confirm V2 still matches V1 there.
- The module wasn't in the migration plan (yet) but you need to re-check it now.

**What it does** (per matched feature):
1. Re-detect: re-dispatch `parity-auditor` to compare V1 vs V2 line-by-line.
2. Decide: V1-parity by default (no chatter on cosmetic stuff).
3. Fix: apply V1-parity edits to V2.
4. Verify: re-detect — `gaps_in == gaps_closed`.
5. Record: update ledger row.

Same discipline as `/find-and-fix` (the per-feature loop), just multi-feature + path-scoped.

## When to use

- "Re-check the orders module" — `/migration-recheck the orders module` OR `/migration-recheck <modules-root>/orders/`
- "Re-check the sidebar" — `/migration-recheck the sidebar`
- "Re-check the page-builder" — `/migration-recheck the page builder`
- "Re-check customer tabs" — `/migration-recheck the customer tabs`
- "Re-check store + products" — `/migration-recheck the store and products modules` OR `/migration-recheck <modules-root>/store/ <modules-root>/products/`
- After a feature merge that touched many files in a module, to verify nothing rotted.

## Input forms — description OR path

The first arg can be:

1. **Path** — anything that looks like a path: starts with `src/`, `apps/`, `lib/`, etc., contains `/`, or has a file extension matching the project's stack (declared in `_extracted-codebase.md § Stack`). Used directly as-is.
2. **Description** — anything else. Plain-language description of what to re-check. The agent resolves it to features (see below).

Mixed input is allowed:
```
/migration-recheck the sidebar <modules-root>/orders/
```
→ resolves "the sidebar" to its feature(s), then ORs with the explicit `<modules-root>/orders/` path. Both contribute to the matched-features set.

## When NOT to use

- For a single feature → `/find-and-fix <id>` is more direct.
- For a whole phase → `/migration-fast <N> --re-audit` is the phase-scoped variant.
- For a fresh full-repo sweep → `/migration-scan` then phased flow.
- Mid-feature work (your own dirty diff) — finish the feature first, then recheck.

## Pre-requisites (intentionally minimal)

**Hard requirements** (the command halts without these):
- V1 + V2 source roots accessible (project-specific anchors per `migration-discipline.md` § Project-specific block).
- `_extracted-idioms.md` (or `codebase-profile.md`) populated — for semantic resolution + V2 structure reference.
- Mechanical CI green at HEAD (lint / typecheck / build / tests).
- Working tree clean, unless `--allow-dirty`.

**Explicitly NOT required** (this is the bypass-the-ceremony part):
- ❌ `/migration-scan` does NOT need to have run.
- ❌ `ai/migration/ledger.md` does NOT need to exist.
- ❌ `ai/migration/plan.md` does NOT need to exist.
- ❌ The area does NOT need to be in any phase.
- ❌ No ledger row needs to exist for the area.

If a ledger / plan exists, the command USES it (best-effort: matches existing rows, updates them after fix). If not, the command works anyway — it scans V1 + V2 source directly for the described area.

## Phase 1 — Understand (the ask)

Inputs:
- `<description-or-path>` — natural-language description OR explicit path(s).
- V1 + V2 source roots (from project anchors).
- `_extracted-idioms.md` / `codebase-profile.md` (semantic resolution).
- `ai/migration/ledger.md` — **OPTIONAL**. If present, used for ledger-row updates. If absent, ignored.

Optional flags:

**Resolution flags** (description-input behavior):
- `--no-confirm` — never confirm ambiguous matches; pick the highest-scoring candidate silently. Use only in scripted contexts.
- `--always-confirm` — show the resolution table even for high-confidence matches. Verify what the agent picked.
- `--max-matches=<N>` — cap the candidate set (default: 5). Above the cap, halt and ask user to narrow.

**Ledger flags** (best-effort, not required):
- `--register-ledger` — if a matching ledger row doesn't exist, create one for the area as part of the recheck. Default: leave the ledger alone (recheck stays "off the books"). Use this when you're spot-checking an area that SHOULD be tracked going forward.
- `--ledger-only` — restrict matching to existing ledger rows (legacy behavior). Use when the area is already in the ledger and you want the strict prior behavior. Without this flag, the command works whether or not a ledger row exists.

**Run-control flags**:
- `--max-parallel=<N>` — cap parallel area dispatch (default: 4). Per-file lock prevents races.
- `--dry-run` — show what would be re-checked, no edits.
- `--allow-dirty` — proceed with uncommitted changes (default: refuse).
- `--re-detect-only` — audit but DO NOT fix; surface drift report only.
- `--v1-commit=<sha>` — pin a specific V1 commit for the audit (default: V1 HEAD). Use when you want to audit against a stable V1 reference rather than a moving HEAD.

## Phase 2 — Organize (decompose the work)

```
1. PRE-FLIGHT      — verify oracle + clean tree (ledger / plan NOT required)
2. RESOLVE         — for each input arg: classify as path or description; resolve descriptions to V1 + V2 source paths via semantic understanding
3. CONFIRM         — if resolution was ambiguous, surface candidates and confirm
4. NAV-TREE        — for any module-scoped or multi-tab area: build V1 navigation tree AND V2 navigation tree via the MANDATORY TWO-LAYER scan, then diff. Layer A: route tree from every router file in the project's stack. Layer B: per-leaf template grep — for EACH component identified by Layer A, open the source and grep for in-template tab patterns (the project's tab primitive — concrete tag/component vocabulary varies by stack; see the project's frontend pack rule § Tab patterns; plus role-based markers `role="tab"` / `role="tablist"`, sidebar nav-tab arrays, in-page tab iteration constructs over `tabs|items|sections` collections, accordion title arrays, in-component nested-routing siblings). Layer-A-only scans are incomplete and HALT. Any V1 leaf (route OR in-template) without a V2 equivalent navigation surface is HALT-tier nav drift, surfaced BEFORE per-axis enumeration. Per `migration-discipline.md` halt #13: burying a V1 sub-tab as a section in another V2 tab is drift, not STRUCTURE_OK. If nav drift surfaces, the auditor halts at this step; per-axis work runs only on tabs that exist in both sides. Section 0 completion checklist (in `migration-discipline.md` halt #13) must tick all boxes before audit can advance.
5. SCAN-FRESH      — for each resolved area: enumerate V1 + V2 source files; pin V1 commit hash for the run
6. AUDIT-FRESH     — dispatch parity-auditor per area: read V1 source + V2 source line-by-line, output gap list (NO cache lookup, NO prior-audit reuse). Section 0 of every module-scoped audit is the Navigation Inventory from step 4.
7. TRIAGE          — split into clean / drifted / halted
8. FIX             — apply V1-parity edits to V2 (one logical fix per commit)
9. VERIFY          — lint + typecheck + scoped tests + re-detect (gaps_in == gaps_closed)
10. RECORD-LEDGER  — best-effort: if a matching ledger row exists, update it. If not, leave the ledger alone (or create new row if --register-ledger was passed)
11. SUMMARY        — end-of-run report
```

Heavy-tier areas (cross-repo, security-sensitive, write-path) still route through the heavy ceremony — the discipline floor doesn't change just because we're skipping the plan.

Key difference vs `/migration-fast` / `/migration-phase`:
- Fast/phase: reads ledger → finds rows in phase N → re-audits each row.
- Recheck: reads YOUR description → finds V1 + V2 source for the area → audits source directly.

Both apply the same V1-parity discipline. Recheck just bypasses the ledger-as-input requirement.

## Resolution — the agent UNDERSTANDS the description (not keyword search)

The agent treats your description the same way `/add-feature` treats yours: read the project's context, then use semantic understanding to map your intent to the right features. **No keyword tokenization. No stopword stripping. No mechanical regex search.** The agent reads the project, knows what "the sidebar" or "the customer tabs" means in this specific codebase, and resolves it.

### Context the agent reads BEFORE interpreting your description

1. **`.claude/codebase-profile.md`** (or `_extracted-codebase.md`) — the project's UI surface inventory. Names key components, pages, modules, layouts, navigation patterns. The agent reads this to know "in THIS project, what is the sidebar / header / dashboard / customer tabs."
2. **`ai/migration/ledger.md`** — feature inventory with names, domains, paths, notes. The agent reads it to know which features exist and what they're called.
3. **`ai/architecture.md` + `ai/conventions.md`** — module structure, naming conventions, layout patterns. Helps the agent disambiguate (e.g., "the orders module" → `<modules-root>/orders/` vs "an orders endpoint" → could be elsewhere).
4. **`.claude/_extracted-idioms.md`** (when present) — named shared components / wrappers. Helps interpret descriptions referencing shared surfaces ("the toolbar", "the data table").

### How the agent interprets your description

Like a teammate who knows the project. Example flow for `/migration-recheck the customer tabs in the dashboard`:

1. Reads `codebase-profile.md`. Sees: "Dashboard at `<v2-root>/<dashboard-leaf-component>` has tabbed sections: customer profile, orders, addresses, payment-methods." *(extension is stack-specific — declared in `_extracted-codebase.md § Stack`.)*
2. Reads ledger. Finds rows F082 (`customer-profile-tab`), F083 (`customer-orders-tab`), F084 (`customer-addresses-tab`), F085 (`customer-payment-methods-tab`).
3. Concludes: the user means those 4 features.
4. If the project profile didn't have explicit "customer tabs" naming, the agent would also read source: open the dashboard leaf, find the in-template tab construct (the project's tab primitive — concrete tag/component vocabulary varies by stack; see the project's frontend pack rule § Tab patterns), and cross-reference labels against ledger rows whose `v2_path` is inside that file's directory.
5. Surfaces the resolution to user for confirmation if the mapping isn't certain.

### What "understanding" means here

The agent uses its full read-the-context capability:

- Reads source files when the profile doesn't directly name what you described.
- Cross-references descriptions against module domains (e.g., "the auth flow" → reads `<modules-root>/auth/` to enumerate the actual flow steps: login, signup, password-reset, MFA, etc.).
- Handles compound descriptions ("the auth flow including login and signup") as one semantic intent — figures out which features comprise the auth flow first, then narrows to the named subset.
- Handles UI-element descriptions ("the dropdown in the header") by reading the header component's source to find dropdown sub-components.
- Asks a clarifying question when the description is genuinely ambiguous in this codebase — not because tokenization failed, but because two different features genuinely match.

### Confirmation flow (only when uncertain)

Default behaviour:

- **Agent is confident** → resolves silently, surfaces the resolution as a 1-line preamble in the run summary so you can verify after:
  ```
  Resolved "the customer tabs in the dashboard" → 4 features:
    F082 (customer-profile-tab), F083 (customer-orders-tab),
    F084 (customer-addresses-tab), F085 (customer-payment-methods-tab)
  Proceeding to re-audit...
  ```
- **Agent is uncertain** (multiple plausible interpretations, or the codebase has surfaces that match overlapping intents) → halts and asks:
  ```
  Description "the sidebar" could mean:
    [1] The app-wide navigation sidebar (F042 — AppSidebar)
    [2] The orders-list filter sidebar (F156 — orders/SidebarFilter)
    [3] Both

  Which did you mean?
  ```
- **Agent finds nothing matching** → halts with suggestions:
  ```
  Couldn't find anything matching "the foo widget" in this project.
  Suggestions:
  - Check `/migration-status` for the feature inventory
  - The codebase profile lists known surfaces — search there
  - Run `/migration-scan --since=<commit>` if it's a recently-added feature
  - Provide an explicit path: `/migration-recheck src/path/to/foo/`
  ```

### Confirmation control flags

- `--no-confirm` — even if uncertain, pick the most-likely resolution silently. Use only in scripted contexts. The agent still surfaces the chosen resolution in the summary.
- `--always-confirm` — always show the resolution preview before running, even when the agent is confident. Use when you want to verify before any code is touched.
- `--max-matches=<N>` — cap the candidate set (default: 8). Above the cap, the agent asks you to narrow rather than run on a huge set.

### Edge cases

- **Empty description** → halt; ask for a description or path.
- **Path-like string** (a basename with a stack-native extension, e.g., `"Sidebar.<leaf-ext>"`) → handled as path-basename match (no semantic resolution needed).
- **Compound descriptions** ("login and signup") → resolved as one intent (auth-flow features), not split into separate keyword groups. The agent reads context to figure out what login + signup means in this codebase.
- **Mixed input** (description + path) → both resolve, results unioned.
- **Description references something the agent can't find** → asks for clarification with concrete next-step suggestions.

## Phase 3 — Retrieve (read the right context)

For each matched feature:
- Ledger row.
- 5K shared context blob (idioms + conventions + architecture summaries).
- V1 + V2 source for the feature.
- Cached audit at `ai/migration/audits/<feature>.md` (replaced by re-audit).

## Phase 4 — Generate (produce the output)

### Audit-output rule — ADRs are notes, not verdicts

Every V1↔V2 divergence is reported as `DIVERGENT` regardless of ADR status. Existing ADRs appear as a *note* on the row, not as ✅ closure. The user re-confirms each ADR-ratified divergence during recheck — recheck is the moment to revisit prior decisions, not the moment to defer to them. The recheck command's premise is "fresh parity audit, no cache lookup, no prior-audit reuse" (see top of this file); treating an ADR as ✅ violates that premise and reproduces the original Trusted-Summary failure mode at one level of indirection.

```
❌ WRONG (treats ADR as closure):
| N | <surface> | V1: <behaviour-A> | V2: <behaviour-B> | ✅ ADR-NNN §<id> |

✅ RIGHT (ADR is a note; user re-confirms):
| N | <surface> | V1: <behaviour-A> | V2: <behaviour-B> | DIVERGENT (note: ADR-NNN §<id> ratified V2 — re-confirm or revert?) |
```

The status column has exactly two values: `PARITY` (V1 and V2 match observable behaviour) or `DIVERGENT` (they don't). ADRs annotate; they do not close.

When the user replies with "do like V1" / "match V1" / "fix it" without per-row exceptions, **all DIVERGENT rows are eligible for V1-revert**, including ADR-ratified ones. Do not narrow the scope to "DIVERGENT and not-ADR'd" — that inversion of the default is the bug this rule prevents.

### Output stream

Per-feature output streams to `ai/migration/runs/<YYYY-MM-DD-HHMMSS>-recheck.log`. End-of-run summary surfaces to user.

```
Migration recheck — paths: <modules-root>/orders/, <modules-root>/store/

Pre-flight:                    PASS
Features matched:              23
  By path:
    <modules-root>/orders/:    12
    <modules-root>/store/:     11

Triage (after re-audit):
  Clean (no drift):            18
  Drifted:                     4
  Halted (need user action):   1

Re-fixes applied:
  F042 (order-create)          fixed: 2 gaps closed (+0/-3 lines)
  F058 (order-cancel)          fixed: 1 gap closed (+1/-2 lines)
  F071 (store-product-list)    fixed: 3 gaps closed (+0/-8 lines)
  F089 (store-checkout)        fixed: 1 gap closed (+0/-1 lines)

Halts (require user action):
  F045 (order-bulk-update)     reason: cross-repo (V1 backend route shape changed)
                               see: ai/migration/halts/F045.md

Total impact:
  Net diff:                    +1 / -14 = -13 lines
  Test suite:                  PASS (all parity tests green)
  Coverage:                    no change
  Wall-clock:                  4m 12s

Next:
  Resolve F045 halt (cross-repo dependency).
  Re-run /migration-recheck <modules-root>/orders/ to drain F045 once resolved.
  OR /find-and-fix F045 directly after the cross-repo PR lands.
```

## Phase 5 — Update (persist changes to the knowledge base)

- Per-feature: ledger row updated, audit overwritten, commit per fix.
- `ai/migration/runs/<timestamp>-recheck.log` — full per-feature log.
- `ai/migration/_history.md` — append one line: `<iso> recheck | paths=<paths> | matched=<N> drifted=<D> fixed=<F> halted=<H>`.
- One commit per fixed feature: `recheck/<feature-id>: <one-line description>`.

## Phase 6 — Validate (verify correctness)

- Every matched feature has a fresh audit at `ai/migration/audits/<feature>.md` with the current V1 commit pinned.
- Every re-fixed feature has a new commit + ledger update.
- Halted features have `ai/migration/halts/<id>.md`.
- No matched feature is left in `in-flight` (all rows terminal: clean, drifted-fixed, or halted).

## Phase 7 — Improve (feed the learning loop)

- If the same feature halts repeatedly across rechecks → flag for re-classification or `/migration-park`.
- If a path consistently surfaces drift → queue ADR for hook / lint rule that prevents the drift class.
- If many features in one module drift simultaneously → likely a backend contract change; surface to user with cross-repo link.

## Match logic (how feature IDs are selected from <path>)

For each feature in `ai/migration/ledger.md`:
- Compute `v1_match = is_path_inside_or_equal(feature.v1_path, given_paths)`.
- Compute `v2_match = is_path_inside_or_equal(feature.v2_path, given_paths)`.
- Feature matches if (per `--match-on`):
  - `--match-on=v1` → `v1_match`
  - `--match-on=v2` → `v2_match`
  - `--match-on=both` (default) → `v1_match OR v2_match`

Glob patterns are expanded before matching. Multiple `<path>` args are OR'd.

Path matching is recursive — `<modules-root>/orders/` matches any feature whose path is inside that directory, including subdirectories.

## Hard rules

- **No phase concept.** This command is path-scoped, not phase-scoped. Ledger phase fields are ignored.
- **Same discipline as /find-and-fix.** Per-feature: DETECT → DECIDE → FIX → VERIFY → RECORD. One commit per feature. V2 wins on structure; V1 wins on observable behaviour.
- **Tier defaults preserved.** Trivial / standard / heavy auto-routes per feature based on its ledger row's tier.
- **Halts are aggregated, not blocking.** A halted feature surfaces in the summary; other features continue.
- **No silent ADRs.** ADR-needed decisions halt the affected feature; user resolves and re-runs.
- **Idempotent.** Re-running drains halts as their causes resolve.

## Failure modes

- **No features match the path** — halt; surface "no ledger rows have v1_path or v2_path inside <given paths>". User checks the path or runs `/migration-scan` to pick up new features.
- **A matched feature has no V1 source at the pinned commit** — halt that row; route to `/migration-park` or unpin the commit.
- **Cross-repo blocker on a fixed row** — halt that row; surface in summary; rest of the recheck continues.
- **Many features halt with same root cause** — surface as a cluster in the summary ("8 features halted with reason: cross-repo backend route shape change") so user fixes the upstream once.

## Examples

### Description-based (natural language)

```bash
# Single concept — agent resolves to the matching feature(s)
/migration-recheck the sidebar
/migration-recheck the header
/migration-recheck the orders module
/migration-recheck the page builder
/migration-recheck the navigation menu

# Multi-concept — multiple keyword groups
/migration-recheck the customer tabs in the dashboard
/migration-recheck the auth flow including login and signup
/migration-recheck the checkout and payment pages

# Specific UI element — profile likely names it
/migration-recheck the user dropdown
/migration-recheck the order details page
```

### Path-based (still supported)

```bash
# Single path
/migration-recheck <modules-root>/orders/

# Multiple paths
/migration-recheck <modules-root>/store/ <modules-root>/products/ <modules-root>/orders/

# A specific component / page (extension is stack-specific — declared in _extracted-codebase.md § Stack)
/migration-recheck <components-root>/Sidebar.<leaf-ext>
/migration-recheck <modules-root>/builder/pages/BuilderPage.<leaf-ext>

# Glob
/migration-recheck "<modules-root>/{auth,permissions,roles}/"
```

### Mixed (description + path)

```bash
# Combine: resolve "the sidebar" + add explicit path
/migration-recheck the sidebar <modules-root>/orders/
```

### Modifier flags

```bash
# Re-audit only (no fixes; surface drift report)
/migration-recheck the orders module --re-detect-only

# Always show resolution table even for confident matches
/migration-recheck the sidebar --always-confirm

# Skip confirmation (scripted contexts only)
/migration-recheck the sidebar --no-confirm
```

## Related

### Sibling commands in migration pack
- `/find-and-fix <id>` — single-feature variant of this command.
- `/migration-fast <N> --re-audit` — phase-scoped re-audit (vs path-scoped here).
- `/migration-scan --since=<commit>` — pick up newly-added features before rechecking.
- `/compare-v1 <feature>` — read-only V1↔V2 diff for inspection.

### Rules
- `.claude/rules/migration-discipline.md` — the discipline this command enforces.

### Patterns
- `ai/patterns/feature-port.md` — per-feature lifecycle.
- `ai/patterns/migration-ledger.md` — ledger schema.
