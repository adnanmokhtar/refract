---
description: "Area-scoped align audit + fix: resolve \"the sidebar\" or a path, run align-detect fresh there, close declared-convention rows through find-and-align, route owner rows to their fix commands. No plan or ledger needed."
kind: command
pack: align
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
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
- ✅ Run a **fresh detection sweep** for the area: `align-detect` scoped to the resolved paths — the four align detectors (`convention-oracle`, `wrapper-adoption-scan`, `naming-layout-scan`, `convention-ratchet-scan`) and every installed owner detector (ui-ux `design-token-audit`, frontend `i18n-scan` / `a11y-code-scan`, code-quality `architectural-diagnosis`, backend `edge-error-scan` / `api-consistency-audit`). Every candidate is refuted (`refute-before-report.md` § 10) before it counts.
- ✅ Close the align-owned rows through `find-and-align` (the proof ladder: EQ by a zero diff, VC only with a human approval, FN by a behaviour test).
- ✅ Print an **owner line** for every row another pack closes — security, performance, data, error handling, dead code, SOLID, API contracts, new copy — with the owner's fix command. Recheck never closes them.
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
- You suspect convention drift (a raw library import past the wrapper, a token literal, a misnamed file, a dropped permission gate) in a specific module / page / route after a feature merge.
- You want to re-verify a code area independent of how it was phased originally.
- A code review surfaces concerns about a specific surface and you want a fresh quality sweep there.
- The module wasn't in the alignment plan (yet) but you need to re-check it now.

**What it does** (per matched finding):
1. Route: an owner row gets its owner line and no edit; a T2g oracle waits for ratification.
2. Re-detect: re-run the row's `detector_cmd` against current source; the oracle quote still resolves (L0).
3. Decide: the proof class (EQ / VC / FN) and a closure verb from the closed set.
4. Fix: only the matched expression and the verb's footprint; tests and snapshots read-only.
5. Verify: the ladder (`align-sweep-gate.py ladder`, L0–L13).
6. Record: update the ledger row, when a ledger exists.

Same discipline as `/align-phase` (the per-finding loop), just multi-finding + path-scoped.

## When to use

- "Re-check the orders module" — `/align-recheck the orders module` OR `/align-recheck <modules-root>/orders/`
- "Re-check the sidebar" — `/align-recheck the sidebar`
- "Re-check the page-builder against our conventions" — `/align-recheck the page builder` (security or quality issues there are `/security-audit` and `/quality-audit`)
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
- A declared convention for the area — the oracle map (`convention-oracle` § 0) has a T1 or T2 row; the inventory comes from `_extracted-idioms.md` → `codebase-profile.md` → `ai/conventions.md`.
- Mechanical CI green at HEAD (lint / typecheck / build / tests).
- Working tree clean, unless `--allow-dirty`.

**Explicitly NOT required**:
- ❌ `/align-scan` does NOT need to have run.
- ❌ `ai/align/ledger.md` does NOT need to exist.
- ❌ `ai/align/plan.md` does NOT need to exist.
- ❌ The area does NOT need to be in any phase.

If a ledger / plan exists, the command USES it (best-effort row updates). If not, the command still works — it scans source directly through `align-detect`.

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
- `--ledger-only` — restrict the scan to existing ledger rows whose scope is inside the resolved area (legacy behavior). Use when the area has already been scanned and you want the strict prior behavior. Without this flag, the command scans source directly through `align-detect`.

**Detection flags**:
- `--class=<list>` — limit to AL classes (e.g., `--class=AL-05,AL-11,AL-15,AL-28`). Legacy names map through `align-detect` § The legacy class map; a name that maps to no AL class (or to an owner class such as `security`) is refused with its owner named, never silently dropped.

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
4. SCAN-FRESH      — for the resolved area: `align-detect --scope=<paths>` against current source (align detectors + installed owner detectors), the AL-01 quote check, then refute-before-report § 10 for every candidate. NO cache lookup, NO ledger-row lookup as input.
5. TRIAGE          — owner rows → owner lines (no edit); T2g rows → one ratification line per rule; the rest split trivial / standard / heavy; dispatch `@align-evidence-auditor` over the fresh rows. Rows it REJECTs do not reach FIX; out-of-domain rows leave with their destination named.
6. FIX             — find-and-align per align-owned row (one commit per row; only the matched expression; tests read-only)
7. VERIFY          — the ladder: align-sweep-gate.py ladder (oracle, approval, diffkind, lock-paths, scope, redetect, consistency, names, roundtrip, ratchet, lock-count, vacuous) + L9 lint/types/tests + L10a zero diff (EQ) or L10b approved visual diff (VC)
8. RECORD-LEDGER   — best-effort: if a ledger exists, update matching rows. If not, leave alone (or create new entries if --register-ledger)
9. SUMMARY         — end-of-run report
```

Heavy-tier findings still get the supervised loop (reviewer pause). The discipline floor doesn't change — only the input source (your description vs. ledger rows).

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

### Owner lines (what recheck reports and does not close)

`align-detect` § The class ledger is the routing table; recheck never re-decides it. For each row whose closer is not align, print one owner line with the site, the class, the owner's detector and the owner's fix command, and make no edit:

| The row is | Owner line |
|---|---|
| a security class (injection, XSS, secret, auth gate, tenant filter) | `owner: security → /security-fix` (always installed) |
| performance or data (N+1, missing index, cache, sequential await) | `owner: performance → /perf-fix` · `owner: database → /db-fix`; `(not installed)` when absent — then the one carve-out in `find-and-align` Step 1 applies (an idiom the oracle names, with a **measured** failing-first baseline) |
| silent catch, unhandled I/O, dead code, a diverged copy, SOLID, complexity | `owner: code-quality → /quality-fix` |
| an envelope or error shape against a **declared** contract (AL-23) | `owner: backend → /backend-fix`; no contract declared → `/polish` |
| casing or pagination uniformity (AL-24, AL-25), schema naming | `owner: backend / database → /polish` (the introduce-finish command; recheck has no verb for it) |
| new copy, catalog defects (AL-26 non-EQ, AL-27), an a11y fix with no wrapper prop | `owner: frontend → /frontend-fix` |
| a token literal with no exact token, a token or state that does not exist yet | `/polish` (AL-06 may also close as VC with a human approval) |
| a wrapper gap (P-09) | `/unify-surfaces` |

Owner rows whose closer **is** align — an EQ token row from `design-token-audit`, an EQ catalog-key row from `i18n-scan`, a re-route through a public surface the oracle names — go through `find-and-align` like any align row. Without the owner pack installed, its classes print `N/A (owner pack <x> not installed)`.

Per-finding output streams to `ai/align/runs/<YYYY-MM-DD-HHMMSS>-recheck.log`. End-of-run summary surfaces to user.

```
Align recheck — paths: <modules-root>/orders/, <modules-root>/store/

