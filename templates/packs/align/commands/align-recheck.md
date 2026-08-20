---
description: Independent codebase-quality spot-check + fix. Accepts a natural-language description ("the sidebar", "the orders module") OR explicit paths. Scans source FRESH for the described area against the gold-standard inventory, detects drift (dead code / dups / reinvented wrappers / silent catches / a11y / design tokens / i18n / security / perf), fixes it. NO plan dependency, NO phase concept, NO required ledger row. Bypasses the full alignment ceremony — just: find the area, scan, fix. Mirrors /migration-recheck.
kind: command
pack: align
---

# /align-recheck <description-or-path> [<more>...]

## The Premise (read this first)

**This is your bypass-the-ceremony tool for align.** Forget the plan. Forget the phases. Forget whether a ledger row exists. You describe a code area; this command finds it, scans against gold standards FRESH, fixes drift. One command, no chain.

What it does NOT do:
- ❌ Read the alignment plan to figure out what to do.
- ❌ Care which phase the area belongs to.
- ❌ Require a ledger row to exist for the area.
- ❌ Require any prior `/align-scan` or `/align-plan` run.

What it DOES:
- ✅ Resolve your description to actual source paths (semantic understanding via codebase-profile + idioms).
- ✅ Run a **fresh detection sweep** for the area: dispatches the 12 universal detectors (dead-code, dups, reinvented-wrapper, silent-catch, over-abstraction, drift, SOLID, clean-code, performance, security, unhandled-io) + stack-conditional UI/UX detectors for `frontend-*` (a11y, design-tokens, i18n, motion, lifecycle, default-true-prop, permission-gate-drop).
- ✅ Apply closure-verb fixes (21-verb vocabulary; structural net-lines ≤ 0; functional cite-idiom).
- ✅ Verify (lint + typecheck + scoped tests + re-detect + class-specific assertions).
- ✅ Commit (one commit per finding).
- ✅ **Best-effort ledger update**: if the alignment ledger exists, update it; if not, leave it alone (or pass `--register-ledger` to create new entries).

Examples:

- `/align-recheck the sidebar`
- `/align-recheck the orders module`
- `/align-recheck the page builder`
- `/align-recheck the navigation header`
- `/align-recheck <modules-root>/orders/` (paths still work)
- `/align-recheck "auth pages including login and signup"` (multi-concept)

Use this when:
- You want focused quality cleanup on a specific area without setting up the full alignment workflow.
- Alignment hasn't been initialized in the project yet (no `/align-scan` run).
- You want a quick spot-check before merging a feature that touched the area.
- The full alignment plan is paused / abandoned but you still want a sweep on one area.

This is the **focused-area** companion to `/align-fast <N> --re-audit` (which is phase-scoped). Use `/align-recheck` when:
- You suspect drift (dead code, reinvented wrappers, silent catches, perf issues, security gaps) in a specific module / page / route after a feature merge.
- You want to re-verify a code area independent of how it was phased originally.
- A code review surfaces concerns about a specific surface and you want a fresh quality sweep there.
- The module wasn't in the alignment plan (yet) but you need to re-check it now.

**What it does** (per matched finding):
1. Re-detect: re-run the detector against current source.
2. Decide: confirm closure verb is in vocabulary; verify behaviour-preserving for structural rows; verify idiom-citation for functional rows.
3. Fix: apply closure-verb edit (mechanical for structural; small + budgeted for functional).
4. Verify: lint + typecheck + scoped tests + re-detect + class-specific assertions.
5. Record: update ledger row.

Same discipline as `/align-phase` (the per-finding loop), just multi-finding + path-scoped.

## When to use

- "Re-check the orders module" — `/align-recheck the orders module` OR `/align-recheck <modules-root>/orders/`
- "Re-check the sidebar" — `/align-recheck the sidebar`
- "Re-check the page-builder for security/quality issues" — `/align-recheck the page builder`
- "Re-check store + products" — `/align-recheck the store and products modules`
- After a feature merge that touched many files, to verify nothing broke alignment.

## Input forms — description OR path

The first arg can be:

1. **Path** — anything that looks like a path (starts with `src/`, contains `/`, has a file extension). Used as-is.
2. **Description** — anything else. Plain-language description; agent resolves to ledger findings.

Mixed input is allowed: descriptions resolve first, paths append, final set is the union.

## Resolution — the agent UNDERSTANDS the description (not keyword search)

Like `/add-feature`: the agent reads the project's context, then maps your intent to the right findings. **No keyword tokenization. No stopword stripping. No mechanical regex search.** Context the agent reads before interpreting:

