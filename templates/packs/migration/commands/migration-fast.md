---
description: One-shot deep-migration phase runner. After /migration-scan + /migration-plan, ports every row in phase N — trivial / standard / heavy — in parallel waves respecting the dependency graph. Auto-routes per row (trivial+standard → /find-and-fix, heavy → /port-feature --heavy --unattended). Auto-runs /migration-gate at the end. Same discipline, same artifacts, same V2-structure enforcement as the manual flow — but parallel and unattended. Built for production-scale migrations with many modules and phases where serial wall-time is the bottleneck.
kind: command
pack: migration
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /migration-fast <N>

## The Premise (read this first)

**One command. Port the entire phase in parallel. Route each row to the right tier automatically.** This command is the fast path for ANY phase — it collapses the four-step intended flow (`/migration-phase --audit-only` → `/draft-phase-adrs` → `/migration-phase --chain` → `/migration-gate`) into a single invocation that ports **every row**, regardless of tier, in parallel waves respecting the dependency graph.

**The "fast" in fast** = (a) parallel dispatch — multiple sub-agents work the phase simultaneously; (b) automatic tier routing — trivial/standard rows go through `/find-and-fix`, heavy rows go through `/port-feature --heavy --unattended`, all dispatched by fast itself with no user choice required between commands; (c) lenient pre-flight — the run starts unless something is genuinely broken (missing ledger / plan / phase number).

**Nothing is skipped.** Every discipline check from the manual flow still runs:
- Every row still gets a `parity-auditor` agent dispatch (with `auditor_agent_id` provenance — `check_audit_provenance` enforced).
- Every audit still enumerates per-axis (no `etc.` / `...` / `&...` hand-waves — `check_audit` enforced).
- Trivial/standard ports run `/find-and-fix` with its mandatory RE-DETECT step (`gaps_in == gaps_closed` enforced).
- Heavy ports run `/port-feature --heavy --unattended` with the full 7-phase ceremony (contract / plan / parity tests / perf decisions / runbook / audit).
- Every artifact the row's tier requires is still produced.
- `/migration-gate <N>` still runs at the end with the full tier-scoped 14-check matrix.
- ADR-needed halts surface to `ai/migration/halts/` per row — they don't halt the whole run, but they do block that specific row from advancing until the user resolves.

**What it removes** is the wall-clock waste between steps — the human-watch pauses, the manual checkpoints, the "run command, wait, run next command, wait, run next" cycle. AND the artificial sequential bottleneck — independent rows in the same dependency level run in parallel.

Use this for any phase where you want one command to drive the entire migration step. The output is: every row ported (or its halt note in `halts/`), gate verdict at the end, walk-away workflow.

The existing multi-step flow (`/migration-phase --audit-only` etc.) is **untouched**. Reach for it when you specifically want to inspect audits before any port, draft ADRs in batch before chain, or supervise per-row.

## When to use vs not

**USE `/migration-fast <N>`** for any phase. It handles all tiers — trivial rows go through `/find-and-fix`, heavy rows go through `/port-feature --heavy --unattended`, both routed automatically by fast itself.

**USE the manual flow** (`/migration-phase --audit-only` → `/draft-phase-adrs` → `/migration-phase --chain` → `/migration-gate`) only when you specifically want:
- Audit-only mode to inspect findings before any code is touched.
- Batch ADR drafting before any port runs (vs. ADR-needed rows surfacing as per-row halts).
- Per-row supervision with `--stop-on-halt` semantics.
- Sequential dispatch with no parallelism.

Fast mode does NOT silently downgrade heavy → trivial. Heavy rows still get the full 7-phase ceremony — fast just dispatches that ceremony in parallel with the trivial/standard rows of the same dependency level instead of forcing the user to run `/port-feature --heavy` separately afterward.

## What happens per row (deep migration, not lift-and-shift)

Fast dispatches `/find-and-fix` (trivial/standard) or `/port-feature --heavy --unattended` (heavy) per row. Both commands enforce the same anti-Transposition-Trap discipline. Here's the actual sequence per row, end-to-end — read this so you can verify fast doesn't just "add code":

### 0. Inventory V2 BEFORE reading V1 (mandatory pre-step)

Skipping this is "the canonical Transposition Trap trigger" per `migration-discipline.md`. Before any V1 read:

- Scan V2's gold-standard inventory: shared wrappers, utils, hooks, types, patterns from `_extracted-idioms.md`.
- Write `ai/migration/mapping/<feature>.md` — a 2-column V1-X→V2-Y table naming every V2 equivalent the port will reuse.
- Capture API samples to `ai/migration/api-samples/<feature>/` when port touches the service layer. V2 types derive from these, NOT from V1 caller code.

