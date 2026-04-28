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

For each feature in the phase, run this sub-routine:

### 4a. AUDIT

Use the project's audit agent (e.g., `api-contract-verifier`, `business-auditor`, or generic `parity-auditor` if no project-specific exists).

Comparison axes (apply only the ones relevant to this feature's shape):
- **Inputs** — request body, query params, headers, file uploads, queue message envelope, CLI args, etc.
- **Outputs** — response body, status code, headers, side-effects, emitted events, written files, return value.
- **Error contract** — error codes, messages, retry semantics.
- **Auth + permissions** — who can call / who is denied / what role grants what.
- **Side effects** — DB writes, queue publishes, external API calls, audit log entries.
- **Performance envelope** — p50 / p99 latency budget; document if V2 differs.

Output: `ai/migration/audits/<feature-id>.md` with one section per axis.

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

After processing every feature in the phase:

- Every feature in the phase has been audited.
- Every audit produced an `audits/<feature-id>.md` file.
- Every parity test runs in CI (or user explicitly waived in a noted exception).
- Ledger row updates pass schema validation.

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

- **Audit before port.** Never port a feature without first comparing V1 ↔ V2 to know what's actually missing.
- **Parity is non-negotiable.** A "ported" feature without a passing parity test isn't ported.
- **Follow V2 structure, not V1 lift-and-shift.** Cite V2 patterns/helpers/base classes when porting.
- **Intentional breaks need ADRs.** Behavior divergence by design must be documented before the row flips to `done`.
- **One feature per managed transaction.** A phase can have many features but each is audited + ported + verified atomically. No half-ports persisted to the ledger.
- **Ledger is the source of truth.** This command writes only to the ledger row + audit/perf files. Never edits unrelated ai/ files.
