---
description: Audit and close data-trust gaps — per-model assertion coverage across structural, temporal, distributional, and reconciliation floors, plus severity, ownership, and routing for every failure. Writes the missing assertions, not just a list of them.
kind: command
pack: data-engineering
---

# /audit-data-quality [<scope>] [--write-tests]

Audit whether this warehouse can tell you when it is wrong. Most warehouses can tell you when a job failed; far fewer can tell you when a job succeeded and loaded nonsense. This command measures coverage against four floors, then closes the gaps it found.

## When to use / NOT to use

- USE: before a model backs a money or compliance decision; after any incident where a wrong number reached a human; when the test suite has never failed; when nobody can name who is paged for a stale table; on a quarterly cadence.
- NOT: to assess whether the model's shape is right — that is `/audit-data-model`.
- NOT: to assess application code correctness — that is the testing pack.
- NOT: to design infra alerting — that is `/alert-design` in the observability pack; data assertions reuse its routing rather than inventing a second one.

## Phases applied

1-3 + 4 (only under `--write-tests`) + 5 + 6.

## The Premise (read this first, internalize, do not deviate)

**Coverage is per model and per floor.** An aggregate percentage is a hiding place. Every model in scope gets a row with four independent verdicts.

**A green suite is a hypothesis, not evidence.** Check the run history: a suite that has never failed is either trivially true or not executing. Report which, with the run record.

**Assertions without routing are decoration.** Every assertion has a severity, an owner, and a destination. If a failure lands somewhere nobody reads, report the model as uncovered on that floor regardless of how many assertions exist.

**Existing assertion style is the truth.** New assertions match the shape, placement, severity vocabulary, and naming of the ones already in the repo. Do not introduce a second testing idiom.

## Mechanical halt — hand-wave grep

Canonical procedure: [`templates/snippets/hand-wave-grep.md`](../../../snippets/hand-wave-grep.md). Below adds the data-quality tokens.

Before emitting the report: scan for `should catch`, `probably covered`, `mostly tested`, `reasonable threshold`, `sensible default`, `industry standard`. Any match = HALT. Every threshold cites either a trailing-history statistic computed in this run or a stated business bound. A threshold with no derivation is not shipped.

## Phase 1 — Understand

Confirm, in one consolidated question:
- Scope — models, subject area, or "everything consumer-facing".
- **Freshness SLA** per model in scope (how stale before someone must act). Without it there is no late table.
- **Failure policy** per model — halt, quarantine, or warn. Differs per model; cannot be guessed.
- **Owner** per model — the recipient of a severity-`error` failure.
- **PII classification** for any table the audit might sample. Unclassified tables are not sampled.

## Phase 2 — Organize

Assess each model against four floors, independently:

1. **Structural** — uniqueness on the declared grain (composite tested as composite), not-null on join/filter columns, referential integrity per fact foreign key, accepted values per enum consumed by a branch, type/range bounds on measures.
2. **Temporal** — freshness monitor with a threshold tied to the load cadence; volume monitor as a band derived from trailing history (an absolute floor a growing business always clears is not a monitor); Type 2 range integrity.
3. **Distributional** — null-rate, category-mix, and headline-measure drift against trailing baselines with stated tolerances.
4. **Reconciliation** — warehouse totals versus the source system for money- and count-bearing facts, at a stated cadence and tolerance; plus cross-grain agreement (a daily rollup sums to its detail fact).

## Phase 3 — Retrieve

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Additionally:
- `ai/patterns/data-quality-tests.md`, `ai/patterns/data-contract.md`.
- `.claude/rules/data-engineering-principles.md`.
- The existing assertion files and their run history (which failed, when, what happened next).
- The quarantine tables, with their last-read date and row counts.

## Phase 4 — Generate (only under `--write-tests`)

Write the missing assertions in the project's existing idiom:
- Derive every threshold from trailing history computed in this run, and record the derivation inline (the window, the statistic, the tolerance). No borrowed numbers.
- Assign severity from the model's declared failure policy, not from habit.
- Route every severity-`error` assertion to its owner.
- Add the reconciliation assertion for every money-bearing fact — this is the floor most warehouses skip, and the one that catches shape-preserving corruption.

## Phase 5 — Update

- `ai/data/quality-contract.md` — one entry per model: grain, freshness SLA, failure policy, owner, the four floors and their assertions.
- Retire assertions disabled for more than one quarter: either re-enable with a corrected threshold or delete them with a note. A permanently disabled assertion is a lie in the repo.
- Give every quarantine table a reader and a retention policy, or delete it.

## Phase 6 — Validate