Validator `check_v2_mapping_doc` halts the gate if missing or empty.

### 1. Read V1 deeply (NOT skim)

**Trivial/standard** (via `/find-and-fix` DETECT step): parity-auditor reads V1 + V2 line-by-line; outputs gap list with `<v1-path:line> ↔ <v2-path:line>` for each divergence, severity per gap (P0/P1/P2).

**Heavy** (via `/port-feature --heavy` Phase 1, `extract-v1-contract` skill):
- Read EVERY file in V1's call graph end-to-end (no skim) — every conditional, error path, side effect, type, dependency call
- Read V1's tests; read git log (`git log --follow -p <path>`); read related issues
- Sample 100 production logs (anonymised) if available
- Inspect adjacent code that consumes V1 (`git grep` exported symbols / endpoints)
- Output: 9-section contract — Inputs / Outputs / Side effects / Business rules / Invariants / Perf characteristics / Caller assumptions / Edge cases / Known V1 bugs — every claim cited to `<path:line>`

### 2. Analyze V2 (gold-standard read BEFORE writing)

Hard rule from `port-feature.md` Phase 3: *"a V1→V2 port is NOT a copy-paste of V1. The new V2 code MUST follow V2's NEW structure"*.

The per-row sub-agent reads:
- V2's primitives (DI container, ORM, error envelope, logging facade, validation library) from `_extracted-idioms.md`
- V2's gold-standard equivalent file for the feature shape (project's CRUD page, settings page, etc.)
- 1–2 already-ported V2 features for shape reference
- The parity test infra location
- `migration-discipline.md` § Anti-patterns (The Transposition Trap + per-stack fingerprints)

Output: a "V2 patterns I will follow" note in the plan, listing the gold-standard files read + the specific patterns being mirrored.

### 3. Detect gaps (per-axis enumeration, NO hand-waves)

The audit enumerates EVERY axis where V1 and V2 differ. No `etc.`, no `...`, no `&...`, no `and so on`.

**Frontend axes** (when feature renders UI): form fields (every input enumerated), UI affordances (every button/link/dropdown), templated query params (every `?foo=&bar=` enumerated), event handlers, per-button permission gates, accessibility, DOM-equivalent assertions, reactive lifecycle hooks.

**Backend axes**: DTO shape, query-param surface, response-envelope, validator-stack, tenant-isolation, transaction boundaries.

Validator `check_audit` halts the gate on hand-wave tokens.

### 4. Move to V2 (re-derive, NOT copy-paste)

Hard rules from `migration-discipline.md` enforced per row:

- *"Structure → V2 wins; observable behaviour → V1 wins"* — file layout / component shape / naming / layering follows V2 unconditionally; behaviour (inputs, outputs, errors, side effects) follows V1
- Use V2's primitives, not V1's
- Match V2 wrappers, not V1 raw library components
- **Reuse-Before-Create** — consult mapping doc for every authored line
- Derive types from API samples, not V1 caller code
- No silent catches — every catch routes through the project's error handler
- No frontend compensation for backend gaps — file backend ticket; halt the row instead
- Default-true wrapper props set explicitly when removing UI affordances
- Lifecycle hooks chosen for the component's actual mount semantics
- *"Forbidden: copy-pasting a V1 file and renaming it; placing a new file at V1's path; importing V1 utilities into V2"*

Validators catch violations:
- `check_v2_structure` — stack-conditional fingerprint detection (Transposition Trap)
- `check_v2_mapping_doc` — Reinvented Wrapper detection
- `check_api_response_sample` — Guessed Type detection

### 5. Verify (`gaps_in == gaps_closed` mechanical gate)

After FIX, re-dispatch parity-auditor in verify-only mode. The agent re-reads V1 + V2 line-by-line for each gap, returns: `closed` / `still-open` / `regressed`. Surfaces any NEW gaps the edits introduced.

Halts:
- `gap_count_in != gap_count_closed` → halt the row
- Any `regressed` → halt the row (fix introduced new break)
- Any NEW gap surfaced → halt the row

The ledger row records `gaps_in: <N>` and `gaps_closed: <N>`; both fields must be populated and equal before the row flips to `done`. Validator `check_gap_count_parity` enforces this.

### 6. Run tests + typecheck + lint

- **Trivial**: standard CI tests pass; audit + ledger note carry the risk register (no separate parity test required at this tier)
- **Standard**: ≥10-fixture parity test against pinned V1 commit
- **Heavy**: ≥30-fixture parity test + tolerance.yaml + golden snapshots + property-based tests for invariants

