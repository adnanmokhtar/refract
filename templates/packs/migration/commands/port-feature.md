---
description: Per-feature V1→V2 port orchestrator. Drives one ledger row through all six phases — Understand V1 → Plan V2 → Port → Parity-test → Perf uplift → Cutover. Halts on every gate that fails the migration discipline rule. Cross-stack (backend / frontend / API).
---

# /port-feature

**For routine ports use `/find-and-fix <feature>` instead.** That command runs the simple detect → decide → fix → verify → record loop with single-agent dispatch and a 5K context blob — the right tool for trivial-tier rows (which is most rows). `/port-feature` defaults to a wrapper around `/find-and-fix` for that reason; the heavy 6-phase ceremony only runs when you pass `--heavy`.

`/port-feature --heavy` is reserved for: P0 findings, cross-repo blockers, contract breaks, security/privacy/legal regressions, write-path data-mutation, storefront blast radius. Reach for it deliberately, not by default.

The full-ceremony command takes a feature name (matching a row in `ai/migration/ledger.md`) and orchestrates the per-feature port — reading V1 deeply, planning V2, writing V2 against parity tests, applying parity-preserving perf wins, and gating cutover. Idempotent: re-invoking on the same feature resumes where the ledger says it is.

`--heavy` mode implements `feature-port.md`'s six-phase lifecycle. It dispatches `migration-architect` and `parity-auditor`. It uses skills `extract-v1-contract`, `parity-test-generate`, and `perf-uplift-survey`. It enforces `migration-discipline.md` at every gate.

## Default mode (`--simple`, implicit)

Without `--heavy`, this command **delegates to `/find-and-fix <feature>`**. Same arguments, same halts. The 6-phase machinery below does NOT run. Read `find-and-fix.md` for the loop semantics.

## Phases applied (`--heavy` ONLY)

The remainder of this document describes `--heavy` mode. Without `--heavy`, control passes to `/find-and-fix` and these phases do NOT execute.

All 7 of the standard pipeline (Understand → Organize → Retrieve → Generate → Update → Validate → Improve), refined for migration:

| Standard phase | Migration interpretation |
|---|---|
| 1. Understand | Read V1 deeply (`extract-v1-contract`); confirm dependencies |
| 2. Organize | Plan V2 (`migration-architect`); slice if needed |
| 3. Retrieve | Read V2's primitives + similar already-ported features for shape |
| 4. Generate | Write V2 code + parity tests + perf-decisions; in PARALLEL where independent |
| 5. Update | Update ledger row; revise contract if extraction surfaced new behaviours |
| 6. Validate | Run parity tests; run `parity-auditor`; rehearse rollback |
| 7. Improve | Apply perf uplifts (parity-preserving only); re-validate |

## Invariants

- **Zero copy-paste from V1.** V2 is re-derived from the contract, not transposed.
- **No V1 modifications.** V1 is the parity oracle — touching V1 invalidates the oracle.
- **One feature per invocation.** If the user asks to port "the user module" — break into per-feature invocations (one per ledger row).
- **Parity tests before V2 code OR alongside, never after.**
- **Every perf decision recorded** as applied / deferred / rejected with rationale + measurement.
- **Ledger updated in the same PR** as the port.
- **Cutover gated** by `parity-auditor` PASS at every state advance.

## Flags

- `--simple` (default) — delegate to `/find-and-fix <feature>`. Use this for routine ports.
- `--heavy` — opt into the full 6-phase ceremony below. Required when audit flags P0 / cross-repo / contract-break / security-sensitive / write-path mutation. Without `--heavy`, none of Phases 1-7 run; the command shells out to `/find-and-fix`.
- `--no-prompt` — `--heavy` only. Auto-confirm contract review summary in Phase 1 step 5. Does NOT skip decision halts.
- `--resume` — resume at the appropriate phase based on ledger row state (default behaviour; flag is explicit-form).
- `--advance` — used post-merge to advance Shadow→Canary→V2-only (Phase 6 stage advance).
- `--depend-on-v1` — proceed even if a dependency is still V1-only. Requires written rationale logged to the ledger row's notes.
- `--overwrite-v2` — force re-port when `migration-detect-existing.sh` returns `full`. Logged to `ai/migration/_history.md`.
- `--merge-existing` — proceed when detection returns `partial` (V2 has scaffolding); merge with what's there instead of overwriting.
- `--override-paths` — bypass `migration-validate-paths.sh` when the architect can defend the deviation in writing (logged).
- `--unattended` — run without per-decision prompts; skip halts ONLY for decisions covered by an accepted ADR (`Status: accepted` in `ai/decisions/`). See "Unattended mode" below.

