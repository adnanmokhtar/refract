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

## The loop (5 steps)

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

### 2. DECIDE — V1-parity by default

For each gap with `closure: code-edit`:
- **Default verb is "remove V2 deviation to match V1"**. Never "draft ADR to legitimize V2."
- ADRs are the path of last resort for user-explicit divergence — not the agent's default closure. (Phase 7 lesson: 6 ADRs that should have been code edits.)
- Surface to user ONLY when: V1 has a known bug V2 already fixed; V2's deviation has a security/privacy/legal rationale; the audit can't determine V1's actual behavior.

For ambiguous cases, present three options to user:
1. Match V1 (default — code edit)
2. Keep V2 (requires user-authored ADR)
3. Deprecate V1 feature (requires user-authored ADR)

Wait for explicit choice. Do not silently pick.

### 3. FIX — direct code edits

Apply the closure verb for each gap. Rules:

- **Default-true wrapper props MUST be set explicitly when removing UI affordances.** Removing a `@delete-selected` event handler does NOT hide the underlying button — `<CrudActions>`, `<TableHeader>`, `<TableActions>` and similar wrappers default their `show-*` / `can-*` props to `true`. To hide a button: pass `:show-delete="false"` / `:can-delete="false"` explicitly. Removing the handler alone is the F040-class default-true bug.
- **i18n keys land in BOTH locales** (typically `en.ts` + `ar.ts`) at the same path. Missing-locale = silent break in the alt locale.
- **No "while I'm here" cleanups.** One feature per fix run.
- **No V1 modifications.** V1 is the parity oracle.
- **Match V2 wrappers, not V1 raw components.** No raw `<Dialog>` / `<Paginator>` / `<Dropdown>` / `<form>` in pages where V2 wrappers exist (`<BaseModal>` / `<CrudPaginator>` / `<BaseDropdown>` / `<BaseForm>`). Re-derive layout from V2's gold-standard equivalent.

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

DETECT:  <N> gaps found (P0=<a> P1=<b> P2=<c>)
DECIDE:  <ok> code-edit closures, <esc> escalated to user
FIX:     <files> files edited (<lines>+/<lines>- LOC)
VERIFY:  typecheck ✓  lint ✓  parity ✓
RECORD:  ledger row → done; audit at ai/migration/audits/<feature>.md

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
