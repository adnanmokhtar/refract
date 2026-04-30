---
description: Default V1→V2 port loop. Detect → Decide → Fix → Verify → Record. Single-agent dispatch, shared 5K-token context blob, code edits as deliverable. Routine ports use this; reserve /port-feature --heavy for security-sensitive / contract-breaking / cross-repo work.
kind: command
pack: migration
---

# /find-and-fix <feature>

The simple loop. **Code edits are the deliverable; docs only when they enable a code change.** Replaces the 6-phase ceremony for routine ports — most rows in the ledger are trivial-tier and ship via this command.

## When to use

- Default for any ledger row not flagged P0 / cross-repo / security-sensitive / write-path-mutation / contract-break.
- Resuming a parked simple port.
- Closing a parity gap surfaced by `/migration-status` triage.

Use `/port-feature --heavy` instead when audit flags any of: P0 finding, cross-repo blocker, contract break, security/privacy/legal regression, write-path data-mutation, storefront blast radius. The heavy ceremony is rare-by-design.

## The loop (6 steps)

### 1. DETECT — line-by-line V1↔V2 read

Single `parity-auditor` dispatch. Pass a **shared 5K-token context blob** (see § Context blob) — NOT full files. The agent reads V1 + V2 source line-by-line and outputs a gap list:

```
Gap G1: <one-line description>
  V1: <v1-path:line> — <1-line excerpt>
  V2: <v2-path:line> — <1-line excerpt> (or "missing")
  Severity: P0 | P1 | P2
  Closure verb: code-edit | user-decision | escalate-heavy
```

Halts:
- Any P0 → halt; surface; user decides escalate-heavy or accept-as-found.
- Cross-repo blocker (V2 fix needs API/sibling repo change) → halt; surface; route to `/cross-repo-task`.
- User-decision-needed (V1 has X, V2 has Y, both arguably correct) → halt; surface options.

No P0 + no cross-repo + no user-ambiguity → proceed to step 2.

### 2. DECIDE — V1-parity by default, no chatter

**The DEFAULT is auto-fix. The agent does NOT ask questions on cosmetic / V2-only-extras / locale / ordering / wrapper-shape gaps.** It applies V1-parity edits silently and reports them in a batched summary at the end. Asking the user mid-run is a token-waste anti-pattern.

**Severity-driven dispatch (mandatory):**

| Severity | Closure | User prompt? |
|---|---|---|
| **P0** with cross-repo / security / privacy / data-loss / auth-bypass signal | `user-decision` | YES — halt, surface, wait |
| **P0** without that signal | `code-edit` (V1-parity) | NO — auto-fix |
| **P1** | `code-edit` (V1-parity) | NO — auto-fix |
| **P2** (cosmetic, locale-key drift, V2-only-extras, empty-cell text, swatch-vs-picker, etc.) | `code-edit` (V1-parity) — silent | NO — auto-fix; batched into final summary |
| Audit cannot determine V1 behavior (V1 source ambiguous, file missing) | `escalate` | YES — halt, surface |

**Forbidden:** the auditor / find-and-fix MUST NOT emit `user-decision` for P2 gaps. The Phase 7 anti-pattern (auditor asking "should `--` be `----------`?") is exactly the noise this rule kills. If V2 deviates from V1 on cosmetic surface, the answer is always "edit V2 to match V1" without asking.

**Batched end-of-run summary** (presented once, after FIX + RE-DETECT + VERIFY succeed):
```
Auto-applied (no prompt): <N> P1 + <M> P2 closures
  - G3 form-field: re-added ColorPicker widget to match V1
  - G5 permission-gate: added :can-delete="hasPermission(...)" to TableHeader
  - G7 locale-keys: restored Inventory.Variants.* keys
  ...
User-decision required (cross-repo / P0): <K>
  - G1 hex_code vs code wire-name (capsolah-api confirmation needed)
  - G2 colors/export endpoint existence (capsolah-api confirmation needed)
```

The user reviews the auto-applied list AFTER the run, in one read, not interrupted N times during the run.

**Hard rule:** if you find yourself about to ask the user a question on a P1 or P2 gap — STOP. Default to V1, edit, and add to the summary. The user can override later in a follow-up run; agent self-doubt is not a closure.

### 3. FIX — direct code edits

Apply the closure verb for each gap. Rules:

- **Default-true wrapper props MUST be set explicitly when removing UI affordances.** Removing a `@delete-selected` event handler does NOT hide the underlying button — `<CrudActions>`, `<TableHeader>`, `<TableActions>` and similar wrappers default their `show-*` / `can-*` props to `true`. To hide a button: pass `:show-delete="false"` / `:can-delete="false"` explicitly. Removing the handler alone is the F040-class default-true bug.
- **i18n keys land in BOTH locales** (typically `en.ts` + `ar.ts`) at the same path. Missing-locale = silent break in the alt locale.
- **No "while I'm here" cleanups.** One feature per fix run.
- **No V1 modifications.** V1 is the parity oracle.
- **Match V2 wrappers, not V1 raw components.** No raw `<Dialog>` / `<Paginator>` / `<Dropdown>` / `<form>` in pages where V2 wrappers exist (`<BaseModal>` / `<CrudPaginator>` / `<BaseDropdown>` / `<BaseForm>`). Re-derive layout from V2's gold-standard equivalent.
- **Any NEW file added to V2 MUST follow V2's structure — never V1's.** This applies to every layer: frontend (pages, components, composables, locales), backend (controllers, services, repositories, DTOs, modules), and AI (agents, skills, commands, rules). Before writing a new file:
  1. **Find V2's gold-standard equivalent** for the same shape (e.g., V2's CRUD page for a new CRUD page; V2's service + repository pair for a new service; V2's agent definition for a new agent). The blob's `gold_standard_v2_files:` field names them; if missing, halt and ask the user to point at one.
  2. **Mirror its shape**: same module path (`<v2-root>/<layer>/<module>/<kind>/...`), same file naming (PascalCase / camelCase / kebab-case per V2 convention), same layer boundaries (domain framework-free, application uses ports, infrastructure is the adapter), same DI / ORM / error envelope / validation / logging primitives, same shared wrappers and base classes.
  3. **Forbidden**: copy-pasting a V1 file and renaming it; placing a new file at V1's path; importing V1 utilities into V2; using a primitive V2 doesn't use (e.g., raw `axios` when V2 has a typed client; raw `try/catch` when V2 has a Result envelope).
  4. The RE-DETECT step (3.5) flags any new file whose shape diverges from the named gold-standard as a `regressed` finding — the row halts.

### 3.5. RE-DETECT — confirm every gap is closed (mechanical gate)

**This step is mandatory. Skipping it is the failure mode that ships partial fixes.**

After step 3 (FIX), re-dispatch `parity-auditor` against the now-edited V2, with the SAME 5K context blob from step 1 PLUS the original gap list. The agent's job:

1. Re-read V1 + V2 line-by-line for each gap from step 1.
2. For each gap, return one of: `closed` (V2 now matches V1), `still-open` (no edit landed or edit insufficient), `regressed` (edit broke an unrelated axis).
3. Surface any NEW gaps the edits introduced (e.g., a wrapper-prop change that hid a sibling button by accident).

**Halt rules**:
- `gap_count_in != gap_count_closed` → HALT. Do not advance to VERIFY. Surface the open list and ask the user: refix, escalate, or accept.
- Any `regressed` → HALT. The fix introduced a new break.
- Any NEW gap surfaced → HALT. Either fold into this run (one more FIX → RE-DETECT cycle) or escalate.

**No silent advance.** The ledger row records `gaps_in: <N>` and `gaps_closed: <N>` — they must be equal before VERIFY runs. The audit verdict in step 5 cites this count; the validator's `check_gap_count_parity` (in `validate-migration-artifacts.sh`) reads both fields from the ledger row and HALTs if unequal or missing.

This is a single agent dispatch (same auditor, verify-mode), 5K blob input, ~2-5K output. Cheap. Mandatory.

### 4. VERIFY — typecheck + lint + parity tests stay green

Run the project's existing checks:
- `<typecheck-cmd>` (e.g., `npx vue-tsc --noEmit`, `tsc --noEmit`, `mypy`)
- `<lint-cmd>` (e.g., `npx eslint src/`, `ruff check`)
- Existing parity tests (if any) at `<parity-test-root>/<feature>/` — must stay green against the V1 commit pinned in the ledger row.

If any red:
- Typecheck/lint red → fix before continuing. Do not advance with broken V2.
- Parity-test red → either V2 fix is wrong (re-fix) or V1 oracle drifted (re-pin V1 + re-run; never loosen tolerance to make a test pass).

No new parity tests are required for trivial-tier ports — the audit + ledger note carry the risk register per `migration-discipline.md` § Trivial-tier artifact spec. If the audit flags a missing test as a P1 gap, that promotes the row to standard-tier (≥10 fixtures) per the discipline rule.

### 5. RECORD — ledger note + audit verdict

Two artifacts. Nothing else.

**Ledger row update** (in `ai/migration/ledger.md`):
```yaml
- id: <feature>
  status: done
  tier: trivial         # or standard if escalated by audit
  v1_commit_pinned: <sha>
  ported_at: <UTC ISO8601>
  audit: ai/migration/audits/<feature>.md
  audit_provenance: <parity-auditor agent run ID>
  gaps_in: <N>          # gap count from DETECT step 1
  gaps_closed: <N>      # gap count confirmed-closed by RE-DETECT step 3.5; MUST equal gaps_in
  notes: "<1-paragraph: what changed + why V1-parity match>"
```