1. **`.claude/codebase-profile.md`** — the project's UI surface inventory. Knows what "the sidebar" or "the customer tabs" means in THIS project.
2. **`ai/align/ledger.md`** — finding inventory with classes, scopes, evidence, notes.
3. **`ai/architecture.md` + `ai/conventions.md`** — module structure for disambiguation.
4. **`.claude/_extracted-idioms.md`** — named shared components / wrappers.

The agent uses full read-the-context capability: opens source files when the profile doesn't directly name what you described; cross-references against module domains; handles compound descriptions semantically. Same model `/add-feature` uses — interpret intent, don't pattern-match strings.

**Confirmation flow**:
- **Confident** → resolves silently, surfaces the resolution as a 1-line preamble in the summary.
- **Uncertain** → halts with options ("Did you mean [1] X, [2] Y, [3] both?").
- **Nothing found** → halts with suggestions (`/align-status`, `/align-scan --since=<commit>`, or explicit path).

Configurable via `--no-confirm` / `--always-confirm` / `--max-matches=<N>`.

## When NOT to use

- For a single finding → fix it manually or wait for the next phase.
- For a whole phase → `/align-fast <N>` is the phase-scoped variant.
- For a fresh full-repo sweep → `/align-scan` then phased flow.
- Mid-feature work (your own dirty diff) — finish the feature first, then recheck.

## Pre-requisites (intentionally minimal)

**Hard requirements**:
- `_extracted-idioms.md` (or `codebase-profile.md`) populated — the oracle.
- Mechanical CI green at HEAD (lint / typecheck / build / tests).
- Working tree clean, unless `--allow-dirty`.

**Explicitly NOT required**:
- ❌ `/align-scan` does NOT need to have run.
- ❌ `ai/align/ledger.md` does NOT need to exist.
- ❌ `ai/align/plan.md` does NOT need to exist.
- ❌ The area does NOT need to be in any phase.

If a ledger / plan exists, the command USES it (best-effort row updates). If not, the command still works — it scans source directly via the universal detectors.

## Phase 1 — Understand (the ask)

Inputs:
- `<description-or-path>` — natural-language or explicit path(s).
- `_extracted-idioms.md` / `codebase-profile.md` (semantic resolution + gold standards).
- `ai/align/ledger.md` — **OPTIONAL**. If present, used for row updates. If absent, ignored.

Optional flags:

**Resolution flags** (description-input behavior):
- `--no-confirm` — never confirm ambiguous matches; pick the highest-scoring candidate silently.
- `--always-confirm` — show the resolution table even for high-confidence matches.
- `--max-matches=<N>` — cap candidate set (default: 5). Above the cap, halt and ask user to narrow.

**Ledger flags** (best-effort, not required):
- `--register-ledger` — if no matching ledger rows exist, create new entries for the findings detected in the recheck. Default: leave the ledger alone (recheck stays "off the books"). Use this when you want the area's findings tracked going forward.
- `--ledger-only` — restrict the scan to existing ledger rows whose scope is inside the resolved area (legacy behavior). Use when the area has already been scanned and you want the strict prior behavior. Without this flag, the command scans source directly via the universal detectors.

**Detection flags**:
- `--class=<list>` — limit to specific classes (e.g., `--class=security,reinvented-wrapper,a11y-violation,duplicated-surface-styles`).

**Run-control flags**:
- `--max-parallel=<N>` — cap parallel finding dispatch (default: 5 trivial; 3 standard; 1 heavy).
- `--dry-run` — show what would be re-checked, no edits.
- `--allow-dirty` — proceed with uncommitted changes.
- `--re-detect-only` — detect but DO NOT fix.

## Phase 2 — Organize (decompose the work)

```
1. PRE-FLIGHT      — verify oracle + clean tree (ledger / plan NOT required)
2. RESOLVE         — for each input arg: classify as path or description; resolve descriptions to source paths via semantic understanding
3. CONFIRM         — if resolution was ambiguous, surface candidates and confirm
4. SCAN-FRESH      — for the resolved area: dispatch the 12 universal detectors (+ stack-conditional UI/UX detectors for frontend-*) directly against current source. NO cache lookup, NO ledger-row lookup as input.
5. TRIAGE          — split detected findings into trivial / standard / heavy; dispatch `@align-evidence-auditor` over the fresh rows (evidence resolves + explicit enumeration + class matches signal + verb reachable without invention + tier floor). Rows it REJECTs do not reach FIX; out-of-domain rows leave with their destination named.
6. FIX             — apply closure-verb edits per finding (one commit per finding; net-lines ≤ 0 structural / cite-idiom functional)
7. VERIFY          — lint + typecheck + scoped tests + re-detect + class-specific assertions (security / perf / a11y / bundle-size)
8. RECORD-LEDGER   — best-effort: if a ledger exists, update matching rows. If not, leave alone (or create new entries if --register-ledger)
9. SUMMARY         — end-of-run report
```

