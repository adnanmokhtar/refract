---
description: Default V1→V2 port loop. Detect → Decide → Fix → Verify → Record. Single-agent dispatch, shared 5K-token context blob, code edits as deliverable. Routine ports use this; reserve /port-feature --heavy for security-sensitive / contract-breaking / cross-repo work.
kind: command
pack: migration
---

# /find-and-fix <feature>

## The Premise (read this first, internalize, do not deviate)

**V1 is production. V1 is correct.** Real users use V1 every day. Every behavior in V1 — every button, field, locale key, validation, ordering, permission gate, query param, status code — is the intentional truth, unless V1 has a documented bug (rare).

**The agent's job is exactly this:**
1. Find what V1 has that V2 doesn't have, OR what V2 has differently.
2. Port V1's behavior to V2 — using **V2's structure** (V2's modules, primitives, wrappers, naming, layer boundaries). Never copy V1's shape.
3. Remove what V2 has that V1 doesn't have (V2-only buttons / routes / fields). V1 wins.

**The agent does NOT:**
- Ask the user to validate whether V1's behavior is correct. **V1 IS the validation.**
- Ask the user about cosmetic deviations (empty cell text, swatch vs picker, locale-key drift, padding, ordering). **V1 wins. Edit V2.**
- Surface "do you want option A, B, or C" prompts mid-run. **V1 wins. Edit V2.**
- Draft an ADR to legitimize V2's deviation. **V1 wins. Edit V2.**

**The agent ONLY asks the user when:**
- The fix needs another repo (cross-repo blocker — genuinely cannot proceed without external confirmation).
- V1 has a known security/privacy/legal regression (V2's deviation is the auth-correct side; rare).
- V1 source is genuinely ambiguous (file missing, no caller, contradictory signals).

That's it. Three escalation triggers. Everything else is silent V1-parity edits, batched into one end-of-run summary.

**ADR pre-check (mandatory before removing V2-only features or reverting V2 deviations):**

Before applying a V1-parity edit that would (a) remove a V2-only feature OR (b) revert a V2 deviation toward V1, the agent MUST scan `ai/decisions/` for an accepted ADR documenting the divergence. Match by feature name, file path, or behavior keyword. If an ADR with `Status: accepted` exists, treat the V2 deviation as **intentional**: do NOT edit, do NOT remove. Surface it in the summary as a 1-line `ADR-NNN preserved: <V2 deviation> kept per <accepted ADR title>` note. This protects intentional V2 improvements (new buttons, accessibility fixes, route reorganizations, deprecation of obsolete V1 behavior) from getting silently reverted.

If no ADR is found, proceed with the V1-parity edit as the default rule says.

**The simple loop.** Code edits are the deliverable; docs only when they enable a code change. Replaces the 7-phase ceremony for routine ports — most rows in the ledger are trivial-tier and ship via this command.

## When to use

- Default for any ledger row not flagged P0 / cross-repo / security-sensitive / write-path-mutation / contract-break.
- Resuming a parked simple port.
- Closing a parity gap surfaced by `/migration-status` triage.

Use `/port-feature --heavy` instead when audit flags any of: P0 finding, cross-repo blocker, contract break, security/privacy/legal regression, write-path data-mutation, storefront blast radius. The heavy ceremony is rare-by-design.

## Flags

- `--plan` — run INVENTORY + ROUTING FLOOR + DETECT (steps 0–1, read-only), then STOP before FIX. Emit the gap list + tier-floor decision as a full handoff plan under `.claude/plans/` (path + Plan ID printed); make NO code edits, write NO ledger row. Full contract: `templates/snippets/plan-flag.md`. Hand the plan to `/execute-plan <file>` (or `/find-and-fix <feature> --from-plan <file>`) to apply the fixes.

## The loop (6 steps)

### 0. INVENTORY — V2 first, V1 second (added 2026-05-01, Phase 9 lesson)

**Mandatory pre-step. Skipping it is the canonical Transposition Trap trigger.**

Before any V1 read, produce two artifacts (required at every tier — see migration-discipline.md § Reuse-Before-Create):

1. **Mapping doc** at `ai/migration/mapping/<feature>.md` — a 2-column table mapping every V1 surface in the feature to its V2 equivalent. The V2 column entries come from THIS project's gold-standard inventory, read from `.claude/_extracted-codebase.md § Gold standards` + `_extracted-idioms.md` (populated by `/setup-project --refine`). Universal shape:
   ```
   | V1 surface | V2 equivalent (wrapper / util / type / pattern) |
   |---|---|
   | <V1 surface 1>  | <V2 equivalent named in _extracted-idioms.md> |
   | <V1 surface 2>  | <V2 equivalent named in _extracted-idioms.md> |
   | ...             | ... |
   ```
   The specific wrapper / util / hook / class / pattern names are project-specific and live in the per-project anchors — do NOT hardcode any here. If `_extracted-idioms.md` is empty, halt and run `/setup-project --refine` before continuing the port.

   Auto-fail at gate (`check_v2_mapping_doc`) if missing or has zero mapping rows.

2. **API samples** at `ai/migration/api-samples/<feature>/<endpoint>.json` — captured real responses, ONE per endpoint the service calls. Required only if the port touches the project's service / data-access layer (the path convention is project-specific; see `_extracted-codebase.md`). The V2 type's field names + nullability are derived from this sample, NOT guessed from V1 caller code. Auto-fail at gate (`check_api_response_sample`) if missing.

If the mapping doc surfaces "no V2 wrapper exists for X" → halt, surface to user, do not author a custom one without explicit approval (otherwise = Reinvented Wrapper anti-pattern).

### 0.5. ROUTING FLOOR — mechanical tier minimum (runs BEFORE DETECT; overrides auditor judgment)

**This is a pre-route check, not a judgment call.** Before the auditor sets a tier, grep the feature's V1 + V2 paths (and any diff already staged) for surface signals. If ANY of these surfaces is touched, the row's tier floor is **≥ standard** — regardless of what the auditor would otherwise classify. A trivial classification on one of these surfaces is a routing bug, not a fast path.

| Surface | Mechanical signal (stack-conditional; extend per `_extracted-idioms.md`) | Floor |
|---|---|---|
| **Write-path / data mutation** | `INSERT`/`UPDATE`/`DELETE`/`UPSERT`, repository `save`/`create`/`update`/`delete`/`destroy`, ORM `transaction`, queue publish/emit on a write | ≥ standard |
| **Auth / permission** | auth guard / middleware, `can*` / `hasPermission` / `authorize` / role check, session / token mint, `:can-*` / `:show-*` permission props | ≥ standard |
| **Contract surface** | DTO / serializer / response-envelope / API route handler / public type export / OpenAPI schema | ≥ standard |

Additionally, if the surface is **write-path AND (auth OR contract)** OR carries a P0 signal (data-loss, auth-bypass, tenant-leak, payment), the floor is **heavy** → STOP and route to `/port-feature --heavy` (this command does not handle heavy rows). 

The floor only ever *raises* the tier; it never lowers it. Record the floor decision in the audit (`routing_floor: standard (write-path: <v2-path:line>)`) so the gate can see why a row that "looks trivial" is standard. Skipping this check is how a silent auth-gate drop or an unguarded write ships under the trivial fast path.

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
| Audit cannot determine V1 behavior (V1 source ambiguous, file missing) | `user-decision` | YES — halt, surface |

**Forbidden:** the auditor / find-and-fix MUST NOT emit `user-decision` for P2 gaps. The Phase 7 anti-pattern (auditor asking "should `--` be `----------`?") is exactly the noise this rule kills. If V2 deviates from V1 on cosmetic surface, the answer is always "edit V2 to match V1" without asking.

**Batched end-of-run summary** (presented once, after FIX + RE-DETECT + VERIFY succeed):
```
Auto-applied (no prompt): <N> P1 + <M> P2 closures
  - G3 form-field: re-added ColorPicker widget to match V1
  - G5 permission-gate: added :can-delete="hasPermission(...)" to TableHeader
  - G7 locale-keys: restored Inventory.Variants.* keys
  ...
User-decision required (cross-repo / P0): <K>
  - G1 <example field name divergence> (upstream API confirmation needed)
  - G2 <example endpoint existence> (upstream API confirmation needed)
```

The user reviews the auto-applied list AFTER the run, in one read, not interrupted N times during the run.

**Hard rule:** if you find yourself about to ask the user a question on a P1 or P2 gap — STOP. Default to V1, edit, and add to the summary. The user can override later in a follow-up run; agent self-doubt is not a closure.

### 3. FIX — direct code edits

Apply the closure verb for each gap. Rules:

- **Default-true wrapper props MUST be set explicitly when removing UI affordances.** Removing a `@delete-selected` event handler does NOT hide the underlying button — `<CrudActions>`, `<TableHeader>`, `<TableActions>` and similar wrappers default their `show-*` / `can-*` props to `true`. To hide a button: pass `:show-delete="false"` / `:can-delete="false"` explicitly. Removing the handler alone is the F040-class default-true bug.
- **i18n keys land in EVERY declared locale** at the same key path. Missing-locale = silent break in the alt locale. The locale file format + paths are project-specific (declared in `_extracted-idioms.md`).
- **No "while I'm here" cleanups.** One feature per fix run.
- **No V1 modifications.** V1 is the parity oracle.
- **Match V2 wrappers, not V1 raw library components.** Use the project's shared wrappers in place of the underlying UI-library / framework primitives wherever a wrapper exists. The specific wrapper-vs-raw mapping is stack-specific and lives in your project's `_extracted-idioms.md`; the per-stack pack rule (`frontend/rules/migration-frontend.md` for frontend ports) enumerates fingerprints the validator catches. Re-derive layout from V2's gold-standard equivalent feature, not from V1's template.
- **Reuse-Before-Create.** Consult the mapping doc from step 0 for every authored line. If a shared entry exists in the project's `_extracted-idioms.md` for the surface you're about to write — use it; do NOT author a custom equivalent. Triggers the Reinvented Wrapper anti-pattern.
- **Derive types from API samples.** Field names + nullability + nested shape come from `ai/migration/api-samples/<feature>/`. Do NOT type a service response by reading V1 caller code; V1 may be reading untyped responses and silently mismatching. Triggers the Guessed Type anti-pattern.
- **No silent catches.** Every `catch` either calls the project's error handler (named in `_extracted-idioms.md`) OR includes a comment + debug log explaining recovery. Empty / silent catches produce consumer states indistinguishable from real failures. Triggers the Silent Catch anti-pattern.
- **No consumer compensation for provider gaps.** If the upstream returns wrong field names / missing fields / different shape, file the upstream ticket and mark the row `status: halted` with the explicit dependency. Do NOT map fields locally to "make it work". Triggers the Consumer Compensation anti-pattern.
- **Lifecycle / data-fetch hooks must match the component's actual mount semantics** (per the project's framework conventions in CLAUDE.md / `_extracted-idioms.md`). A page-level hook chosen for a nested child component that mounts under different conditions never fires. Triggers the Wrong Lifecycle Hook on Nested Child anti-pattern.
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

No new parity tests are required for trivial-tier ports — the audit + ledger note carry the risk register per `ai/patterns/migration-guardrails.md § Tier artifact specs → Trivial-tier artifact spec (audit + code only)`. If the audit flags a missing test as a P1 gap, that promotes the row to standard-tier (≥10 fixtures) per the discipline rule.

**Self-validate the artifacts before RECORD.** Run `~/.claude/scripts/validate-migration-artifacts.sh --feature=<feature>`. This is the SAME tier-scoped check the phase gate runs — running it here catches an unequal `gaps_in`/`gaps_closed`, a missing mapping doc / API sample, a thin standard-tier corpus, an un-measured perf candidate, or a `done`+`parity_test: passing` row with no recorded parity-run artifact (`check_parity_run_report`) while the context is hot. Non-zero exit → do NOT record the row as `done`; fix the flagged artifact and re-run. A row that can't pass its own per-feature validation is not done.

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
6. **Deferred gap with no destination** — one or more gaps cannot be closed in this run (structural blocker, complex restructure, awaiting cross-repo) AND the user has not assigned a destination: target phase number, ADR ID, or `/migration-park`. Halt and surface the open gap(s). The ledger row is recorded as `status: halted` with `gaps_in: <N>` and `gaps_closed: <M>` (M < N). The row MUST NOT be recorded as `done`. Before the phase gate can pass, the user must either: (a) fix the gaps (re-run `/find-and-fix`), (b) write an ADR and set `intentional_break: ADR-NNN`, or (c) run `/migration-park <feature>` with a rationale. A halt note with no destination is a floating obligation — the gate will REFUSE.

Halts log to `ai/migration/halts/<feature>-<iso>.md` per `migration-discipline.md` § halts convention. Halt files for condition 6 MUST include: gap description, why it can't be closed now, and one of: `target_phase: <N>` / `pending_adr: true` / `recommend_park: true`.

## Output

```
/find-and-fix <feature>:

DETECT:    <N> gaps found (P0=<a> P1=<b> P2=<c>; ADD=<x> DEL=<y> CHG=<z>; FE=<f> API=<g>)
DECIDE:    <ok> code-edit closures, <esc> escalated to user
FIX:       <files> files edited (<lines>+/<lines>- LOC)
RE-DETECT: gaps_in=<N> gaps_closed=<N> (must match) ✓; new=<0> regressed=<0>
VERIFY:    typecheck ✓  lint ✓  parity ✓  validator ✓ (--feature=<feature>)
RECORD:    ledger row → done; audit at ai/migration/audits/<feature>.md

Not validated: <suites/environments skipped, manual checks recommended | none — full suite ran>
Risks:         <residual risk worth a human glance | none identified>
Revert:        git revert <sha>   (one commit for this feature)

Halts: <none | list>
```

**Honesty clause (mandatory).** `Not validated:` / `Risks:` / `Revert:` appear in every run's output before the `Halts:` line. `VERIFY ✓` alone is insufficient — name what did NOT run (skipped suites, unavailable environments, recommended manual checks) or state `none — full suite ran`; name residual risk or `none identified`; give the exact git revert command for this run's commit. Omitting the negative space is the Trusted-Summary failure mode. Sibling commands (`/migrate`, `/port-feature`, `/migration-fast`) mandate the same clause.

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
- `port-feature.md` — `--heavy` flag for the rare 7-phase ceremony case
- `migration-phase.md` — chains via this command per phase row at default tier