- **Run every new assertion.** An assertion that has not executed is not shipped.
- **Prove at least one assertion can fail** — inject a violating row into a scratch copy (never production) and confirm the assertion fires and routes. An assertion that has never been observed failing is unverified.
- **Check the run history** of the pre-existing suite and report suites with zero failures ever.
- Dispatch **`@data-quality-auditor`** for the verdict.

### Coverage ledger — REQUIRED OUTPUT ARTIFACT (the run is not done until this table exists)

```
Model           | Structural | Temporal | Distributional | Reconciliation | Owner | Failure policy | Status
fct_orders      | 5/5        | 2/2      | 2/3            | present        | data  | halt           | COVERED
stg_payments    | 3/4        | 1/2      | 0/2            | ABSENT         | —     | undeclared     | UNCOVERED
```

Per-row `Status`:
- **COVERED** — all four floors have at least their mandatory assertions, each executed in this run, each with a severity and a routed owner.
- **UNCOVERED** — a floor is missing, or an assertion exists but has no owner/route. Name the floor.
- **UNVERIFIED** — assertions exist and were written but not executed, or the fail-path was never demonstrated.

## Output format

```
## /audit-data-quality — <scope> — <date>

Models in scope: N   |   COVERED n | UNCOVERED n | UNVERIFIED n

Coverage ledger: <the table above, verbatim>

Assertion health:
  Assertions disabled > 90d:            N   (listed with their disable date)
  Severity-error assertions with owner: N / N
  Quarantine tables unread > 90d:       N
  Suites with zero failures in history: N   (named)
  Thresholds with a derivation cited:   N / N

Assertions written (under --write-tests): N
Fail-path demonstrated for:               <assertion name> on a scratch copy

Hand-wave grep: ✓ | halts=<N>

Status: <see gate below>
```

**Every UNCOVERED / UNVERIFIED row carries a closure verb from the owning pattern — never an invented one.** The verbs this audit may emit:

- `data-quality-tests` → `prove-assertion-can-fail`, `retire-disabled-assertion`, `assign-assertion-owner`, `add-freshness-monitor`, `add-volume-band`, `add-reconciliation-check`, `derive-threshold-from-history`, `route-quarantine-reader`, `move-coverage-to-marts`
- `data-contract` → `write-contract`, `declare-units-and-timezone`, `version-contract-change`, `assert-accepted-values`, `schedule-schema-diff`, `date-the-deprecation`, `narrow-select-star`

These are copies of the patterns' own lists; where they disagree the pattern wins. The vocabulary exists so a **second run can diff which rows closed** — a ledger whose remediation is prose cannot be diffed, so a repeat audit cannot distinguish a fixed gap from a re-worded one. In particular, `prove-assertion-can-fail` is the only verb that closes the zero-failure-history row: writing more assertions into an unproven suite does not close it.

### Closure gate — COMPLETE only when every ledger row is COVERED

- **`Status: COMPLETE`** — every row COVERED, every new assertion executed, at least one fail-path demonstrated, and every threshold carrying its derivation.
- **`Status: INCOMPLETE — unmet: <list>`** — the moment any row is UNCOVERED or UNVERIFIED. Name each model and the missing floor (`fct_orders — UNCOVERED: no reconciliation against the billing source`).

This gate is **[self-policed]** on the Status line, but every input is inspectable: assertion run output, the owner map, the trailing-history statistic behind each threshold. `@data-quality-auditor` will BLOCK a COMPLETE whose reconciliation column is empty on a money-bearing fact.

## Hard rules

- **A money- or decision-bearing model with no reconciliation assertion is a BLOCKER**, whatever else it has.
- **No threshold without a derivation** computed in this run or a cited business bound.
- **No severity-`error` assertion without a named owner.**
- **Never sample row values from a table with unknown PII classification.**
- **A volume monitor is a band, not a floor.**

## Failure modes

- Column tests everywhere, reconciliation nowhere — the suite is green while revenue is wrong.
- Freshness thresholds so loose they cannot fire.
- Assertions that only ever ran on a clean fixture; the fail path was never exercised.
- Quarantine as a landfill: rows diverted, nobody reads them, the data is quietly lost.
- A page routed to a rotation that no longer exists.

## Related

- `@data-quality-auditor` — issues the verdict.
- `@warehouse-modeler` — supplies the declared grain the structural floor tests against.
- `@dag-reviewer` — decides where in the graph a failing assertion stops the build.
- `grain-probe`, `contract-diff` — the executors.
- `ai/patterns/data-quality-tests.md`, `ai/patterns/data-contract.md`.
- `alert-design` (observability pack) — the routing this command reuses for paging assertions.