**Audit verdict** (single `parity-auditor` dispatch — same agent that ran step 1, now in verify mode):
- Re-reads V1 + V2 with the now-applied edits.
- Confirms each gap from step 1 is closed.
- Writes verdict to `ai/migration/audits/<feature>.md` with `auditor_agent_id` frontmatter (provenance proof — see `parity-auditor.md` § How to read).
- Verdict criterion: **does V2 now match V1?** NOT "did the agent ship what the plan said?" (Phase 7 lesson: audits validated plan-execution, not parity.)

**No** contract file. **No** plan file. **No** perf-decisions file. **No** rollback runbook. **No** ADR drafts. Trivial-tier defaults from `migration-discipline.md` apply — heavy ceremony is opt-in via `/port-feature --heavy`.

## Context blob (the shared 5K)

The context blob passed to the single agent dispatch (used in BOTH step 1 detect and step 5 verify):

```yaml
feature_id: <ledger row id>
v1_commit_pin: <sha>          # from ledger row
v1_path: <v1-root>/<entry-file>
v2_path: <v2-root>/<entry-file>
audit_summary: |
  <8-15 lines of prior audit context if exists, OR
   the row's notes from /migration-scan, OR
   "first-pass audit — no prior context">
gold_standard_v2_files:        # 1-3 files agent reads BEFORE diffing V1
  - <v2-path:line> (e.g., the project's gold-standard CRUD page)
constraints:
  - V1-parity default closure
  - default-true wrapper-prop trap
  - i18n both locales
  - V2 wrappers not raw components
```

Cap at 5K tokens. The agent does NOT receive full V1+V2 files in the prompt — it reads them via tool calls during its run. Passing files inflates input by 50K+ per dispatch (Phase 7 lesson: parallel sub-agents each re-read 200-360K tokens of duplicate context).

**No parallel sub-agents.** Single dispatch for detect; single dispatch for verify. If the feature truly needs parallel (multi-file scope, multiple gold standards) → that's a heavy-tier signal; escalate to `/port-feature --heavy`.

## Halt conditions

The command halts (refuses to advance, surfaces options, waits for user) on:

1. **P0 finding** — security regression, data-loss, auth bypass, tenant-leak. Surface; user routes to `/port-feature --heavy` or accepts P0.
2. **Cross-repo blocker** — V2 fix needs API or sibling-repo change. Surface; user routes to `/cross-repo-task` (workspace-level orchestrator).
3. **User-decision-needed** — V1↔V2 divergence with legitimate-either-way verdict. Surface three options (match V1 / keep V2 + ADR / deprecate-V1 + ADR); wait.
4. **Audit cannot determine V1 behavior** — V1 source ambiguous, telemetry absent, no caller. Halt; user resolves before proceeding.
5. **Verify red that re-fix can't close** — V2 has structural blocker; escalate to `/port-feature --heavy` for full plan + parity tests.

Halts log to `ai/migration/halts/<feature>-<iso>.md` per `migration-discipline.md` § halts convention.

## Output

```
/find-and-fix <feature>:

DETECT:    <N> gaps found (P0=<a> P1=<b> P2=<c>; ADD=<x> DEL=<y> CHG=<z>; FE=<f> API=<g>)
DECIDE:    <ok> code-edit closures, <esc> escalated to user
FIX:       <files> files edited (<lines>+/<lines>- LOC)
RE-DETECT: gaps_in=<N> gaps_closed=<N> (must match) ✓; new=<0> regressed=<0>
VERIFY:    typecheck ✓  lint ✓  parity ✓
RECORD:    ledger row → done; audit at ai/migration/audits/<feature>.md

Halts: <none | list>
```

## Hard rules

- **One feature per invocation.** Bundling defeats per-row ledger tracking.
- **Single agent dispatch per step.** No parallel sub-agents at trivial-tier — that's heavy-tier signal.
- **Code edits are the deliverable.** Docs that don't enable a code change are waste.
- **V1-parity is the default closure.** ADR-as-closure is forbidden at trivial-tier; surface to user instead.
- **Default-true wrapper props are explicit.** Removing handlers without setting `:show-*="false"` / `:can-*="false"` is a default-true bug.
- **No V1 modifications.** Per `migration-discipline.md`.

## Cross-references

- `migration-discipline.md` § Required artifacts per feature — tiered floor, § Anti-bloat rules
- `migration-discipline.md` § "Default to V1-parity, ADR is opt-in"
- `parity-auditor.md` — the single agent dispatched
- `port-feature.md` — `--heavy` flag for the rare 6-phase ceremony case
- `migration-phase.md` — chains via this command per phase row at default tier
