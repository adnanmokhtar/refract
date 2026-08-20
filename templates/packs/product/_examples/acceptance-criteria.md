---
name: acceptance-criteria
kind: example
pack: product
---

# Pattern: Acceptance Criteria

> **Hard rule:** Every criterion names the observation that would prove it FAILED. Every numeric criterion carries a unit, a percentile where it is a distribution, a measurement point, and a load condition. Every requirement is checked against the eight-cell coverage grid.

## The falsifiability test

Name the observation that would prove this criterion FAILED. If none exists, it cannot be verified and the argument about "done" has been scheduled for after delivery. The test is mechanical, which is why it works where "is this clear enough?" does not.

## The four tests

falsifiable (what would refute it) · observable (checkable without asking the author) · bounded (numbers, volumes, conditions stated) · singular (one claim, not two joined by "and").

A compound criterion passes when half is met, and the resulting argument is unresolvable because both parties are right about their half.

## Failure classes

| Class | Disguise | Replacement |
|---|---|---|
| unbounded adjective | fast, intuitive, robust | a number, a percentile, a measurement point, a load condition |
| deferred standard | properly, correctly, as expected | name the standard, or state the behaviour |
| capability not behaviour | "should be able to" | the observable outcome |
| blanket error clause | "handles errors gracefully" | one criterion per named failure |
| compound | joined by "and" | split |
| intent-dependent | "the user understands" | an observable proxy |
| circular | "works as expected" | state the expectation |

## A number is not a bound

A latency criterion missing its percentile and measurement point is unbounded despite containing a number — the most common way an unverifiable criterion passes review. Every numeric criterion needs unit, percentile, measurement point, and load condition.

## The coverage grid

empty · partial · each named error · boundary · concurrent · permission · migration · reversal.

Each cell is specified or explicitly out of scope. The reversal cell is the one most often empty under deadline pressure and the most expensive to fill later — by then the data model has assumed permanence.

## Non-functional bounds

Anything touching a list, search, import, export, report, or background job needs expected volume, maximum volume, latency with a percentile and a measurement point, and the behaviour above the maximum.

## Detectors

- Criteria written after the implementation, restating what was built.
- A criterion verifiable only by asking its author.
- "Just" — almost always hiding a rule about which one.
- Fifteen happy-path criteria and one line for errors.
- "Same as X" where X is itself unspecified.
- A criterion embedded in prose rather than in the criteria list.

## Related

- `ai/patterns/problem-framing.md`
- `@requirements-reviewer`, `acceptance-criteria-check`, `/audit-requirements`
- `missing-counterparts` (business pack) — the cycle behind the reversal cell.
