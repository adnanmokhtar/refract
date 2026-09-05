---
description: "Executes one migration phase. For each feature in the phase: AUDIT (compare V1 vs V2) → identify GAPS → PORT (fill gaps using V2 structure) → VERIFY (parity test). Updates ledger as it progresses. Stops at phase boundary. Stack-agnostic."
kind: command
pack: migration
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /migration-phase <N>

## The Premise (read this first)

**Audit first, chain second. Never auto-advance unverified rows.** The audit step (§ 4b) is where V1↔V2 truth is established — by line-by-line read, by dispatched `parity-auditor` agent, by enumerated axes with real `<path:line>` cites. The chain step (§ 4c-4g) only runs after every audited row has explicit closure (parity-clean / accepted ADR / parked / deprecated). A row whose audit was a Trusted-Summary echo, or whose `gaps_in != gaps_closed`, or whose audit lacks `auditor_agent_id` provenance — does NOT advance. The pre-advance verifier is mandatory; partial fixes do not flip rows to `done`.

Runs phase N from `ai/migration/plan.md`. Per feature: audit, gap-find, port, verify, update ledger. Repeats until every feature in the phase is `done` + `parity_test=passing`.

## Pre-requisites

- `/migration-scan` produced a ledger.
- `/migration-plan` produced the phased plan.
- Argument N is a valid phase number from the plan.

## Phase 1 — Understand (the ask)

Inputs:
- `<N>` — phase number (required).
- `ai/migration/plan.md` — phase definition.
- `ai/migration/ledger.md` — feature status.

Optional flags:
- `--feature=<id>` — execute ONLY this feature within phase N (skip the rest). Useful for retry.
- `--audit-only` — run audit step but skip port + verify. Useful for triage. Pairs with `/draft-phase-adrs <N>` next.
- `--chain` (default per-feature delegate: `/find-and-fix`) — execute ports sequentially per phase row. Each row dispatches `/find-and-fix <id>` (the simple loop). Heavy-tier rows still halt and surface to the user.
- `--heavy` (compose with `--chain`) — escalate every chained row to `/port-feature <id> --heavy --unattended` after `/draft-phase-adrs <N>` produced ADRs the user accepted. Use only when the phase contains many heavy-trigger features.
- `--stop-on-halt` (chain only; default: on) — halt the chain on the first feature halt. With `--no-stop-on-halt`, the chain continues to the next feature and aggregates halts at end-of-phase.

## Workflow modes

| Mode | When | Behaviour |
|---|---|---|
| **Default** (no flag) | Single-feature retry, or you want fully-interactive port-by-port | Audit + port + verify per feature, with decision halts surfacing to user. Synonymous with running `/find-and-fix <id>` per row. |
| **`--audit-only`** | Phase entry — produce honest baseline before any port work | Per-feature audit only. No code changes. Ledger rows stay `unverified`. Output: per-feature audits + `phase-<N>.md` summary. **Always followed by** `/draft-phase-adrs <N>` only if the audit flagged P0/cross-repo/contract-break triggers; otherwise proceed straight to `--chain`. |
| **`--chain`** | After audit (and ADRs accepted, if any) | Sequential `/find-and-fix <id>` per row in dependency order. Trivial-tier closures land directly; halts surface for user-decision rows. Output: ports landed + per-feature halts (if any). |
| **`--chain --heavy`** | Phase contains many heavy-trigger features and ADRs accepted | Sequential `/port-feature <id> --heavy --unattended` per row. Used rarely. |

The intended flow:
```
/migration-phase 8 --audit-only       (you watch → audits + phase summary)
/draft-phase-adrs 8                   (you watch → drafts ADRs)
[user reviews + flips Status: proposed → accepted in each ADR]
/migration-phase 8 --chain            (walk away → unattended ports)
/migration-gate 8                     (you watch → phase exit verification)
```

Skipping `/draft-phase-adrs` is supported but pushes decisions back into per-port halts (one-by-one supervision instead of batch).

**Fast alternative**: `/migration-fast <N>` collapses the four steps above into a single invocation AND parallelises per-row dispatch — same audits, same chain, same gate, same artifacts, same V2-structure discipline. Auto-routes every row to the right per-row command (trivial/standard → `/find-and-fix`; heavy → `/port-feature --heavy --unattended`) and runs them in parallel waves respecting `depends_on`. Built for production-scale migrations where serial wall-time is the bottleneck. ADR-needed rows still halt per-row (logged to halts/) since fast can't decide on intentional V1↔V2 breaks for the user. See `migration-fast.md` for the full contract.