Pre-flight:                    PASS (clean tree, CI green, oracle: T1 3 · T2 14 · T2g 4)
Candidates:                    31 → AL-01 dropped 2 → verified: 9 findings · 3 unconfirmed · 4 hardening · 13 refuted
  By class:
    AL-11 raw primitive:       4
    AL-05 token = value:       2   (routed from design-token-audit, EQ → align closer)
    AL-15 gate:                1
    AL-16 file name:           2

Fixes applied:
  A058 (AL-11)   fixed  EQ  raw ky import → @acme/http apiClient (V400; defaults reproduce the options)
  A061 (AL-05)   fixed  EQ  '#d92d20' → var(--color-danger); zero computed-style diff light + dark (V394)
  A066 (AL-15)   fixed  FN  delete action wrapped in <Can action="orders.delete">; render test as viewer (V401)
  A071 (AL-16)   fixed  EQ  orderRow.tsx → OrderRow.tsx (git mv; tsc --noEmit --incremental false green; V402)

Pending:
  A069 (AL-06)   pending-approval     13px → --space-3 changes pixels; diff images in ai/align/runs/…/A069
  —              pending-ratification ai/conventions.md:41 "Store files end in .store.ts" (generated) — confirm it

Owner lines (no edit here):
  src/orders/report.ts:88        security · string-built SQL      → /security-fix (A067 routed; it used to halt on a missing idiom)
  src/orders/list.service.ts:44  database · query per element     → /db-fix (A112 routed; never closed here without a measured baseline)
  src/store/cart.ts:12           code-quality · empty catch        → /quality-fix (error-handling-scan)

Halts:
  A073 (AL-11)   wrapper gap: the raw dialog uses `modal={false}`, which @acme/ui Dialog does not expose → /unify-surfaces

Sweep gates:                   consistency PASS · scope PASS · lock-paths PASS · names PASS · ratchet PASS
Total impact:
  Net diff (structural):       +2 / -14 = -12 lines
  Test suite:                  PASS (count 212 → 212)
  Wall-clock:                  3m 48s

Next:
  Approve A069 or send it to /polish; confirm ai/conventions.md:41 (/setup-project --refine).
  /unify-surfaces dialog for A073 · /security-fix, /db-fix, /quality-fix for the owner lines.
  Re-run /align-recheck <modules-root>/orders/ to confirm.
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
- **Same discipline as /align-phase.** Per-finding: ROUTE → DETECT → DECIDE → FIX → VERIFY → RECORD (`find-and-align`). One commit per finding. Closure verbs from the 21-verb vocabulary only. Net-lines ≤ 0 for structural rows. Tests and snapshots read-only.
- **Owner rows are lines, not fixes.** Security, performance, data, error handling, API contracts and new copy are closed by their owners' fix commands.
- **Tier defaults preserved.** Trivial / standard / heavy auto-routes per finding.
- **Halts are aggregated, not blocking.** A halted finding surfaces in the summary; other findings continue.
- **No silent abstractions.** Functional fixes USE existing idioms; missing idioms halt the row, route to `/setup-project --refine`.
- **Idempotent.** Re-running drains halts as their causes resolve.

## Failure modes

- **No findings match the path** — halt; surface "no ledger rows have scope or evidence inside <given paths>". Suggest `/align-recheck <path> --rescan-fresh` to surface new findings.
- **A matched finding's evidence file is deleted** — mark `archived-pre-existing`; skip.
- **Idiom missing** for a functional row — halt that row; surface in summary; rest continues. User runs `/setup-project --refine` to add the idiom, then re-runs recheck.
- **Many findings halt with same root cause** — surface as a cluster ("8 findings halted: wrapper gap, `@acme/ui` Dialog has no `modal` prop") so the user fixes upstream once.

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
/align-recheck the order pages --class=AL-11,AL-15

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

### Skills
- `.claude/skills/align-detect/SKILL.md` — the scoped detection sweep and the class ledger (owner, closer).
- `.claude/skills/find-and-align/SKILL.md` — the per-row proof ladder.
- Owner detectors, when their packs are installed: ui-ux `design-token-audit`, frontend `i18n-scan` and `a11y-code-scan`, code-quality `architectural-diagnosis`, backend `edge-error-scan` and `api-consistency-audit`. Their findings close through their own fix commands except the EQ rows `align-detect` marks as align's.

### Cross-pack
- `migration/commands/migration-recheck.md` — sibling pattern in migration; this command mirrors it for align.

### Rules
- `.claude/rules/align-discipline.md` — the discipline this command enforces.
