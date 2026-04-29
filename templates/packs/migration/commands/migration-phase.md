---
description: Executes one migration phase. For each feature in the phase: AUDIT (compare V1 vs V2) → identify GAPS → PORT (fill gaps using V2 structure) → VERIFY (parity test). Updates ledger as it progresses. Stops at phase boundary. Stack-agnostic.
kind: command
pack: migration
---

# /migration-phase <N>

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
- `--audit-only` — run audit step but skip port + verify. Useful for triage.

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

**Composition**: this command DISPATCHES `/port-feature <feature-id>` per row. It does NOT re-implement the per-feature audit/port loop; that lives in `/port-feature` with full discipline (`extract-v1-contract` + `migration-architect` + `parity-test-generate` + `perf-uplift-survey` + `parity-auditor`). Skipping the dispatch is the F039 trigger — a permissive shell over a strict toolchain that lets a loose executor produce shallow artifacts.

For each feature in the phase, in plan order:

### 4a. PRE-FLIGHT (per feature)

Halt before invoking `/port-feature` if any:
1. Ledger row exists for this feature.
2. Feature's dependencies (per ledger) are `V2-only` OR override `--depend-on-v1` documented.
3. `~/.claude/scripts/migration-detect-existing.sh "<v2-root>" "<feature-slug>"` returns `none` or `partial` (never `full` without `--overwrite-v2`).
4. V1 branch is at HEAD of a clean working tree.

### 4b. DISPATCH `/port-feature` (per feature)

Invoke `/port-feature <feature-id>` per row. The orchestrator runs the 7-phase per-feature lifecycle:

| `/port-feature` phase | Output artifact (per `migration-discipline.md` § Required artifacts) |
|---|---|
| 1. Understand V1 | `ai/migration/contracts/<feature>.md` (9 required sections) |
| 2. Plan V2 | `ai/migration/plans/<feature>.md` |
| 3. Port | V2 implementation in `<v2-root>/<feature>/` |
| 4. Parity tests | `<parity-test-root>/<feature>/` (≥30 corpus inputs OR record-replay) + `tolerance.yaml` |
| 5. Perf uplift | `ai/migration/perf-decisions/<feature>.md` (every candidate classified + measured) |
| 6. Cutover audit | `ai/runbooks/migration-rollback-<feature>.md` + `parity-auditor` Stage A green |

If `/port-feature` halts at any phase, this command captures the halt root cause to `ai/migration/halts/<feature>-<iso>.md` and continues to the next feature in the phase. The user resumes the halted feature with `/port-feature <feature-id> --resume` after fixing the cause.

**For tools without `/port-feature` dispatch**: follow the procedures inlined in `migration-discipline.md` § Tool-agnostic procedure (extract V1 contract → generate parity tests → perf-uplift survey). Produce the same artifact set. Use `scripts/validate-migration-artifacts.sh` to verify completeness.

### 4c. AUDIT (per feature; using the 10 hard halts)

After `/port-feature` reports phase-6 audit PASS for a feature, this command verifies independently against `migration-discipline.md` § "Per-feature audit — 10 hard halts":

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
- Reactive lifecycle (`onActivated` for cached pages)

### 4d. PER-FEATURE AUDIT FILE

Output: `ai/migration/audits/<feature-id>.md`. Required structure:

```markdown
# Audit — <feature-id> — <feature-name>

> Phase: <N> | Audited: <iso> | Auditor: <agent / executor / tool>
> V1 commit pinned: `<sha>`
> V2 commit: `<sha>`

## Classification
parity-clean | divergent | missing-in-v2 | intentional-break (ADR-NNN)

## Per-axis comparison (every applicable axis enumerated; no "..." or "etc.")

| Axis | V1 | V2 |
|---|---|---|
| <axis 1> | <observable + path:line cite> | <observable + path:line cite> |
| <axis 2> | ... | ... |

## Hard-halt findings
List every halt fired (or "none"). Each: which halt, evidence, specific remediation.

## Frontend axes (if applicable)
| Axis | V1 | V2 |
|---|---|---|
| Form fields | <enumerated list with types + validators> | <enumerated list> |
| UI affordances | <every button + handler + permission gate> | <every button + handler + permission gate> |
| Templated query params | <every param V1 sends> | <every param V2 sends> |
| ... | | |

## Tenant-isolation gate
PASS / FAIL. Specific evidence per `migration-discipline.md` checks.

## Decision recommended
<port + parity-test / port + reconcile divergent fields / halt for ADR / etc.>

## ADR references
<list ADR-NNN references or "None">
```

Refer to `_examples/audit-template.md` for a worked example.

### 4b. GAP-FIND

From the audit, classify the feature:

| Classification | Meaning | Action |
|---|---|---|
| `parity-clean` | V2 matches V1 across every axis | Skip to step 4d (mark done) |
| `missing-in-v2` | V2 has no implementation | Step 4c: port from scratch |
| `divergent` | V2 implements but behavior differs | Step 4c: port with reconciliation |
| `intentional-break` | V2 differs by design (cite ADR) | Step 4d (mark done with `intentional_break: ADR-NNNN`) |

If `intentional-break` and no ADR exists → halt; require user to author ADR first.

### 4c. PORT

Only run if classification is `missing-in-v2` or `divergent`.

**Constraint: follow V2's NEW structure.** Cite V2 patterns explicitly. Do NOT lift V1 implementation verbatim.

For each gap:
1. Identify the V2 destination (path from ledger).
2. Identify the V2 patterns/helpers/base classes to use (cite by file:line).
3. Implement using V2 conventions (`ai/conventions.md` is authoritative).
4. Add parity test alongside (e.g., `<feature>.parity.spec.<ext>`) — uses V2's test runner; asserts V1 behavior holds.
5. Wire up the parity test in CI if not already.

Generate test framework + helpers via project's existing test commands (e.g., `/add-test`) if they exist.

### 4d. VERIFY

Re-run the audit (step 4a). Result must be `parity-clean` OR `intentional-break` (with ADR).

If still `divergent` or `missing-in-v2` → log to `ai/migration/audits/<feature-id>.md` and FLAG the row in ledger as `status: failed`. Do NOT mark `done`. Continue to next feature.

### 4e. UPDATE LEDGER

For each feature processed, update the row:

```yaml
- id: F001
  status: done                    # was: unverified
  parity_test: passing            # was: missing
  v1_commit_pinned: <sha>
  ported_in_phase: <N>
  ported_at: <UTC ISO8601>
  notes: "<brief — e.g. 'used V2 service layer pattern'>"
```

Use managed-block markers per `templates/idempotency.md` so re-running this phase is safe.

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

If the validator exits non-zero → halt; surface findings per feature; do NOT mark the phase done. If the validator is unavailable in the current tool environment, the executor MUST manually verify each item above against `migration-discipline.md` § "Per-feature audit — 10 hard halts" before declaring Phase 6 done.

## Phase 7 — Improve (feed the learning loop)

- Recurring divergence patterns (e.g., "every endpoint had different pagination") → propose a pattern.
- Recurring failure patterns (e.g., "auth always blew up on first port") → flag for `ai/_baseline/failures/`.
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
- **Compose with `/port-feature`.** This command DISPATCHES `/port-feature <id>` per row. It does NOT re-implement the per-feature audit/port loop. (For tools without `/port-feature`, follow the inlined procedures in `migration-discipline.md` § Tool-agnostic procedure.)
- **Use `parity-auditor` agent (or its 10 hard halts inlined).** A generic search/exploration agent is NOT acceptable for the AUDIT step. The 10 hard-halts in `migration-discipline.md` § "Per-feature audit — 10 hard halts" is the checklist; an audit that passes the gate without resolving every halt is incomplete.
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