## Chain mode (`--chain`)

When invoked with `--chain`, this command sequentially dispatches `/find-and-fix <id>` per phase-N feature in **dependency order** (per ledger `depends_on`). With `--chain --heavy`, the per-row dispatch becomes `/port-feature <id> --heavy --unattended` instead.

**Pre-flight checks (chain-specific)** — halt before the first port if any:
1. `ai/decisions/_phase-<N>-decisions.md` exists (otherwise: "run `/draft-phase-adrs <N>` first").
2. Every ADR in the index doc has `Status: accepted` (otherwise: "ADR-NNN still proposed; review and flip Status before --chain").
3. Working tree is clean (otherwise: "uncommitted changes; commit or stash before --chain").
4. Phase-N audit summary exists at `ai/migration/audits/phase-<N>.md`.

**Per-feature loop**:
1. Sort phase-N features by `depends_on` (topological). Skip features with `status: parked` or `status: deprecated`.
2. For each feature in order:
   - **Read the audit's `tier:` field** (mandatory frontmatter per § 4d). The tier determines which 4-phase set runs inside `/port-feature` — trivial = 4a only; standard = 4a + 4b; heavy = 4a + 4b + 4c + 4d. See `port-feature.md` § Phase 4 — Tier-aware execution.
   - **Default dispatch is `/find-and-fix <id>`** (light path per `migration-discipline.md` § Anti-bloat rules). Only escalate to `/port-feature <id> --heavy --unattended` when the row's audit flags P0 / cross-repo / contract-break / security-sensitive / write-path mutation, OR `--chain --heavy` was passed explicitly.
   - On HALT (either command): write reason to `ai/migration/halts/<feature>-<iso>.md`. If `--stop-on-halt` (default), abort the chain. If `--no-stop-on-halt`, log and continue to next feature.
   - **Pre-advance gate (mandatory)**: before flipping the ledger row to `V2-shadow` (or `done` for trivial), re-dispatch `parity-auditor` in **verify-only mode** with the original gap list as input. Verdict must be `parity-clean` (every gap from the per-feature audit confirmed closed; `gaps_in == gaps_closed`; no regressions; no new gaps). If verdict is anything else, HALT — do NOT advance the ledger row, do NOT commit, do NOT continue to the next feature on `--stop-on-halt`. This catches partial fixes that `find-and-fix`'s internal re-DETECT (step 3.5) somehow let through, AND it catches `port-feature --heavy` runs whose internal audit was a Trusted-Summary echo.
   - On verified port success: commit the diff with a structured message that records `gaps_in` / `gaps_closed`; continue.
3. After last feature (or on chain abort): produce a chain report at `ai/migration/audits/phase-<N>-chain-report.md` listing per-feature outcome (success / halt / skipped) + halt files.
4. Auto-invoke `/migration-gate <N>`. If gate refuses, surface its findings; phase exit blocked.

**What `--chain` does NOT do**:
- Author NEW ADRs. New ambiguities halt; user resolves via `/draft-phase-adrs` or manual ADR before resuming.
- Auto-merge port PRs. Each port lands as a commit; merge to main is a human step.
- Advance Shadow→Canary. That's a separate `/port-feature <id> --advance` per stage.
- Modify V1. Per `migration-discipline.md`, V1 is the parity oracle.

**Output of chain run**:
```
/migration-phase <N> --chain complete:

Features in phase:        <Y>
  Skipped (parked/dep):    <skip>
  Successfully ported:     <ok>     → V2-shadow
  Halted (--unattended):   <halt>   → see halts/
  Failed parity:           <fail>   → see audits/

Chain report: ai/migration/audits/phase-<N>-chain-report.md
Halts (if any): ai/migration/halts/F0xx-*.md

Auto-invoked: /migration-gate <N>
Gate verdict: PASS | REFUSED (see output above)
```

## Phase 2 — Organize (decompose the work)

For each feature in phase N (in plan order):

```
For F in phase_N_features:
    1. AUDIT          → comparing V1[F] vs V2[F]
    2. GAP-FIND       → list missing/divergent behaviors
    3. PORT (if gaps) → implement using V2 structure
    4. VERIFY         → re-run audit; parity must pass
    5. UPDATE ledger  → status=done if verify-green
```