Heavy-tier findings still get the supervised loop (reviewer pause). Critical security still auto-promotes to heavy. The discipline floor doesn't change — only the input source (your description vs. ledger rows).

Key difference vs `/align-fast` / `/align-phase`:
- Fast/phase: reads ledger → finds rows in phase N → re-detects each.
- Recheck: reads YOUR description → finds source for the area → scans source directly.

## Phase 3 — Retrieve (read the right context)

**MUST read** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) before generating code fixes.

For each matched finding:
- Ledger row.
- 5K shared context blob (idioms summary).
- Source files in `scope`.
- For functional rows: the idiom file at `idiom_cited`.

## Phase 4 — Generate (produce the output)

### Per-class → pack-skill routing (the FIX dispatch)

The 21-verb vocabulary above is the closure-verb floor for structural / functional drift. For findings whose class is owned by a specialist pack skill, the FIX step (Phase 2 step 6) routes the finding to that skill — the skill owns the verb taxonomy, procedure, and verify for its class; `/align-recheck` keeps the per-finding loop (DETECT → DECIDE → FIX → VERIFY → RECORD) around it.

| Finding class | Dispatched skill | Pack |
|---|---|---|
| refactoring (extract-method / inline / rename / move / dedup — behaviour-preserving structure) | `refactoring-sweep` | code-quality |
| UI/UX axes (tokens / hierarchy / rhythm / states / contrast / focus / motion / tap-target / cta / affordance / surface / type-scale) | `ui-design-sweep` | ui-ux |
| api (envelope / error-contract / pagination / naming-case / idempotency / log-metric-trace naming / openapi coverage) | `api-consistency-audit` | backend |
| schema (column-naming / type / index-naming / audit-field / soft-delete / timestamp drift) | `schema-consistency-audit` | database |

Class-to-skill routing fires only when the resolved area's `PROJECT_KIND` makes the skill applicable (UI/UX skills on `frontend-*` / `mobile-*`; api/schema on `backend-*` / `data-*`). Findings outside these four classes stay on the universal 21-verb closure path. The dispatched skill's own pre-flight (idioms / conventions present) and verify (visual baseline / a11y / migration reversibility) apply.

Per-finding output streams to `ai/align/runs/<YYYY-MM-DD-HHMMSS>-recheck.log`. End-of-run summary surfaces to user.

```
Align recheck — paths: <modules-root>/orders/, <modules-root>/store/

Pre-flight:                    PASS
(--rescan-fresh):              ran; 3 new findings added to ledger
Findings matched:              28
  By path:
    <modules-root>/orders/:       16
    <modules-root>/store/:        12
  By class:
    reinvented-wrapper:        9
    silent-catch:              5
    dead-code:                 4
    drift:                     6
    security:                  2
    performance:               2

Triage (after re-detect):
  Clean (no drift):            21
  Drifted:                     6
  Halted (need user action):   1

Re-fixes applied:
  A042 (silent-catch)          fixed (-3 lines)
  A058 (reinvented-wrapper)    fixed (-12 lines, swapped local Button for AppButton)
  A071 (dead-code)             fixed (-8 lines)
  A089 (drift)                 fixed (replaced raw axios.create with apiClient)
  A105 (security)              fixed (added requireAdmin gate; +4 lines, idiom-cited)
  A112 (performance)           fixed (replaced sequential await with batch query)

Halts:
  A067 (security/sql-injection) reason: idiom missing (no parameterized-query primitive)
                                see: ai/align/halts/A067.md

Total impact:
  Net diff (structural):       +0 / -23 = -23 lines
  Net diff (functional):       +6 / -2  = +4 lines (cited idioms)
  Test suite:                  PASS
  Coverage:                    +0.2% (no drop)
  a11y (frontend):             PASS (no regression)
  Bundle-size:                 -0.4% (smaller)
  Wall-clock:                  3m 48s

Next:
  Resolve A067 halt (run /setup-project --refine to add parameterized-query idiom).
  Re-run /align-recheck <modules-root>/orders/ to drain A067.
```

## Phase 5 — Update (persist changes to the knowledge base)

- Per-finding: ledger row updated, commit per fix.
- `ai/align/runs/<timestamp>-recheck.log` — full per-finding log.
- `ai/align/_history.md` — append one line: `<iso> recheck | paths=<paths> | matched=<N> drifted=<D> fixed=<F> halted=<H>`.
- One commit per fixed finding: `recheck/<finding-id>: <one-line description>`.

## Phase 6 — Validate (verify correctness)

