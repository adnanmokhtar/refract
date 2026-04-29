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
  - The 10 hard halts (inlined or by reference to `migration-discipline.md`)
  - The frontend axes list (form fields, UI affordances, templated query params, event handlers, per-button permission gates, a11y, DOM-equivalent, reactive lifecycle) — for frontend features only
  - Explicit instruction: "Read V1 source line-by-line. Do NOT trust prior audit docs. Do NOT use `...`, `etc.`, `N+ filters`, `and so on`, `deferred to port-phase parity author`, or `by audit-by-inspection`. Enumerate every item in every axis table."
  - Output target: `ai/migration/audits/<feature-id>.md` (full structure per § 4d)
  - Audit doc MUST start with frontmatter declaring `auditor_agent_id: <agent run ID returned by Agent tool>` — this is the proof-of-dispatch the validator checks (see § 4d).

- **Tools with agent + command dispatch but no skill dispatch (Cursor, Copilot)**: same as above — invoke the equivalent agent / sub-task tool. The `auditor_agent_id` field holds the equivalent run ID.

- **Rule-only tools (Aider, Codex, Gemini, Cline, Windsurf)**: the executor follows `migration-discipline.md` § Tool-agnostic procedure inline, BUT the audit doc's frontmatter MUST declare `auditor_agent_id: rule-only-mode/<tool>/<UTC ISO>`. Validator allows this sentinel; the trade-off is logged so the user can see which tool produced which audit. Lightning-rod feature (any feature in a phase that lists `revenue_critical: true` or `tenant_isolation: true` in the ledger) requires a human-in-the-loop second pass before the row flips to `done`.

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
- Reactive lifecycle (`onActivated` for cached pages)

Output: `ai/migration/audits/<feature-id>.md`. Required structure (validator-enforced):

```markdown
---
auditor_agent_id: <Agent run ID returned by the parity-auditor dispatch>
auditor_mode: agent | rule-only-mode/<tool-name>
audit_date: <UTC ISO8601>
v1_commit_pinned: <sha>
v2_commit: <sha>
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

Refer to `_examples/audit-template.md` for a worked example.

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