## Phase 3 — Retrieve (read the right context)

Per feature:
- V1 source files for this feature.
- V2 destination files (existing or planned).
- Relevant V2 patterns from `ai/patterns/`.
- Project conventions from `ai/conventions.md`.
- Foundation-phase outputs (auth helpers, tenant context, etc.) — required by every later phase.

## Phase 4 — Generate (produce the output)

**Composition (mechanism, not policy)**: this command MUST dispatch the `parity-auditor` agent for the audit step and MUST dispatch `migration-architect` (where available) for the port step. The audit step is NEVER run inline by the executor. Inline audit was the F039 + F030 + F032 trigger — a fast executor reading prior summary docs and echoing "parity-clean" without line-by-line V1 source review. This section converts that "should dispatch" policy into a binding mechanism.

For each feature in the phase, in plan order:

### 4a. PRE-FLIGHT (per feature)

Halt before invoking the audit step if any:
1. No ledger row exists for this feature.
2. Feature's dependencies (per ledger) are not `V2-only` OR `--depend-on-v1` override is undocumented.
3. `~/.claude/scripts/migration-detect-existing.sh "<v2-root>" "<feature-slug>"` returns `full` without `--overwrite-v2`.
4. V1 branch is not at HEAD of a clean working tree.

### 4b. AUDIT (mandatory agent dispatch — applies in BOTH normal AND `--audit-only` modes)

**The audit step MUST be performed by dispatching the `parity-auditor` agent. There is no inline-executor fallback for tools that have agent dispatch.**

Mechanism by tool family:

- **Claude Code / OpenCode (full agent + command + skill dispatch)**: invoke the `Agent` tool with `subagent_type="parity-auditor"` per feature. The agent's prompt MUST include:
  - Feature ID + V1 path:line entry points + V2 destination path:lines
  - V1 commit hash to pin (`v1_commit_pinned`)
  - The 13 hard halts (inlined or by reference to `migration-discipline.md`)
  - The frontend axes list (form fields, UI affordances, templated query params, event handlers, per-button permission gates, a11y, DOM-equivalent, reactive lifecycle) — for frontend features only
  - Explicit instruction: "Read V1 source line-by-line. Do NOT trust prior audit docs. Do NOT use `...`, `etc.`, `N+ filters`, `and so on`, `deferred to port-phase parity author`, or `by audit-by-inspection`. Enumerate every item in every axis table."
  - Output target: `ai/migration/audits/<feature-id>.md` (full structure per § 4d)
  - Audit doc MUST start with frontmatter declaring `auditor_agent_id: <agent run ID returned by Agent tool>` — this is the proof-of-dispatch the validator checks (see § 4d).

- **Tools with agent + command dispatch but no skill dispatch (Cursor, Copilot)**: same as above — invoke the equivalent agent / sub-task tool. The `auditor_agent_id` field holds the equivalent run ID.

- **Rule-only tools (of the shipped adapters, only Aider — `tool-adapters/_registry.md:23`)**: the executor follows the `extract-v1-contract` / `parity-test-generate` / `perf-uplift-survey` `SKILL.md` files inline (they install with the pack and every adapter translates them), BUT the audit doc's frontmatter MUST declare `auditor_agent_id: rule-only-mode/<tool>/<UTC ISO>`. Validator allows this sentinel; the trade-off is logged so the user can see which tool produced which audit. Lightning-rod feature (any feature in a phase that lists `revenue_critical: true` or `tenant_isolation: true` in the ledger) requires a human-in-the-loop second pass before the row flips to `done`.

**Refusal rule**: an audit doc without a populated `auditor_agent_id` field FAILS the validator (`check_audit_provenance` — see § 4d). The phase cannot exit until every audit has provenance.

**`--audit-only` flag**: skips the PORT + VERIFY steps in § 4c–4e. **It does NOT change the audit mechanism above.** The audit is still produced by the `parity-auditor` agent (or rule-only-mode equivalent). `--audit-only` only means: write artifacts, but keep ledger row at `unverified` (do not flip to `done`).

### 4c. PORT (per feature)

After the audit's classification, the action depends on the verdict:

| Classification | Action |
|---|---|
| `parity-clean` | Skip to § 4e (mark done) |
| `missing-in-v2` | Dispatch `migration-architect` agent → `Agent({subagent_type: "migration-architect"})`. Produces V2 plan in `ai/migration/plans/<feature>.md`. Then implement per the plan. |
| `divergent` | Same as `missing-in-v2` but the plan must enumerate the divergent axes from the audit and cite each remediation. |
| `intentional-break` | Halt; require user to author ADR before advancing. The ADR ID populates the ledger's `intentional_break: ADR-NNN` field. |

Implementation MUST follow V2 patterns (cite by `<path:line>` in the plan). Do NOT lift V1 implementation verbatim.

Add parity tests alongside the implementation: `<parity-test-root>/<feature>/parity.spec.<ext>` + ≥30 corpus inputs in `inputs/` + `tolerance.yaml`. Wire the test in CI if not already.

### 4d. AUDIT FILE STRUCTURE (validator-enforced)

1. Contract complete (9 sections; citations resolve)
2. Parity tests not thin (≥30 inputs OR record-replay; tolerance.yaml covers every output field; per-recipe coverage)
3. Parity tests green against pinned V1 commit
4. Plan exists + matches implementation
5. Perf-decisions complete (every candidate classified; applied has measurement)
6. No V1 modifications in port PR
7. Ledger row updated with required-fields-per-state
8. Rollback runbook exists
9. Scope = exactly one ledger feature row
10. (For non-first-port stages) Cutover mechanism tested in staging within 7 days

Each halt is logged to `ai/migration/audits/<feature-id>.md`'s "Hard-halt findings" section with specific remediation. **Halts BLOCK the feature from advancing.**

**For frontend features**, additionally enumerate per `migration-discipline.md` § Frontend audit axes:
- Form fields (every input listed; type + validation + defaults audited)
- UI affordances (every button / link / dropdown / modal trigger / file-upload / toggle / copy-button — F039 lesson)
- Templated query params (every `?foo=&bar=&...` — no `&...` hand-wave)
- Event handlers (every @click / @submit / @change)
- Per-button permission gates
- Accessibility (axe-core baseline)
- DOM-equivalent assertions
- Reactive lifecycle (the framework's mount-AND-reactivate hook pair declared in the project's anchors)

Output: `ai/migration/audits/<feature-id>.md`. Required structure (validator-enforced):

**Tier requirement**: the audit doc MUST include a `tier:` field in its frontmatter — one of `trivial` / `standard` / `heavy` — with a 1-2 sentence justification in the body citing P0/P1 counts + risk axes from `migration-discipline.md` § Tier classification. The tier propagates from this audit to the ledger row's `tier:` field; downstream artifacts (contract scope, parity-test corpus floor, plan depth, perf-decisions, runbook) are scoped to the tier. **Without a tier on the ledger row, `validate-migration-artifacts.sh` defaults `tier` to `trivial`** — do not rely on implicit heavy artifacts; set `tier:` explicitly before gate when the feature needs standard/heavy floors. See `migration-discipline.md` § Required artifacts per feature — tiered floor.

```markdown
---
auditor_agent_id: <Agent run ID returned by the parity-auditor dispatch>
auditor_mode: agent | rule-only-mode/<tool-name>
audit_date: <UTC ISO8601>
v1_commit_pinned: <sha>
v2_commit: <sha>
tier: trivial | standard | heavy
tier_justification: <1-2 sentences citing P0/P1 counts + risk axes>
---

# Audit — <feature-id> — <feature-name>

## Classification
parity-clean | divergent | missing-in-v2 | intentional-break (ADR-NNN)

## Per-axis comparison
Every applicable axis enumerated. NO `...`, `etc.`, `N+ filters`, `and so on`, `deferred to port-phase parity author`, `by audit-by-inspection`. Validator HALTs on any of these tokens (see `validate-migration-artifacts.sh § check_audit`).

| Axis | V1 (path:line) | V2 (path:line) | Verdict |
|---|---|---|---|
| List endpoint | `GET /<resource>?...` at `<v1-path:line>` | `<v2-path:line>` | match \| mismatch \| missing |
| (one row per relevant axis — concrete observable + cite) | | | |

## Hard-halt findings
One row per halt (or "none"). Each: halt #, evidence, specific remediation.

## Frontend axes (if feature renders UI)
Tables for: Form fields, UI affordances, Templated query params, Event handlers, Per-button permission gates, Accessibility, DOM-equivalent, Reactive lifecycle. Every row has a path:line cite on BOTH sides. Empty cells are not allowed; use `none` if absent.

| Axis | V1 (count + path:line) | V2 (count + path:line) | Verdict |
|---|---|---|---|
| Form fields | n_v1 fields at `<path:line>` (enumerate) | n_v2 fields at `<path:line>` (enumerate) | match \| mismatch |
| UI affordances | n_v1 buttons/links/dropdowns | n_v2 | match \| mismatch |
| ... | | | |

## Tenant-isolation gate
PASS / FAIL. Specific evidence per `migration-discipline.md` checks.

## Decision recommended
<port + parity-test / port + reconcile divergent fields / halt for ADR / etc.>

## ADR references
<list ADR-NNN references or "None">
```

