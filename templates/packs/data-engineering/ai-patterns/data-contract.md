---
name: data-contract
description: 'Pattern: Data Contract (declared shape + semantics + version, and the three classes of change)'
kind: ai-pattern
pack: data-engineering
---

# Pattern: Data Contract

> **Hard rule:** Every source consumed and every model published carries a versioned contract naming its fields, types, nullability, accepted values, **units and semantics**, grain, and freshness. Every change is classified ADDITIVE / BREAKING / SEMANTIC-BREAKING, and the third class — same name, same type, new meaning — is the one that must be hunted deliberately because nothing fails when it happens.

**When to apply**
- Any table another team, another service, or an external partner reads.
- Any source you do not control: third-party APIs, partner file drops, another team's database.
- A load starts failing, or an assertion starts firing, and the producer says nothing changed.
- Before agreeing a date with an upstream team that has announced a change.

**When NOT to apply**
- A table with exactly one consumer inside the same commit boundary — the contract is the code review.
- A scratch or exploratory model, explicitly marked as such with an expiry.

**Halt conditions / mandatory cites**
- No contract exists — do not "diff against the last successful load". That measures drift from an accident. Declare a baseline contract from the observed schema first, and label it as a baseline, not a classification.
- Contract version unknown on either side of a diff — halt.
- Semantic classification requested with no value sample — schema alone cannot see it. Say which you had.
- Consumers unenumerated — the required notice period cannot be computed. Run `lineage-trace`.

## What a contract declares

| Field | Why it is in the contract |
|---|---|
| name, type, nullability | the mechanical shape; the only part most teams write down |
| **unit** (cents / dollars / bytes / ms / count) | the single most common silent break |
| **timezone** for every timestamp and derived date | the second most common |
| accepted values for every enum | so a new member is a failure, not a silently-dropped `CASE` branch |
| **semantics** — one sentence per non-obvious field | "`status = closed` means the invoice was paid OR written off" |
| grain | one row means what |
| freshness | how stale before a consumer must act |
| version + effective date | a contract edited without a bump is not a contract |
| owner | who agrees to a change, and who is told about one |

The unit, the timezone, and the semantics are what separate a contract from a schema dump. A schema dump prevents type errors. A contract prevents wrong numbers.

## The three classes of change

| Class | Shape | What consumers experience |
|---|---|---|
| **ADDITIVE** | new optional field; new accepted-value member on a passthrough field; widened numeric type; loosened nullability | nothing — *unless* a consumer uses `SELECT *`, in which case additive changes reshape their model. List those consumers explicitly. |
| **BREAKING** | field removed or renamed; type narrowed or changed; nullability tightened; grain change | loud failure, migration window required |
| **SEMANTIC-BREAKING** | unit change; timezone change; currency change; precision change; a new enum member existing branches drop into `else`; a reused code; a flag that starts being populated | **nothing fails.** Every downstream number moves. Found weeks later, by finance. |

A change can be schema-additive and semantically breaking at the same time. Classify both dimensions and report the worse one.

## Hunting the semantic class

Schema diffing will never find these. Compare value distributions between two snapshots:

- **Unit / magnitude shift** — mean or median moves by roughly a power of ten, or by a currency-conversion-shaped factor, with row count unchanged.
- **New enum members** — set difference on distinct values, then cross-reference every downstream branch that consumes the field.
- **Null-rate shift** — a field that was never null starts arriving null some of the time.
- **Timezone shift** — the hourly row-count histogram translates by a whole number of hours.
- **Precision collapse** — values start ending in `00`; someone rounded upstream.

Each of these becomes a standing assertion once found, so the second occurrence is caught by the suite instead of by a person.

## Notice and migration

The required notice is the longest refresh cycle among the enumerated consumers, not the producer's convenience. A partner that reads monthly cannot react to a week's notice, and "we announced it in the channel" is not a migration plan.

Migration shape for a BREAKING change:
1. Publish the new version alongside the old.
2. Repoint consumers, named individually from `lineage-trace`.
3. Remove the old version after the stated deprecation window, which is a date in the contract, not a feeling.

For a SEMANTIC-BREAKING change, add one step at the front: **decide whether history is restated**. If it is not, the series has a documented break at a date, and every consumer is told the date. If it is, that is a backfill with its own plan.

## Enforcement points

A contract nobody checks is a document. Put it where it runs:
- **At the boundary** — validate arriving data against the contract at ingestion; violating rows quarantine rather than propagate.
- **In the suite** — accepted-values, null-rate bands, and measure-drift bounds as standing assertions.
- **On a schedule** — diff the observed schema of uncontrolled sources against the contract, so drift is found by the check rather than by the dashboard.
- **In review** — a change to a published model's shape requires the contract version bump in the same commit.

## Detectors

- A published table with no contract file.
- A contract with no `unit` on a numeric measure, or no timezone on a timestamp.
- A contract edited without a version bump.
- An enum in a contract with no corresponding accepted-values assertion.
- A source not under your control with no scheduled schema diff.
- A deprecation with no expiry date.
- A `SELECT *` in any model reading a contracted source — it makes every additive change breaking for that model.

## Related

- `ai/patterns/data-quality-tests.md` — the assertions that enforce a contract continuously.
- `ai/patterns/transformation-layers.md` — staging is where an additive change is absorbed.
- `contract-diff` — the executor that produces the classification.
- `lineage-trace` — the consumer enumeration that sets the notice period.
- `@data-quality-auditor`, `@analytics-engineer` — the review agents.
