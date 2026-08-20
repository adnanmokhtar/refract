---
name: contract-diff
description: Diff a source or model schema against its declared data contract and classify every change as additive, breaking, or semantic-breaking — then name the consumers each class would break and the required notice. Run before publishing a schema change, when an upstream team announces one, when a load starts failing after "nothing changed", and on a schedule against volatile sources. Classifies WHETHER a change breaks — `lineage-trace` names WHO it breaks, and `grain-probe` catches the damage after the fact.
---

# Skill: contract-diff

## Premise

The expensive schema changes are the ones that are not breaking in any type-checker's sense. A column keeps its name and its type and starts meaning something else: `amount` moves from cents to dollars, `status` gains a member the downstream `CASE` does not handle, a nullable column starts arriving null. Nothing fails. Every number changes.

Every classification cites the contract version, the observed schema, and the field. A classification with no observed evidence is a guess.

## Halt conditions

- **No declared contract exists** for the source or model. Refuse to classify — you would be diffing against yesterday's accident. Report `NO CONTRACT` and propose one from the current observed schema (see step 5) as the baseline; that proposal is not a classification.
- **Contract version unknown** on either side.
- **Only one snapshot available.** A diff needs two schemas; a single observation is an inventory, not a diff.
- **Semantic classification requested without a data sample.** Type-level diffs come from the schema; semantic breaks are only visible in values. Say which you had.

## When to run

- Before publishing any change to a model or table that another team reads.
- When an upstream producer announces a change — classify before agreeing a date.
- When a load starts failing, or an assertion starts firing, and the producer says nothing changed.
- On a schedule against sources you do not control (third-party APIs, partner file drops), so drift is found by the check rather than by the dashboard.
- As step one of triage for any "the numbers moved" report.

## Procedure

### 1. Establish both sides

- **Declared** — the contract: field names, types, nullability, accepted values, units, semantics, grain, freshness, version.
- **Observed** — the current schema, read from the platform's information schema or the source's response, plus a value sample when semantics are in scope.

Record both with their timestamps. A diff between a contract and a schema read a week apart can mislead.

### 2. Classify every field-level change

| Class | Shape | Consumer effect |
|---|---|---|
| **ADDITIVE** | new optional field; new accepted-value member on a field that is only passed through; widened numeric type; loosened nullability on a field nothing requires | none, if consumers select explicitly. `SELECT *` consumers may still break — flag them. |
| **BREAKING** | field removed or renamed; type narrowed or changed; nullability tightened; a required field becomes optional; grain change | consumers fail loudly. Requires notice and a migration window. |
| **SEMANTIC-BREAKING** | same name, same type, different meaning: unit change, timezone change, currency change, precision change, a new enum member that existing branches silently drop, a code that is reused for a different concept, a soft-delete flag that starts being populated | **nothing fails.** Every downstream number changes silently. This is the dangerous class. |

A change can be additive at the schema level and semantic-breaking at the value level. Classify both dimensions; report the worse one.

### 3. Hunt the semantic class deliberately

Schema diffing will not find these. For each field in scope, compare distributions between the two snapshots:

- **Unit / magnitude shift** — the mean or median moves by roughly a power of ten (or by a currency-conversion-shaped factor) with no change in row count.
- **New enum members** — set difference on distinct values; cross-reference every `CASE`/`IF` branch downstream that consumes the field. A new member falling through to an `else` is a silent reclassification.
- **Null-rate shift** — a field that was 0% null starts arriving 8% null.
- **Timezone / date shift** — the daily row-count histogram shifts by a whole number of hours.
- **Precision change** — trailing-digit distribution collapses (values start ending in `00`).

### 4. Attach consumers and notice

For every BREAKING and SEMANTIC-BREAKING change, run `lineage-trace` and attach the consumer list. Then state the required notice: the migration window the contract specifies, or — if the contract is silent — the longest refresh cycle among the consumers found, because a partner reading monthly cannot react in a week.

### 5. Propose the contract update

Output the new contract version with the change recorded: what changed, its class, its effective date, and the deprecation window for anything removed. A contract that is edited without a version bump is not a contract.

### 6. Report

```
## contract-diff — <source|model> — <date>

Contract version:  <declared>      Observed at: <timestamp>
Sample available:  yes | no (semantic class not assessable)

| Field | Declared | Observed | Class | Evidence | Consumers | Notice required |
|-------|----------|----------|-------|----------|-----------|-----------------|

Summary: ADDITIVE <n> · BREAKING <n> · SEMANTIC-BREAKING <n>

Verdict: COMPATIBLE | REQUIRES-MIGRATION | SILENT-DRIFT-DETECTED | NO CONTRACT

Proposed contract version: <next>   effective <date>   deprecations expire <date>
```

## Inputs

- The declared contract (`ai/data/contracts/<name>.md` or the project's equivalent).
- The observed schema, and a value sample from each snapshot if semantics are in scope.
- `lineage-trace` output for consumer attachment.

## Outputs

- The report block above.
- A proposed contract version bump.
- For any SEMANTIC-BREAKING finding: a proposed standing assertion (accepted-values, null-rate band, or measure-drift bound) so the next occurrence is caught by the suite rather than by this skill. Hand it to `@data-quality-auditor`.

## False positives / gotchas

- **Column order changes** are not a change. Diff by name, not by position; positional diffs generate noise that trains people to ignore the report.
- **Platform type aliases** (`text` vs `varchar`, `int8` vs `bigint`) are the same type on most engines. Normalise before classifying or every re-read is a "breaking change".
- **Case sensitivity** — some platforms fold identifiers, some do not. Normalise consistently or a case-only rename reads as a drop-plus-add.
- **A distribution shift caused by real business change** — a genuine tenfold in volume looks like a unit change. Cross-check row counts and a second correlated field before calling a unit shift.
- **Classifying additive changes as safe for `SELECT *` consumers.** They are not. If the repo has `SELECT *` anywhere in scope, every additive change is potentially breaking for those models — list them.
- **Diffing against the last successful load rather than the contract.** That measures drift from an accident. If there is no contract, say `NO CONTRACT` and propose one.

## Related

### Skills
- `lineage-trace` — the consumer attachment this skill's notice calculation depends on.
- `grain-probe` — catches the damage a missed semantic break already caused.

### Agents
- `@data-quality-auditor` — receives the proposed standing assertions.
- `@analytics-engineer` — owns the staging layer that should absorb additive changes.
- `@warehouse-modeler` — owns grain changes, which are always breaking.

### Commands
- `/audit-data-quality` — the accepted-values and drift assertions this skill proposes.
- `/audit-data-model` — uses this skill when a finding traces to an upstream change.

### Patterns
- `ai/patterns/data-contract.md`
- `ai/patterns/data-quality-tests.md`