The block above **is** the audit template — fill every section. A fuller worked example (with the per-axis tables and the 13-halt findings grid) ships in the pack source at `templates/packs/migration/_examples/audit-template.md`; it is an authoring reference and is **not** installed into the project, so do not cite it from a generated audit.

### 4e. VERIFY (per-feature validator + parity test run)

After audit + port + parity tests are written:

1. Run `validate-migration-artifacts.sh --feature=<feature-id> --quiet`. The validator MUST exit 0. Specifically `check_audit_provenance` (new) HALTs if `auditor_agent_id` frontmatter is missing or empty. `check_audit` HALTs on hand-wave tokens.
2. Run the parity test against the pinned V1 commit. Test runner must exit 0. Record run ID + result in the ledger row's `parity_runs[]`.
3. Re-classify against the audit. Verdict must be `parity-clean` OR `intentional-break` (with ADR). If still `divergent` or `missing-in-v2`, FLAG the row in ledger as `status: failed`. Do NOT mark `done`. Continue to next feature; the user resumes via `/migration-phase <N> --feature=<id>`.

### 4f. UPDATE LEDGER (per feature)

```yaml
- id: F001
  status: done                       # was: unverified
  parity_test: passing               # was: missing
  v1_commit_pinned: <sha>
  ported_in_phase: <N>
  ported_at: <UTC ISO8601>
  audit: ai/migration/audits/F001-<feature>.md
  audit_provenance: <agent run ID>   # mirrors auditor_agent_id from audit frontmatter
  parity_runs:
    - run_at: <UTC ISO8601>
      v1_commit: <sha>
      v2_commit: <sha>
      result: pass
      cases: <int>
  notes: "<brief>"
```

Use managed-block markers per `templates/idempotency.md` so re-running this phase is safe.

### 4g. AUTO-RUN GATE (end of phase)

After every feature in the phase has either advanced to `done`/`intentional-break` or been flagged `failed`, this command MUST automatically invoke `/migration-gate <N>`. The phase exit is REFUSED if the gate fails. Do NOT advance to phase `<N+1>` on a refused gate; surface the gate's failure list to the user and halt.

`--audit-only` mode skips § 4c (port), § 4e (verify), § 4f (ledger flip to done), and § 4g (auto-gate). It still produces audits + validator runs per § 4b + § 4d. Ledger rows stay at `unverified`.