## Unattended mode (`--unattended`)

When invoked with `--unattended`, the command treats every decision-halt as gated by an ADR. The flag is intended for sequential execution under `/migration-phase <N> --chain` after `/draft-phase-adrs <N>` produced ADRs the user accepted.

**Rules**:
1. **Pre-flight gate** — before Phase 1, scan `ai/decisions/_phase-<N>-decisions.md` (where N = the feature's phase per the ledger). For every per-feature ADR linked to this feature: confirm `Status: accepted` in the ADR file. If ANY linked ADR is `Status: proposed` (or missing), HALT with: "ADR-NNN not accepted; review and flip Status before --unattended". Do not silently proceed.
2. **Auto-confirm Phase 1 contract review** (equivalent to `--no-prompt`).
3. **Auto-confirm Phase 2 plan review** if the plan's decisions all map to accepted ADRs. If the architect proposes slicing, HALT — slicing decisions are not auto-confirmable.
4. **Phase 5 contract revision**: if a parity-test red surfaces a contract gap NOT covered by an accepted ADR, HALT. The unattended mode does not author NEW intentional breaks — only consumes pre-approved ones.
5. **Phase 6 audit** still runs the `parity-auditor` agent; halt rules are unchanged. The agent's verdict is not gated by `--unattended`.
6. **All halts log to** `ai/migration/halts/<feature>-<iso>.md` with halt reason, current state, and resume instruction. The user (returning to the chain) reads the halts file to know what blocked.
7. **Cutover stage advance** (Shadow→Canary→V2-only) is NEVER auto-advanced by `--unattended`. Each stage is a separate explicit `/port-feature <id> --advance` invocation per `migration-discipline.md`'s rule "Cutover gated by `parity-auditor` PASS at every state advance".
8. **Contract section 9** entries reference the ADR by ID (`See ADR-NNN`); the ADR is the source of truth for the rationale. Don't restate the rationale in the contract.

**What `--unattended` does NOT skip**:
- New ambiguities surfaced during V1 read that no ADR covers (HALT).
- Path violations (`migration-validate-paths.sh` fail → HALT).
- V2 existence detection returning `full` without `--overwrite-v2` (HALT).
- Parity-auditor verdict (HALT independently per its own rules).
- Cutover stage advance (always explicit).

**Output of an unattended halt**:
```
HALT (--unattended) at Phase <N>: <reason>
  → ai/migration/halts/<feature>-<iso>.md
  → Resume: /port-feature <feature> --resume   (after fixing)
```

The chain runner (`/migration-phase <N> --chain`) inspects this halt file and decides whether to continue with the next feature or stop the chain.

## When to use / NOT to use

- USE: a feature in `ai/migration/ledger.md` is in state `V1-only` and ready to port.
- USE: a feature in `In-progress` whose work resumes (e.g., contract was revised; this command re-runs from the right phase).
- USE: a feature in `V2-shadow` advancing to `V2-canary` (this command runs the audit + advance steps).
- NOT: a brand-new V2 feature with no V1 counterpart → use `/add-feature`. There is no parity to maintain.
- NOT: a small in-version refactor that preserves behaviour → use `code-quality/refactorer`.
- NOT: strategic-level migration planning ("should we strangle vs big-bang?") → use `code-quality/legacy-modernizer`.
- NOT: a DB-only schema migration → use `database/add-migration` + `migration-rehearsal`.

## Pre-flight checks (halt if any fail)

1. `_extracted-codebase.md § Migration` exists and identifies V1 root, V2 root, ledger path. If absent, halt: "run `/setup-project --refresh` first; the migration pack needs extraction."
2. `ai/migration/ledger.md` exists and contains a row for the requested feature. If absent: "feature not in ledger; add it first OR run `/setup-project` to bootstrap the ledger from V1's feature inventory."
3. The feature's dependencies (per ledger) are all `V2-only` — OR an explicit override `--depend-on-v1` is supplied with rationale.
4. V1 branch is at HEAD of a clean working tree. Pin commit before extracting.
5. `ai/architecture.md` (V2's architecture) exists and is the version pinned for the migration window. If V2's architecture is in flux, halt.

**Hard contract (M31) — V2 existence detection (refuses to overwrite):**

```bash
~/.claude/scripts/migration-detect-existing.sh "$V2_ROOT" "$FEATURE_SLUG"
```

Phase 1 MUST run this BEFORE any read of the contract or any planning work. The ledger is not authoritative — the V2 filesystem is. Three outcomes:

- `none` → V2 has no detectable evidence; proceed.
- `partial` → V2 has some files / references; HALT. Print the report at `<v2>/.claude/_migration-detect-<feature>.md`. Surface to user. User decides: continue developing what's there (do NOT port), merge with `--merge-existing`, or rare re-port with `--overwrite-v2`.
- `full` → V2 already implements the feature; HALT and refuse. Update the ledger row first (the ledger drifted), then if user really wants to re-port, force with `--overwrite-v2` (logged to `_history.md`).

**Hard contract (M31) — path conformance (refuses paths that violate V2 structure):**

```bash
~/.claude/scripts/migration-validate-paths.sh "$V2_ROOT" "$FEATURE_SLUG" - <<'PATHS'
src/modules/<feature>/pages/<Feature>Page.vue
src/modules/<feature>/services/index.ts
... every file the architect plans to write ...
PATHS
```

Phase 4 MUST run this on the FULL list of planned files BEFORE writing any of them. Validates against the project's detected stack + module shape + naming conventions (read from `codebase-profile.md`):

- Top-level dir whitelist (no writes outside `src/`, `tests/`, `public/`, `docs/`, `ai/`, `.claude/`).
- Module shape: `src/modules/<feature>/<kind>/...` where `<kind>` is one of the kinds detected in existing modules (`pages, components, composables, services, types, locales` for the typical Vue project).
- Filename conventions: PascalCase + recognized suffix for `.vue`; camelCase for `.ts`; framework-stack matched (no `.tsx` in a Vue project).
- Forbidden zones: `node_modules/`, `dist/`, `.git/`, build outputs.

If ANY path fails, the script exits 1 with the violation list. Phase 4 MUST refuse to write until all paths pass. Override with `--override-paths` (logged) only when the architect can defend the deviation in writing.

## Phase 1 — Understand (the ask + V1 deeply)

1. **Resolve the feature**: parse user's request. Match to a ledger row by name (e.g., `report-orders`) or fuzzy-search if name is approximate. Confirm with user.
2. **Read the ledger row**. Note current state. Decide where in the lifecycle to enter:
   - `V1-only` → start at Phase 1 (extract contract).
   - `In-progress` → resume at the point the contract / plan / V2 code is incomplete.
   - `V2-shadow` (advancing) → skip to Phase 6 audit + Stage B.
   - `V2-canary` (advancing) → skip to Phase 6 audit + Stage C.
   - `V2-only` (advancing to V1-deleted) → skip to Phase 6 audit + Stage D.
3. **Pin V1 commit**: `git -C <v1-root> rev-parse HEAD`. Update ledger row's `v1_commit_pinned`.
4. **Run `extract-v1-contract`** (skill). Output: `ai/migration/contracts/<feature>.md`. The contract is the spec V2 must satisfy.
5. **Review the contract**: present a summary to the user — Inputs / Outputs / Side effects / Business rules / Invariants / Known V1 bugs. Pause for user confirmation OR auto-confirm if `--no-prompt`.

Halt conditions: contract is incomplete; user flags a missing case.

## Phase 2 — Organize (plan V2)

1. **Dispatch `migration-architect`**. Inputs: contract + V2's architecture + ledger + `_extracted-codebase.md`. Output: `ai/migration/plans/<feature>.md`.
2. **Review the plan**: present V2 module shape, parity strategy, perf candidates (with applied/deferred/rejected pre-classification), cutover plan, rollback path, non-goals.
3. **Resolve ambiguities**: if architect halted on missing dependencies / ambiguous contract / V2 architecture flux — surface and pause.
4. **Slice if needed**: if architect proposed splitting, present the split; user confirms before splitting the ledger row into N rows.

Halt conditions: plan halted; user rejects the slice.

## Phase 3 — Retrieve (V2's primitives + gold-standard features)

**Hard rule (anti-Transposition-Trap)**: a V1→V2 port is NOT a copy-paste of V1. The new V2 code MUST follow V2's NEW structure — its shared components, its conventions, its file layout. Skipping this step IS the Transposition Trap (per `migration-discipline.md` § Anti-patterns) and produces ports that look like V1 with new file paths. The V1-pattern fingerprints the validator catches (see `validate-migration-artifacts.sh § check_v2_structure`) all originate here, in a Phase-3 read step that was skipped.

1. **Read V2's primitives**: DI container / error envelope / logging facade / repository pattern / concurrency primitive / cache primitive / validation library — from `_extracted-idioms.md`. The V2 implementation MUST use these.

2. **Read the GOLD STANDARD for this feature shape** (project-anchored — extract from `_extracted-codebase.md § Gold standards`). For frontend ports, this is typically:
   - **CRUD list page** → read the project's gold-standard list page (e.g., `inventory/CategoriesPage.vue` for Vue 3 / vue-architect projects).
   - **Detail/show page** → read the gold-standard detail page (e.g., `orders/OrderDetailsPage.vue`).
   - **Dialog / form** → read at least 2 V2 dialogs that use the same shared components (`<BaseModal>`, `<BaseForm>`, `<FormField>` with `col-class` prop, `<TranslatedInput>`, `<BaseDropdown>`, `<PhoneInput>`, `<StatusSwitch>`).
   - **Composable** → read the V2 equivalent (e.g., `useCrud`, `useForm`, `useGeoCascade`).
   - **Service** → read 1 service in the same module + `BaseCrudService`.

   The new V2 code MUST mirror these files' shape: same component-composition pattern, same prop naming (e.g., `label="Module.key"` as bare string for `<FormField>`, NOT `:label="$t('Module.key')"` — `<FormField>` calls `$t()` internally), same `col-class` prop usage on `<FormField>` (no wrapper `<div class="col-*">` around it), same shared-component wrappers (no raw `<Dialog>`, `<Paginator>`, `<Dropdown>` in pages — use the `Base*` / `Crud*` wrappers).

3. **Read 1–2 already-ported features** in `<v2-root>/` for the same axis (read-only CRUD vs detail vs settings). Note their conventions explicitly before writing — e.g., "OrderDetailsPage uses `onActivated` for KeepAlive caching; my port must too."

4. **Read parity test infra**: `tests/parity/_helpers/run-parity.ts` (or equivalent). If absent, generate it (one-time, via `parity-test-generate`'s "create helper" branch).

5. **Read `migration-discipline.md` § Anti-patterns "The Transposition Trap"** before writing a single line of V2 code. If you find yourself copy-pasting V1's grid layout (`<div class="row"><div class="col-md-6">`) or V1's component composition (raw `<Dialog>` + raw `<form>`), STOP — re-read the gold standard.

**Output of this phase**: a 3-5 line note in `ai/migration/plans/<feature>.md § "V2 patterns I will follow"` listing the gold-standard files read + the specific patterns being mirrored. The plan reviewer (human OR `migration-architect` agent) checks this before the port writes a single line.

## Phase 4 — Generate (V2 code + parity tests + perf-decisions)

**Tier-aware execution** (per ledger row's `tier:` field, set by audit per `migration-discipline.md` § "Required artifacts per feature — tiered floor"):

### Trivial tier
Run **4a only**. Skip 4b/4c/4d entirely. The audit + ledger note carry the risk register. Standard CI tests (the project's existing test suite) must pass.

### Standard tier
Run **4a + 4b**. Skip 4c (no separate perf-decisions doc; classify perf candidates inline in the plan) + 4d (no separate runbook; rollback path is one paragraph in the plan). Parity-test corpus floor: 10 fixtures (not 30).

### Heavy tier
Run **4a + 4b + 4c + 4d** as below. This is the historical full discipline.

### Code-first execution (all tiers)

**Run 4a FIRST, sequentially, before any 4b/c/d dispatch.** The audit lists specific gap closures by `<v1-path:line>` ↔ `<v2-path:line>`. The port applies those edits, runs the project's typecheck + lint, then advances. If 4a's edits introduce any test red, halt and surface — do not proceed to 4b/c/d on a broken V2.

**4a default closure verb is V1-parity, NOT ADR** (per `migration-discipline.md` § "Default to V1-parity, ADR is opt-in"). When the audit flags a V2-deviates-from-V1 gap (extra button, renamed route, flipped default, new field, removed feature), 4a's edit is the **code change that removes V2's deviation to match V1** — NOT a doc that legitimizes V2. The F020 anti-pattern (ADR-019 drafted to keep V2's per-row delete button that V1 didn't have) MUST NOT recur: if the plan ships with an ADR-as-closure for a parity gap, 4a halts and surfaces — the user must explicitly accept the ADR before 4a proceeds, otherwise the plan must be revised to remove-V2-deviation as the closure verb.

This inversion (vs. the old "all 4 in parallel") is deliberate:
- Code edits are the actual deliverable. They must succeed before ceremony around them is generated.
- Many gaps are 1-line fixes — generating ceremony before knowing if the fix even compiles is waste.
- A failing 4a sometimes means the audit's gap list was wrong; finding that out before 4b spends 50K tokens on parity-test fixtures is cheap.
- ADR drafts are not closures for parity gaps — they're records of user-accepted divergences. Code change is the closure.

### Shared-context dispatch (heavy + standard tiers only — for 4b/c/d)

When 4b/c/d run, they all need the same context: contract + plan + V1 commit pin + audit + V2 patterns. **DO NOT dispatch each as an independent sub-agent that re-reads everything.** Instead:

1. Build a **single context blob** at the top of Phase 4: contract excerpt (load-bearing sections only — Inputs § 1, Outputs § 2, Known V1 bugs § 9), plan excerpt (V2 file scope, gap closures), audit excerpt (gaps + ADR cites), V1 commit pin. Cap at 8K tokens.
2. Pass this blob as the **only** context to 4b/c/d sub-agents (not the full files).
3. Sub-agents receive: (a) the blob, (b) a sentence describing their specific output, (c) the path to write to.
4. Sub-agents do NOT re-read `migration-discipline.md`, the full contract, the full plan, the audit doc, or sibling perf-decisions/runbook docs. The blob is the contract.

This cuts each dispatch from ~40-90K input tokens to ~10-15K. For a 4-agent Phase 4, that's 100-300K tokens saved per port.

### Heavy-tier output map (when all 4 run)

| Sub-step | Output |
|---|---|
| 4a. **Write V2 code** (re-derive from contract; use V2 primitives; run BEFORE 4b/c/d) | `<v2-root>/<feature>/{controller,service,repository,dto,errors}.<ext>` |
| 4b. **Run `parity-test-generate`** | `tests/parity/<feature>/` (corpus + golden + tolerance + tests) |
| 4c. **Pre-fill `perf-decisions`** | `ai/migration/perf-decisions/<feature>.md` (planned form, measurements TBD) |
| 4d. **Write rollback runbook** | `ai/runbooks/migration-rollback-<feature>.md` |

Coordination: 4a runs first. After 4a is green, 4b + 4c + 4d run in parallel using the shared context blob (heavy + standard tiers).

After parallel completes, sequentially:

| Sub-step | Output |
|---|---|
| 4e. **Wire DI / routing** | V2 module registered |
| 4f. **Write V2 unit tests** | V2 internal tests (separate from parity tests) |

## Phase 5 — Update (ledger + contract revisions)

1. **Run parity tests**: against the pinned V1 commit. Capture run report.
2. **Iterate on parity reds**: each red is either a V2 bug (fix V2) OR a contract gap (revise contract; re-pin V1 if drifted; never edit tolerance to make the test pass).
3. **Apply perf uplifts** (planned in Phase 4c, applied in Phase 5):
   - For each `applied` candidate from `perf-uplift-survey`: implement; measure before/after; verify parity still green; update `perf-decisions/<feature>.md` with the actual measurement.
   - For each `deferred`: log reason in perf-decisions.
   - For each `rejected`: log reason + ADR link if contract-breaking.
   - **The user's specific concerns are first-class candidates**:
     - **Caching**: per-request memo / cross-request Redis / framework cache adapter — chosen per call site with hit-rate × staleness × invalidation cost.
     - **DB indexing**: V2 query plan rehearsed against prod-sized data; new composite indexes shipped with reversible migrations.
     - **Query optimisation**: N+1 → batch / JOIN; in-app filter → DB filter; subquery → CTE / lateral.
     - **Column projection**: SELECT * → minimal columns based on consumed-columns list in the contract.
   - These four DO NOT silently ship. Every applied row has a measurement. Every applied row preserves parity (verified by re-running parity tests).
4. **Update ledger row**: state → `V2-shadow` (or appropriate next state); fill required fields (parity_runs entry, perf_decisions path, plan path, contract path).

Halt conditions: parity tests can't be made green AND contract can't be revised (i.e., V1 has behaviour V2 fundamentally cannot replicate without a contract break) — escalate to migration owner for an ADR.

## Phase 6 — Validate (audit + cutover stage)

1. **Run `parity-auditor` Stage A** on the implementation by dispatching the agent: `Agent({subagent_type: "parity-auditor", prompt: <feature-context-and-axes>})`. Hard-halt on any fail. The agent's run ID MUST land in the audit doc's frontmatter as `auditor_agent_id: <run-id>`. The validator (`scripts/validate-migration-artifacts.sh § check_audit_provenance`) refuses any audit without a populated provenance field — this is the F039 / Phase-6 lesson made mechanical: prove the agent ran, don't echo prior summaries.
2. **If audit PASSES**: open the port PR. Reviewer (human) reviews. Merge to main.
3. **Cutover stage advance** (this command may be re-invoked at each stage):
   - `Shadow` start: deploy V2 in shadow mode; comparator reports begin streaming.
   - `Shadow → Canary 1%`: re-invoke `/port-feature <feature> --advance`. Runs `parity-auditor` Stage B. If PASS, advance.
   - Repeat for 1% → 10% → 50% → 100%. Each invocation runs Stage C and advances if PASS.
   - `100% sustained ≥ observation_window` → re-invoke with `--advance`. Stage C confirms; ledger transitions to `V2-only`.
   - `V2-only ≥ 14d zero traffic` → re-invoke with `--advance`. Stage D confirms; produces a V1-deletion PR (separate). Ledger transitions to `V1-deleted` after that PR merges.
4. **On halt at any stage**: ledger row → `Halted`; root-cause file at `ai/migration/halts/<feature>-<iso>.md`. The user resumes with `/port-feature <feature> --resume` after fixing the cause.

## Phase 7 — Improve (post-cutover)

After `V1-deleted`, queue follow-ups:

1. Any `deferred` perf candidate from perf-decisions — schedule into the next milestone.
2. Any contract-breaking improvement queued as ADR — execute now that V2 is sole owner of the feature (no parity oracle to preserve).
3. Update `_extracted-codebase.md § Migration § Feature inventory` to remove the feature (it's no longer "to migrate").
4. If this was the last feature in the inventory, ledger transitions to a special "complete" state; this command celebrates + suggests deleting the migration pack from the project (it's no longer useful).

## Output format

Each invocation produces:

```
Phase 1 (Understand):
  ✓ ledger row: <feature> [V1-only → In-progress]
  ✓ V1 commit pinned: <sha>
  ✓ contract: ai/migration/contracts/<feature>.md (12 inputs, 4 happy paths, 7 error paths, 9 business rules, 3 invariants, 2 known V1 bugs)

Phase 2 (Organize):
  ✓ plan: ai/migration/plans/<feature>.md
  ✓ slicing: this is one ledger row
  ✓ dependencies confirmed: getUser ✓, getOrders ✓

Phase 3 (Retrieve):
  ✓ V2 primitives identified: ORM=<x>, DI=<y>, error=<z>, concurrency=<w>
  ✓ similar feature template: <v2-root>/account/

Phase 4 (Generate, parallel):
  ✓ 4a V2 code: 5 files, 312 lines
  ✓ 4b parity tests: 47 inputs, 6 properties, tolerance.yaml
  ✓ 4c perf-decisions: 10 candidates surveyed
  ✓ 4d rollback runbook: ai/runbooks/migration-rollback-<feature>.md

Phase 5 (Update):
  ✓ parity tests: green (47/47)
  ✓ perf applied: 4 (n+1 fix, composite index, column projection, request-cache); deferred: 1 (Redis); rejected: 1 (sync→async email send)
  ✓ ledger updated: V1-only → In-progress → (ready for V2-shadow on merge)

Phase 6 (Validate):
  ✓ parity-auditor Stage A: PASS
  → next: open PR; reviewer signs off; merge → /port-feature <feature> --advance

Phase 7 (Improve): queued for post-V1-deletion
  - Redis caching for tax-rate (deferred candidate)
  - ADR-014: async email send (rejected candidate; revisit post-V1)
```

## Failure modes

- **No feature inventory** — `/setup-project` hasn't been run since the migration pack was loaded. Run `/setup-project --refresh`.
- **Dependency not ready** — feature depends on something still in V1; refuse to proceed; suggest porting the dependency first OR using `--depend-on-v1` with rationale.
- **Contract extraction yields ambiguities** — pause; ask user.
- **Parity tests can't be made green** — investigate. Likely: (a) V2 has a bug, (b) contract is incomplete (re-extract), (c) V1 has non-determinism (mock / strip), (d) a fundamental contract break is required (ADR).
- **Auditor halts** — produce remediation list; user fixes; re-invoke.
- **User asks to bundle features** — refuse; explain one ledger row per port; offer to split.
- **User asks to "port and add a new feature"** — refuse; explain the port stays parity-equivalent; the new feature ships separately on V2.

## Cross-stack notes

This command is stack-agnostic in shape. The specifics differ:

- **Backend (e.g., Django, NestJS, Rails, Spring)**: V1 = controllers/views; V2 = the new service-layer module. Parity at HTTP boundary.
- **Frontend (e.g., React, Vue, Angular)**: V1 = component / page; V2 = the new component / page (possibly different framework). Parity at DOM observable + a11y output + visual snapshot. Tolerance taxonomy includes `dom-equivalent` (semantically equal markup).
- **API**: V1 = endpoint at `/v1/...` (or unversioned); V2 = endpoint at `/v2/...`. Parity at request/response shape; cutover via API gateway routing rule.

For multi-stack features (e.g., "the orders flow" — frontend page + backend API + DB query), each stack ships as its own ledger row, with dependencies recorded — frontend depends on V2 API; V2 API depends on V2 DB layer.

## References

- `migration-discipline.md` — the rule.
- `feature-port.md` + `parity-testing.md` + `migration-ledger.md` — patterns.
- `extract-v1-contract.md` + `parity-test-generate.md` + `perf-uplift-survey.md` — skills.
- `migration-architect.md` + `parity-auditor.md` — agents.
- `migration-status.md` — sibling command for ledger reporting.
- `code-quality/legacy-modernizer.md` — strategic plan this command operates inside.
- `database/migration-rehearsal.md` — used for query plan rehearsal in Phase 5.
- `backend/concurrency-discipline.md` + `backend/parallelize-independent-ops.md` — used in Phase 5 perf uplift.

## Related

### Sibling commands in migration pack
- `/migration-deprecate` — sibling command in migration pack
- `/migration-final` — sibling command in migration pack
- `/migration-gate` — sibling command in migration pack
- `/migration-park` — sibling command in migration pack
- `/migration-phase` — sibling command in migration pack
- `/migration-plan` — sibling command in migration pack
- `/migration-replan` — sibling command in migration pack
- `/migration-rollback` — sibling command in migration pack
- `/migration-scan` — sibling command in migration pack
- `/migration-status` — sibling command in migration pack
- `/migration-unpark` — sibling command in migration pack

### Patterns
- `ai/patterns/feature-port.md`
- `ai/patterns/migration-ledger.md`
- `ai/patterns/parity-testing.md`

### Rules
- `.claude/rules/migration-discipline.md`