All tiers: typecheck + lint must stay green. No tolerance loosening to make tests pass.

### 7. Record

- Ledger row: status, tier, v1_commit_pinned, ported_at, audit, audit_provenance, gaps_in, gaps_closed, parity_runs[]
- Audit verdict at `ai/migration/audits/<feature>.md` with `auditor_agent_id` frontmatter (provenance proof)
- Heavy only: 9-section contract, plan, perf-decisions, rollback runbook

---

**Bottom line**: every row in fast mode goes through scan-V1 + scan-V2 + understand + per-axis gap detection + V2-structure-aware port + mechanical verify. Fast just runs many of these per-row pipelines in parallel waves. The depth per row is identical to the manual flow.

## Pre-requisites (only the substantive ones — fast mode is lenient by default)

**Hard pre-requisites** (halt the run — these are real blockers):
1. `ai/migration/ledger.md` exists (produced by `/migration-scan`).
2. `ai/migration/plan.md` exists (produced by `/migration-plan`).
3. Argument `<N>` is a valid phase number from the plan.

**Soft pre-requisites** (warn + proceed — fast mode does NOT halt on these):
4. **Working tree dirty** → warn + proceed. Port commits will land on top of whatever's currently uncommitted. The ledger row's commit SHA in the artifact will be the post-port commit; if you want a clean separation, commit/stash first, but fast mode will not refuse to start. Pass `--strict-clean` to make this a halt.
5. **V1 branch dirty / detached** → warn + proceed using `git rev-parse HEAD` of V1 as the pin. Pass `--strict-clean` to halt instead.

The decision rationale: the user's intent in invoking `/migration-fast` is "just run". Tooling-state ceremony (anchor-injector backups, half-edited config files, an unrelated WIP) is not a parity risk — only V1/V2 source mutations during the run would be, and those are protected by mid-run discipline (the per-row commit-on-success path). Pre-flight ceremony that refuses to start is the exact friction this command exists to remove.

If a hard pre-requisite (1–3) fails → halt with a one-line remediation pointer.

## Phase 1 — Understand (the ask)

Inputs:
- `<N>` — phase number (required, positional).
- `ai/migration/plan.md § Phase <N>` — feature list + dependency order.
- `ai/migration/ledger.md` — per-feature state.