`--chain` mode runs the full pipeline (audit + port + verify + gate) per feature in dependency order, with `/port-feature <id> --unattended` reading accepted ADRs as pre-approved decisions. The auto-gate STILL fires at end-of-phase per § 4g. See "Chain mode" near the top of this doc for the full contract.

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/migration/ledger.md` — per-feature row updates (managed-block; idempotent).
- `ai/migration/audits/<feature-id>.md` — one per audited feature; append-only.
- `ai/migration/perf-decisions/<feature-id>.md` — if perf was discussed, decisions captured (applied / deferred / rejected + measurements).
- `ai/dynamic/changelog.md` — append entry: "Phase <N> ported <X>/<Y> features".

## Phase 6 — Validate (verify correctness)

After processing every feature in the phase, run the validator script:

```bash
~/.claude/scripts/validate-migration-artifacts.sh --phase=<N>
```

The validator checks every feature in phase N and exits non-zero on any failure. Specifically:

- **Per-feature artifacts complete**:
  - `ai/migration/contracts/<feature>.md` exists with all 9 sections populated
  - Every `<path:line>` citation in the contract resolves
  - `ai/migration/plans/<feature>.md` exists
  - `<parity-test-root>/<feature>/` exists
  - `<parity-test-root>/<feature>/inputs/` has ≥30 entries OR record-replay setup file present
  - `<parity-test-root>/<feature>/tolerance.yaml` exists and covers every contract output field
  - `ai/migration/perf-decisions/<feature>.md` exists with every candidate classified (applied/deferred/rejected); every applied has a measurement
  - `ai/runbooks/migration-rollback-<feature>.md` exists and names mechanism + per-stage rollback steps
  - `ai/migration/audits/<feature>.md` exists with all required sections (classification, per-axis comparison, hard-halt findings, tenant-isolation gate, decision)
- **Per-feature ledger row**: required fields populated per `migration-ledger.md` § Required fields per state
- **Phase summary**: `ai/migration/audits/phase-<N>.md` exists (aggregates per-feature verdicts; first-class artifact `/migration-gate <N>` consumes)
- **No V1 modifications**: PR diff under `<v1-root>/` is empty (or covered by additive cutover-mechanism wiring exception with `migration-discipline.md` rationale)
- **Ledger row updates pass schema validation** (per `migration-ledger.md`)
- **Every parity test runs in CI** (or user explicitly waived in a documented exception)

If the validator exits non-zero → halt; surface findings per feature; do NOT mark the phase done. If the validator is unavailable in the current tool environment, the executor MUST manually verify each item above against `migration-discipline.md` § "Per-feature audit — 13 hard halts" before declaring Phase 6 done.

## Phase 7 — Improve (feed the learning loop)

- Recurring divergence patterns (e.g., "every endpoint had different pagination") → propose a pattern.
- Recurring failure patterns (e.g., "auth always blew up on first port") → flag for `ai/failures/`.
- Effort estimates that diverged from plan by >50% → annotate plan for future phases.

## Output to user

```
Phase <N> complete:
  Features in phase:        <Y>
  Already parity-clean:     <A>   (no work needed)
  Ported (missing-in-v2):   <B>
  Ported (divergent):       <C>
  Intentional breaks:       <D>   (ADR-cited)
  Failed verification:      <F>   ← BLOCK; investigate before /migration-gate <N>

Audits: ai/migration/audits/
Perf decisions: ai/migration/perf-decisions/

Next: /migration-gate <N>      (verifies phase exit criteria; refuses if F > 0)
```

## Hard rules

- **Audit before port.** Never port a feature without first comparing V1 ↔ V2 to know what's actually missing. Audit reads V1 source line-by-line; never trusts an exploration agent's "looks identical" summary (per `migration-discipline.md` § Anti-patterns: "The Trusted Summary").
- **Parity is non-negotiable.** A "ported" feature without a passing parity test ≥30 corpus inputs + tolerance.yaml + green-against-pinned-V1-commit isn't ported.
- **Compose with `/port-feature`.** This command DISPATCHES `/port-feature <id>` per row. It does NOT re-implement the per-feature audit/port loop. (For tools without `/port-feature`, follow the three skills' `SKILL.md` procedures inline — `extract-v1-contract`, `parity-test-generate`, `perf-uplift-survey`.)
- **Use `parity-auditor` agent (or its 13 hard halts inlined).** A generic search/exploration agent is NOT acceptable for the AUDIT step. The 13 hard halts in `migration-discipline.md` § "Per-feature audit — 13 hard halts" is the checklist; an audit that passes the gate without resolving every halt is incomplete.
- **Frontend audit axes are mandatory for frontend features.** Form fields, UI affordances, templated query params, event handlers, per-button permission gates, accessibility, DOM-equivalent assertions, reactive lifecycle. Per `migration-discipline.md` § Frontend audit axes.
- **Follow V2 structure, not V1 lift-and-shift.** Cite V2 patterns/helpers/base classes when porting.
- **Intentional breaks need ADRs.** Behavior divergence by design must be documented before the row flips to `done`.
- **One feature per managed transaction.** A phase can have many features but each is audited + ported + verified atomically. No half-ports persisted to the ledger.
- **Ledger is the source of truth.** This command writes only to the ledger row + audit/perf files. Never edits unrelated ai/ files.

## Related

- `/migration-gate <N>` — runs after this command; enforces phase exit criteria.
- `/migration-park <feature-id>` — set a stuck feature aside; phase continues without it.
- `/migration-rollback <N>` — reverse this phase if a regression surfaces.
- `ai/patterns/feature-port.md` — the per-feature playbook this command applies.
- `ai/patterns/parity-testing.md` — test patterns used during VERIFY.
- `.claude/rules/migration-discipline.md` — parity-non-negotiable contract.
