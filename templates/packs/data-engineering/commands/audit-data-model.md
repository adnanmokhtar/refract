---
description: Audit the warehouse's analytical model — declared grain, fact/dimension separation, key and SCD correctness, conformed dimensions, join cardinality, and layering violations. Read-only; produces a per-model verdict ledger with a probe result behind every uniqueness claim.
kind: command
pack: data-engineering
---

# /audit-data-model [<scope>] [--layer mart|intermediate|staging]

Audit the models a business already trusts. Warehouse defects do not announce themselves — a wrong number looks like a number. This command produces a per-model ledger where every uniqueness claim has a probe result behind it and every join has a proven cardinality.

## When to use / NOT to use

- USE: before a mart is exposed to a dashboard or an external consumer; after a reported number turned out to be wrong; when two dashboards disagree; on a quarterly cadence for money-bearing models; when inheriting a warehouse.
- NOT: to audit whether the data arriving is correct — that is `/audit-data-quality`.
- NOT: to audit the loading code's idempotency and checkpointing — that is `/audit-pipeline` (data-pipeline signal).
- NOT: to audit OLTP schema — that is `/db-audit` in the database pack.

## Phases applied

1-3 + 6 (audit shape — no Generate, no Update; the output is findings).

## The Premise (read this first, internalize, do not deviate)

**Every claim carries a probe result or a citation.** "The grain is unique" is only true when `grain-probe` says so, in this run, with the count pasted in. "The join is many-to-one" is only true when the probe shows one match per fact row. Reading the SQL is how you form a hypothesis, not how you reach a verdict.

**Enumerate; do not sample.** Every model in scope gets a row. A model omitted from the ledger was not audited, and the report says so explicitly rather than implying coverage.

**A wrong number that is currently on a dashboard is a BLOCKER**, regardless of effort to fix — it is actively misleading someone. Say so plainly and name the surface it appears on.

## Mechanical halt — hand-wave grep

Canonical procedure: [`templates/snippets/hand-wave-grep.md`](../../../snippets/hand-wave-grep.md). Below adds the model-audit tokens.

Before emitting the report, scan every finding for: `probably unique`, `should be one-to-one`, `looks like the grain`, `roughly`, `a few duplicates`, `N+ similar models`, `etc.`. Any match = HALT. Replace with a probe result and a count, or drop the claim. A finding that cannot be probed is reported as **UNKNOWN — <what would settle it>**, which is a legitimate outcome; a softened assertion is not.

## Phase 1 — Understand

Confirm:
- Scope — subject area, layer, or model list.
- Which models are consumer-facing today (dashboards, exports, reverse-ETL, external partners). These are audited first and their findings are severity-weighted.
- The tenancy model, the timezone convention, and the restatement policy. Each is a halt condition for `@warehouse-modeler`; collect them once here.

## Phase 2 — Organize

Group the scope into four passes, run in this order because each depends on the previous:

1. **Grain pass** — declared grain per model; probe each. Everything downstream is invalid without it.
2. **Structure pass** — fact type, measure additivity, surrogate/natural keys, SCD type per attribute, unknown-member handling.
3. **Relationship pass** — every join predicate's cardinality, bridge tables, referential completeness.
4. **Conformance pass** — shared dimensions with more than one definition; the same metric computed in more than one model.

## Phase 3 — Retrieve

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Additionally:
- `ai/patterns/dimensional-model.md`, `ai/patterns/transformation-layers.md`, `ai/patterns/semantic-layer.md`.
- `.claude/rules/data-engineering-principles.md`.
- The model catalog / documentation, and the BI layer's model references if reachable — a metric redefined in the BI tool is in scope.
- `ai/decisions/dimension-history.md` if present.

## Phase 6 — Validate

Dispatch, in order:

- **`grain-probe`** on every model in scope. Its output is the uniqueness column of the ledger; no other source is accepted.
- **`@warehouse-modeler`** on the models that failed a probe or whose structure pass raised a question. It issues the design verdict.
- **`lineage-trace`** on every model with a finding, to size the blast radius: which dashboards, exports, and downstream models consume the wrong number today.
- **`contract-diff`** where a finding is caused by an upstream shape change rather than a modelling choice — it classifies whether the change was breaking and when it landed.

Cardinality probes are run, not reasoned: for each fact→dimension join, count fact rows before and after the join. An increase is fan-out; a decrease is silent row loss. Both are findings, and the row counts go in the finding.

## Output format

```
## /audit-data-model — <scope> — <date>

Models in scope: N   |   Audited: N   |   Not audited: N (named below, with reason)

### Grain ledger
| Model | Layer | Declared grain | Probe: rows / distinct key | Unique? | Consumer-facing |
|-------|-------|----------------|----------------------------|---------|-----------------|

### Join cardinality ledger
| Fact model | Dimension | Predicate | Rows before → after | Expected | Verdict |
|------------|-----------|-----------|---------------------|----------|---------|

### Conformance
| Shared concept | Definitions found (paths) | Canonical? | Disagreement observed |
|----------------|---------------------------|------------|-----------------------|

### Findings
BLOCKERS (N)  — wrong numbers currently served, fan-out, overlapping Type 2 ranges,
                semi-additive measures summed over time, duplicated shared dimensions
REQUESTS (N)  — missing unknown-member rows, missing referential tests, layering violations
NITS (N)      — naming, annotation, pre-divided ratios
UNKNOWN (N)   — what could not be settled, and exactly what would settle it

Each finding: <model path:line> · what · why it is wrong · blast radius from lineage-trace ·
              fix · how to verify the fix

Hand-wave grep: ✓ | halts=<N>
```

Write the report to `ai/audits/data-model-audit-<date>.md`.

## Hard rules

- **No uniqueness claim without a probe result in this run.** Historical probe output is not evidence.
- **No cardinality claim without before/after row counts.**
- **Every finding states its blast radius** — which live surfaces are affected — or it is not actionable.
- **UNKNOWN is a valid verdict** and must name what would settle it. A guess dressed as a finding is worse than a gap.
- **Never propose a fix that changes a historical series without saying so.** Restating history is a communication event, not just a code change.

## Failure modes

- Auditing staging models thoroughly and marts superficially — the mart is where the number becomes a claim.
- Declaring a join safe because the schema says foreign key; the warehouse does not enforce it.
- Missing the BI-layer redefinition because the audit stopped at the repo boundary.
- Reporting a conformance problem without naming which of the two definitions is canonical — the team cannot act on a tie.
- Fixing a fan-out and not restating the historical series, so the trend line has a step nobody can explain.

## Related

- `@warehouse-modeler` — issues the design verdicts this command collects.
- `@analytics-engineer` — owns the layering violations found in the structure pass.
- `@data-quality-auditor` — the standing-test counterpart; this audit's findings become its assertions.
- `grain-probe`, `lineage-trace`, `contract-diff` — the executors.
- `ai/patterns/dimensional-model.md`, `ai/patterns/semantic-layer.md`.
- `.claude/rules/data-engineering-principles.md`.