- Every matched finding has a fresh re-detect outcome.
- Every re-fixed finding has a new commit + ledger update.
- Halted findings have `ai/align/halts/<id>.md`.
- No matched finding is left in `in-progress` (all rows terminal: clean, drifted-fixed, archived, or halted).

## Phase 7 — Improve (feed the learning loop)

- If the same finding halts repeatedly across rechecks → flag for re-classification, `/align-park`, or `/setup-project --refine` (idiom gap).
- If a path consistently surfaces drift → queue ADR for hook / lint rule that prevents the drift class.
- If many findings in one module drift simultaneously → likely a refactor or feature merge that violated conventions; surface as a cluster.

## Match logic (how finding IDs are selected from <path>)

For each finding in `ai/align/ledger.md`:
- Compute `scope_match = any(scope_file_inside(s, given_paths) for s in row.scope)`.
- Compute `evidence_match = any(evidence_file_inside(e, given_paths) for e in row.evidence)`.
- Finding matches if `scope_match OR evidence_match`.

Glob patterns are expanded before matching. Multiple `<path>` args are OR'd. Path matching is recursive.

## Hard rules

- **No phase concept.** This command is path-scoped, not phase-scoped. Ledger phase fields are ignored.
- **Same discipline as /align-phase.** Per-finding: DETECT → DECIDE → FIX → VERIFY → RECORD. One commit per finding. Closure verbs from the 21-verb vocabulary only. Net-lines ≤ 0 for structural rows; functional rows cite idioms.
- **Tier defaults preserved.** Trivial / standard / heavy auto-routes per finding.
- **Halts are aggregated, not blocking.** A halted finding surfaces in the summary; other findings continue.
- **No silent abstractions.** Functional fixes USE existing idioms; missing idioms halt the row, route to `/setup-project --refine`.
- **Idempotent.** Re-running drains halts as their causes resolve.

## Failure modes

- **No findings match the path** — halt; surface "no ledger rows have scope or evidence inside <given paths>". Suggest `/align-recheck <path> --rescan-fresh` to surface new findings.
- **A matched finding's evidence file is deleted** — mark `archived-pre-existing`; skip.
- **Idiom missing** for a functional row — halt that row; surface in summary; rest continues. User runs `/setup-project --refine` to add the idiom, then re-runs recheck.
- **Many findings halt with same root cause** — surface as a cluster ("8 findings halted with reason: idiom missing for parameterized-query") so user fixes upstream once.

## Examples

### Description-based

```bash
/align-recheck the sidebar
/align-recheck the orders module
/align-recheck the page builder
/align-recheck the navigation header
/align-recheck the user dropdown
/align-recheck the customer tabs in the dashboard
/align-recheck the auth flow including login and signup
```

### Path-based

```bash
/align-recheck <modules-root>/orders/
/align-recheck <modules-root>/store/ <modules-root>/products/
/align-recheck <components-root>/Sidebar.<ext>   # extension is stack-specific (.vue / .tsx / .svelte / .razor / etc.)
/align-recheck "<modules-root>/{auth,permissions,roles}/"
```

### Mixed + modifiers

```bash
# Description + path
/align-recheck the sidebar <modules-root>/orders/

# Re-detect only (no fixes)
/align-recheck the orders module --re-detect-only

# Pick up new findings first
/align-recheck the page builder --rescan-fresh

# Class-filtered
/align-recheck the order pages --class=security

# Always show resolution table
/align-recheck the sidebar --always-confirm
```

## Related

### Sibling commands in align pack
- `/align-phase <N>` — phase-scoped per-finding loop.
- `/align-fast <N> --re-audit` — phase-scoped re-audit (vs path-scoped here).
- `/align-scan --scope=<path>` — pick up new findings before rechecking.
- `/align-status` — read-only ledger reader.

### Agents
- `.claude/agents/align-evidence-auditor.md` — dispatched at TRIAGE over the SCAN-FRESH rows. Path-scoped rechecks skip `/align-plan` entirely, so this is the only evidence audit a recheck gets.
- `.claude/agents/align-idiom-auditor.md` — dispatched per row at DECIDE and VERIFY inside the FIX loop, exactly as in `/align-phase`.

### Skills (per-class FIX dispatch — see Phase 4 routing table)
- `code-quality/skills/refactoring-sweep/SKILL.md` — refactoring-class findings.
- `ui-ux/skills/ui-design-sweep/SKILL.md` — UI/UX-axis findings (frontend/mobile).
- `backend/skills/api-consistency-audit/SKILL.md` — api-class findings (backend).
- `database/skills/schema-consistency-audit/SKILL.md` — schema-class findings (data).

### Cross-pack
- `migration/commands/migration-recheck.md` — sibling pattern in migration; this command mirrors it for align.

### Rules
- `.claude/rules/align-discipline.md` — the discipline this command enforces.