Optional flags (fast mode is lenient + parallel by default — flags subtract speed, they don't add safety):
- `--feature=<id>` — restrict to a single feature in phase N (retry / surgical).
- `--max-features=<N>` — cap how many features to attempt this run (default: all in phase N).
- `--max-parallel=<N>` — cap parallel sub-agents per dependency wave (default: 4). Lower = lower token burn + slower wall-clock.
- `--serial` — force sequential dispatch; one row at a time. Default: parallel within each dependency wave.
- `--no-gate` — skip the final `/migration-gate <N>` step.
- `--strict-clean` — halt if working tree (or V1 tree) is dirty. Default: warn + proceed.
- `--re-audit` — discard cached audits and re-run `parity-auditor` for every row. Default: reuse audits pinned to current V1 HEAD.

This command does NOT support:
- `--audit-only` — that's the manual flow's purpose; if you want audit-only, use `/migration-phase <N> --audit-only`.
- `--skip-heavy` — heavy rows are ported, not skipped. Fast routes them to `/port-feature --heavy --unattended`. If you want to defer heavy work, use `/migration-park <feature>` BEFORE running fast.

## Phase 2 — Organize (decompose the work)

The fast loop, in order:

```
1. PRE-FLIGHT     — verify hard pre-reqs (scan + plan + valid N); warn on dirty tree
2. AUDIT-ALL      — dispatch parity-auditor per row IN PARALLEL (one sub-agent per row,
                    each with its own 5K context blob); reuse cached audits pinned to V1 HEAD
2.5 ROUTING FLOOR — mechanical pre-route per row (OVERRIDES auditor tier, only ever raises):
                      if V1/V2 paths or staged diff touch write-path / auth / contract
                      surfaces → tier floor ≥ standard;
                      if write-path AND (auth OR contract), or any P0 signal → floor = heavy
3. TIER ROUTE     — per-row dispatch decision based on max(audit tier, routing floor):
                      trivial   → /find-and-fix <id>
                      standard  → /find-and-fix <id>
                      heavy     → /port-feature <id> --heavy --unattended
4. PARALLEL CHAIN — group rows into dependency waves (topological levels);
                    within each wave, dispatch all rows IN PARALLEL (capped at --max-parallel);
                    when wave completes, advance to next wave;
                    on per-row halt: log to halts/ + advance to next row
5. AUTO-GATE      — invoke /migration-gate <N>
6. REPORT         — compact end-of-run summary with per-row outcomes
```

Each step is an existing primitive — this command is the orchestrator.

## Phase 3 — Retrieve (read the right context)

For pre-flight + audit-all:
- `ai/migration/plan.md` — phase N feature list + `depends_on` graph.
- `ai/migration/ledger.md` — per-row state, tier, prior audit references.
- V1 root + V2 root paths (from `_extracted-codebase.md § Migration`).
- `_extracted-idioms.md` — gold-standard inventory the auditor cites.

The audit step itself reads V1 + V2 source per feature; this command does not preload those — `parity-auditor` does its own line-by-line reads per dispatch.

## Phase 4 — Generate (produce the output)

### 4a. PRE-FLIGHT (lenient — only halts on real blockers)

**Halt** before any agent dispatch if:

1. `ai/migration/ledger.md` missing → "run `/migration-scan` first".
2. `ai/migration/plan.md` missing → "run `/migration-plan` first".
3. No `Phase <N>` section in the plan → "phase `<N>` not in plan; valid phases: <list>".

**Warn + proceed** (do NOT halt — pass `--strict-clean` to upgrade these to halts):

4. Working tree dirty → print one-line warning: "working tree has <N> uncommitted change(s); fast-run will commit ports on top". Continue.
5. V1 branch dirty / detached → print warning: "V1 has uncommitted changes; pinning to current HEAD <sha>". Continue.

Load the phase N feature list with their `depends_on` graph. Topologically sort. Skip rows already at `status: done` (idempotent resume). Skip rows at `status: parked` or `status: deprecated`.

Output of pre-flight: a 1-line plan — "Phase `<N>`: `<X>` features to process (`<Y>` already done, `<Z>` parked/deprecated)" + any warnings emitted above.

### 4b. AUDIT-ALL (parity-auditor per row, parallel by default)

**Cache reuse**: before any new dispatch, scan `ai/migration/audits/` for an existing audit per row whose `v1_commit_pinned` matches current V1 HEAD AND whose `auditor_agent_id` is populated. Those are reused as-is — no re-dispatch. Only rows without a fresh audit get a new dispatch. Pass `--re-audit` to force re-dispatch for all rows regardless.

For each row needing audit, dispatch in parallel waves of `--max-parallel` (default 4). The discipline rule "no parallel sub-agents" in `migration-discipline.md § Anti-bloat rules` applies to **within-row** sub-agent dispatch (e.g., a /port-feature dispatching 4 sub-auditors for 4a/b/c/d). Row-level parallelism — one independent agent per ledger row, each with its own 5K context blob — is **explicitly allowed and is the speed multiplier this command depends on**. Each sub-agent reads its own V1+V2 source independently; no shared state across parallel rows.

1. Build a 5K-token shared context blob per row (per `find-and-fix.md § Context blob`). Include: feature_id, V1 commit pin, V1 path, V2 path, ledger row notes, gold-standard V2 files (1-3) the auditor reads BEFORE diffing V1.

2. Dispatch `parity-auditor` agent — `Agent({subagent_type: "parity-auditor", prompt: <blob + audit instruction>})`. The agent's prompt MUST include:
   - Feature ID + V1 path:line entry points + V2 destination path:lines.
   - V1 commit hash to pin.
   - The 13 hard halts (by reference to `migration-discipline.md`).
   - The frontend axes list (form fields, UI affordances, templated query params, event handlers, per-button permission gates, a11y, DOM-equivalent, reactive lifecycle) — for frontend features only.
   - Explicit instruction: "Read V1 source line-by-line. Do NOT trust prior audit docs. Do NOT use `...`, `etc.`, `N+ filters`, `and so on`, `deferred to port-phase parity author`, or `by audit-by-inspection`. Enumerate every item in every axis table. Set `tier:` field per migration-discipline.md § Tier classification."
   - Output target: `ai/migration/audits/<feature-id>.md` (full structure per `migration-phase.md § 4d`).

3. Capture the agent's run ID; it lands in the audit doc's `auditor_agent_id` frontmatter (provenance proof — `validate-migration-artifacts.sh § check_audit_provenance` enforces this).

4. Read the audit's `tier:` field, then apply the **ROUTING FLOOR** (mechanical, overrides the auditor — only ever raises tier, never lowers). Grep the row's V1 + V2 paths (and any staged diff) for surface signals; the effective tier is `max(audit tier, floor)`:
   - **write-path** (`INSERT`/`UPDATE`/`DELETE`/`UPSERT`, repo `save`/`create`/`update`/`delete`, ORM transaction, queue publish on a write) → floor ≥ standard.
   - **auth / permission** (guard / middleware, `can*` / `hasPermission` / `authorize` / role check, session / token mint, `:can-*` / `:show-*` props) → floor ≥ standard.
   - **contract** (DTO / serializer / response-envelope / API route handler / public type export / OpenAPI schema) → floor ≥ standard.
   - **write-path AND (auth OR contract)**, OR any P0 signal (data-loss, auth-bypass, tenant-leak, payment) → floor = heavy.
   Stack-conditional signals extend per `_extracted-idioms.md`. Record the floor in the audit (`routing_floor: <tier> (<signal>: <v2-path:line>)`). This is the same floor `find-and-fix.md § 0.5 ROUTING FLOOR` applies; fast applies it centrally so a "looks-trivial" auth-gate drop or unguarded write cannot slip onto the trivial fast path. Three outcomes (after the floor):
   - effective `trivial` or `standard` → mark row eligible for fast chain.
   - effective `heavy` → mark row heavy; defer to tier gate (4c).

If any audit dispatch itself halts (V1 source ambiguous, file missing, contradictory signals), log the halt and mark the row `audit-halted`. Continue auditing the rest.

Output of 4b: per-feature audit files at `ai/migration/audits/<feature-id>.md` + an in-memory tier classification table.

### 4c. TIER TRIAGE (heavy rows are skipped, not blocking)

After all audits complete, route each row to the right per-row command — fast does NOT skip any tier, it routes every row to the ceremony its audit prescribes:

| Tier | Routed dispatch | Ceremony depth |
|---|---|---|
| `trivial` | `/find-and-fix <id>` | Audit + code edit + ledger note (~5 min/row). |
| `standard` | `/find-and-fix <id>` | Audit + 3-section contract + short plan + ≥10-fixture parity test + code edit + ledger row (~30 min/row). |
| `heavy` | `/port-feature <id> --heavy --unattended` | Full 7-phase ceremony — V1 contract extraction (9 sections) + V2 plan + ≥30-fixture parity tests + perf-decisions + rollback runbook + parity-auditor Stage A + ledger row (~2-4 hr/row). |
| `audit-halted` (parity-auditor itself failed on V1 ambiguity) | Halt note → `halts/`, advance to next row | The ledger row stays at its prior state until the user resolves the V1-source ambiguity. |

**Every row gets ported, deeply, following V2 structure.** The fast in fast-mode is parallel dispatch + automatic routing, not "skip the hard rows". Heavy ceremony happens inside fast — the user does NOT have to run `/port-feature --heavy` afterward.

**Why heavy stays in fast** (vs. the prior skip-to-halts design): the user's intent in invoking `/migration-fast` is to migrate the phase. A phase has heavy rows precisely because those features have hidden invariants / cross-tab dependencies / contract risk — they NEED the deep ceremony. Skipping them defeats the goal. Fast just spawns those ports in parallel with the lighter ones; the wall-clock is gated by the slowest heavy row, not by serial dispatch + manual reach for `/port-feature --heavy`.

### 4d. PARALLEL CHAIN (per-row dispatch in dependency waves)

Build the dependency graph from `ai/migration/ledger.md`'s `depends_on` field. Topologically sort into waves — Wave 1 = rows with no unresolved deps; Wave 2 = rows whose deps are all done after Wave 1; etc. Within each wave, dispatch all rows IN PARALLEL up to `--max-parallel` (default 4). When the wave completes, advance to the next.

**Per-row dispatch by tier** (the route from § 4c):

- `trivial` / `standard` → `Agent({subagent_type: <executor>, prompt: "/find-and-fix <id>"})`. The simple loop per `find-and-fix.md`. RE-DETECT step (`gaps_in == gaps_closed`) is mandatory; pre-advance verifier dispatches `parity-auditor` in verify-only mode before the ledger row flips to `done`.

- `heavy` → `Agent({subagent_type: <executor>, prompt: "/port-feature <id> --heavy --unattended"})`. The full 7-phase ceremony per `port-feature.md`. `--unattended` means the per-decision halts only fire on ambiguities NOT covered by an accepted ADR; pre-approved ADRs auto-confirm.

**V2 structure is non-negotiable** — both dispatched commands have hard rules that V2 ports follow V2's NEW structure (gold-standard equivalents, shared wrappers, layer boundaries, naming conventions). Per `find-and-fix.md § INVENTORY — V2 first, V1 second` and `port-feature.md § Phase 3 (Retrieve)`, the per-row sub-agent reads V2's gold-standard files BEFORE diffing V1 and writes the V2 port mirroring V2's shape — never V1's. Fast mode does NOT relax this; the V2-structure discipline is what makes the migration "deep" rather than a copy-paste.

**Per-row halt handling**:

When a sub-agent halts (any of: P0, cross-repo, user-decision-needed, audit-ambiguous, verify-red, deferred-gap-no-destination, ADR-needed-but-none-accepted):
- The sub-agent writes a halt note to `ai/migration/halts/<feature>-<iso>.md` with the halt reason + remediation pointer.
- The fast orchestrator marks the row `halted` in the in-memory wave report.
- **Other parallel sub-agents in the same wave continue.** A halt in one row does NOT cancel siblings.
- After the wave completes, the orchestrator advances to the next wave. Rows whose `depends_on` includes a halted row are skipped (logged to halts/ as `dependency-blocked`). Rows whose deps are all `done` proceed.

**On per-row success**: the sub-agent commits the diff with a structured message recording `gaps_in` / `gaps_closed`. The orchestrator updates the ledger row to `done` (or `V2-shadow` for heavy ports per their state machine). Continue.

**What the parallel chain does NOT do** (carried over from `migration-phase.md § Chain mode`):
- Author NEW ADRs. ADR-needed halts surface to halts/ for user review.
- Auto-merge port PRs. Each port lands as a commit; merge to main is a human step.
- Advance Shadow → Canary → V2-only. Cutover stages are separate explicit `/port-feature <id> --advance` invocations.
- Modify V1.

### 4e. AUTO-GATE (`/migration-gate <N>`)

After the chain completes (success or aggregated halts), automatically invoke `/migration-gate <N>` (unless `--no-gate` was passed).

The gate runs `validate-migration-artifacts.sh --phase=<N> --strict` and applies the tier-scoped 14-check matrix (per `migration-gate.md § Phase 2`). Two outcomes:

- **PASS** → gate writes the `_history.md` PASS line. Phase N exit-eligible.
- **REFUSED** → gate writes nothing; surfaces blocking issues. Phase N exit blocked.

Fast mode does NOT swallow gate refusals — they propagate to the end-of-run report verbatim.

## Phase 5 — Update (persist changes to the knowledge base)

**Direct writes by this command** (the orchestrator):
- `ai/migration/audits/phase-<N>-fast-report.md` — end-of-run summary (this command's own artifact).
- `ai/dynamic/changelog.md` — append entry: "Phase `<N>` fast-run: `<ok>` ported, `<halt>` halted, gate `<verdict>`".

**Indirect writes via dispatched sub-agents** — these match the manual flow's writes exactly because fast dispatches the same commands:
- `ai/migration/audits/<feature-id>.md` — one per row (via `parity-auditor` agent).
- `ai/migration/contracts/<feature>.md` — for standard tier (3 sections via `/find-and-fix`) and heavy tier (9 sections via `/port-feature --heavy`).
- `ai/migration/plans/<feature>.md` — short via `/find-and-fix` (standard); full via `/port-feature --heavy`.
- `ai/migration/mapping/<feature>.md` — V1-X→V2-Y inventory (every tier).
- `ai/migration/api-samples/<feature>/` — captured responses (when port touches service layer; every tier).
- `<parity-test-root>/<feature>/` — parity tests (≥10 fixtures standard, ≥30 heavy).
- `ai/migration/perf-decisions/<feature>.md` — heavy tier (via `/port-feature --heavy`).
- `ai/runbooks/migration-rollback-<feature>.md` — heavy tier (via `/port-feature --heavy`).
- `ai/migration/ledger.md` — per-row state updates (status, gaps_in, gaps_closed, ported_at, audit_provenance) via managed-block.
- `ai/migration/halts/<feature-id>-<iso>.md` — one per halted row (logged by the sub-agent that halted).
- `ai/migration/_history.md` — one PASS line **only on gate PASS** (written by the auto-invoked `/migration-gate`).

**ADRs**: ADR-needed decisions halt the affected row. The user resolves by drafting an ADR (`/draft-phase-adrs <N>` or hand-written) and re-running `/migration-fast <N>`. Fast does NOT auto-author ADRs — those are user decisions.

## Phase 6 — Validate (verify correctness)

Validation happens in two places:

1. **Per row**, via `/find-and-fix`'s internal RE-DETECT step (mandatory mechanical gate — `gaps_in == gaps_closed` enforced before the row flips to `done`).
2. **Per phase**, via the auto-gate at 4e — validator script + tier-scoped 14-check matrix.

If either fails, the relevant row(s) stay BLOCKED. The end-of-run report cites the specific failures.

## Phase 7 — Improve (feed the learning loop)

After the run completes:

- If >50% of rows halted → flag the phase as "fast-mode mismatch"; propose using the manual flow next time. Annotate `ai/migration/plan.md § Phase <N>` with a note.
- If a recurring halt reason surfaces across rows (e.g., "missing API sample for service-touching feature") → propose adding a pre-flight check that rejects the run before audit-all.
- If gate refused for a tier-classification reason (audit set tier wrong) → log to `ai/failures/` for parity-auditor refinement.

## Output to user

Single end-of-run report written to `ai/migration/audits/phase-<N>-fast-report.md` AND surfaced verbatim to the user:

```
/migration-fast <N> complete:

Phase <N> features:        <Y>
  Skipped (already done):  <skip>
  Audited (cached + new):  <X>     (cached: <c> reused, new: <n> dispatched)
    trivial:               <a>     → /find-and-fix
    standard:              <b>     → /find-and-fix
    heavy:                 <c>     → /port-feature --heavy --unattended
    audit-halted:          <d>     → halts/<feature>-<iso>.md (V1 ambiguity)

Parallel chain:
  Wave 1 (<w1> rows):      <ok>/<total> ported in <duration>
  Wave 2 (<w2> rows):      <ok>/<total> ported in <duration>
  ...
  Total ported:            <ok>    → ledger status=done; audits/<feature>.md
  Halted (per-row):        <halt>  → halts/<feature>-<iso>.md
  Dependency-blocked:      <dep>   → halts/<feature>-<iso>.md (skipped because dep halted)
  Failed verifier:         <fail>  → ledger status=failed; audits/<feature>.md

Auto-gate (/migration-gate <N>):
  Verdict: PASS | REFUSED
  (REFUSED only) Blocking issues: <count> across <features>
                  See ai/migration/audits/phase-<N>-fast-report.md § Gate findings

Total wall-time: <duration>           (max-parallel: <N>)

Not validated: <suites/environments skipped across the phase | none — full suite ran>
Risks:         <residual risk worth a human glance | none identified>
Revert:        git revert <first-sha>..<last-sha>   (or per-row: git revert <sha>)

Next steps:
  PASS:    /migration-fast <N+1>     (continue to next phase)
  REFUSED: review halts/ + audits/; fix blockers; re-run /migration-fast <N>
```

**Honesty clause (mandatory).** The phase report ends with `Not validated:` / `Risks:` / `Revert:` before `Next steps:`. `Total ported: N` + a PASS gate is insufficient — name the validation that did NOT run (suites skipped, environments unavailable, manual checks recommended) or state `none — full suite ran`; name residual risk or `none identified`; give the exact git revert range for the phase's commits. Omitting the negative space is the Trusted-Summary failure mode. Sibling commands (`/migrate`, `/find-and-fix`, `/port-feature`) mandate the same clause.

## Halt conditions (whole-run halt)

The fast run halts the WHOLE phase (refuses to proceed) only on real blockers — fast mode is biased toward starting and aggregating issues at end-of-run, not refusing pre-flight:

1. **Hard pre-flight failure** — missing `ai/migration/ledger.md`, missing `ai/migration/plan.md`, or invalid phase number. (Dirty working tree is NOT a blocker — fast warns and proceeds. Pass `--strict-clean` to upgrade.)
2. **Catastrophic dispatch failure** — `parity-auditor` itself fails repeatedly (3 retries) on multiple rows. Likely a config issue (V1 commit pin invalid, V2 root misconfigured); halt with diagnostics so the user fixes the config.

Per-row halts (P0, cross-repo, user-decision, ADR-needed, verify-red, dependency-blocked) do NOT halt the whole phase; they're aggregated to `ai/migration/halts/` and surfaced at end-of-run. The parallel chain ports everything that can ship now; the user reviews halts after the run completes and re-runs `/migration-fast <N>` to drain them.

## Idempotency

Re-running `/migration-fast <N>` is safe:
- Already-`done` rows are skipped (no re-audit, no re-port).
- Already-`failed` rows are re-audited and re-attempted (the prior failure may have been transient).
- Already-`halted` rows are re-attempted; if the halt cause was resolved (gap closed by hand, ADR landed), the row advances.
- Audit files are overwritten (the latest run is authoritative); the prior `auditor_agent_id` is replaced.
- Ledger updates use managed-block markers per `templates/idempotency.md`.

A re-run after fixing a few halts is the expected workflow — fix the blockers, re-run the same command, watch the halt count drop.

## Hard rules

- **Port every row.** Fast mode ports all tiers — trivial, standard, AND heavy. Heavy rows route to `/port-feature --heavy --unattended` automatically; the user does NOT have to invoke heavy ceremony separately.
- **V2 structure is non-negotiable.** Every ported row uses V2's gold-standard equivalents, shared wrappers, layer boundaries, and naming conventions. The Transposition Trap (V1 lift-and-shift into V2 paths) is the #1 anti-pattern fast must defend against — both `/find-and-fix` and `/port-feature --heavy` enforce this via their INVENTORY / Phase-3 reads. Fast does NOT relax this.
- **Audit before port.** Every row gets a `parity-auditor` dispatch with `auditor_agent_id` provenance (cached if pinned to current V1 HEAD; pass `--re-audit` to force re-dispatch).
- **Parity is non-negotiable.** Every ported row gets a passing parity test before `done`. Trivial uses the audit + ledger note as the risk register; standard produces a ≥10-fixture test; heavy produces a ≥30-fixture test + tolerance.yaml + golden snapshots.
- **RE-DETECT is mandatory.** `gaps_in == gaps_closed` is enforced before any row flips to `done`. Sub-agents that bypass this halt-the-row.
- **Parallel dispatch within waves.** Independent rows in the same dependency level run in parallel. Sub-agents do their own V1+V2 reads with their own 5K context blob — no shared mutable state between parallel rows.
- **No silent ADR drafts.** ADR-needed decisions halt the affected row (logged to halts/). The user drafts ADRs and re-runs.
- **No V1 modifications.** Per `migration-discipline.md`. V1 is the parity oracle.
- **No phase advance on REFUSED gate.** The auto-gate's verdict is binding; a REFUSED phase does not get marked complete in `_history.md`.
- **Idempotent.** Re-runs are safe and expected — already-`done` rows are skipped, halted rows are re-attempted with fresh dispatches.

## Comparison: fast mode vs manual flow

| Concern | Fast (`/migration-fast <N>`) | Manual (`/migration-phase --audit-only` + `/draft-phase-adrs` + `/migration-phase --chain` + `/migration-gate`) |
|---|---|---|
| Tiers handled | All — trivial, standard, heavy (auto-routed) | All — manual chooses the right per-row dispatch |
| Heavy-tier rows | Routed to `/port-feature --heavy --unattended` automatically inside the same run | Routed via `--chain --heavy` after manual ADR review |
| Dispatch shape | Parallel — multiple sub-agents per dependency wave (capped at `--max-parallel`) | Sequential — one row at a time |
| User checkpoints | One (end of run) | Three (after audit, after ADRs accepted, after chain) |
| ADR drafting | Halts on ADR-needed; user resolves and re-runs | Built-in `/draft-phase-adrs` step batches ADR drafts |
| Dirty working tree | Warn + proceed by default; `--strict-clean` halts | Each manual step has its own pre-flight (commit-or-stash advisory) |
| Output artifacts | Same as manual (audits, contracts, plans, parity tests, perf-decisions, runbooks, ledger, halts, gate) + a fast-run summary | Same set of artifacts, produced step-by-step |
| Wall time on a 10-row phase | ~30-60 min (parallel waves) | ~4-8 hours (sequential + interactive) |
| Discipline | Same as manual — every gate is mechanical, every check still runs, every artifact still produced | Same |
| Best for | Production migrations with many rows + many phases — when you can't afford serial wall-time | Foundational phases; phases where you want to inspect audits before any port |

## Related

- `/migration-scan` — produces the ledger this command reads.
- `/migration-plan` — produces the phased plan this command executes.
- `/migration-phase <N>` — the manual-flow alternative with `--audit-only` / `--chain` flags.
- `/draft-phase-adrs <N>` — used in the manual flow when ADRs are expected.
- `/migration-gate <N>` — auto-invoked by this command at end-of-run.
- `/find-and-fix <feature>` — the per-row dispatcher fast uses for trivial/standard rows.
- `/port-feature <feature> --heavy` — the per-row dispatcher fast uses for heavy rows (with `--unattended`).
- `/migration-park <feature>` — set a stuck row aside between fast runs.
- `/migration-status` — read the ledger between runs to see what's left.
- `ai/patterns/feature-port.md` — per-feature playbook this command applies via `/find-and-fix`.
- `.claude/rules/migration-discipline.md` — parity-non-negotiable contract.
