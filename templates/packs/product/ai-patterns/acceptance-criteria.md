---
name: acceptance-criteria
description: 'Pattern: Acceptance Criteria (falsifiability, the coverage grid, non-functional bounds, one criterion per claim)'
kind: ai-pattern
pack: product
---

# Pattern: Acceptance Criteria

> **Hard rule:** Every criterion names the observation that would prove it FAILED. Every numeric criterion carries a unit, a percentile where it is a distribution, a measurement point, and a load condition. Every requirement is checked against the coverage grid — empty, partial, error, boundary, concurrent, permission, migration, reversal — and each cell is specified or explicitly out of scope.

**When to apply**
- Writing or reviewing acceptance criteria for anything that will be estimated or built.
- "Done" was disputed after delivery.
- A ticket keeps bouncing back between build and review.
- Inheriting a backlog whose requirement quality is unknown.

**When NOT to apply**
- Exploratory or spike work whose output is a decision rather than a behaviour. State the question and the time-box instead.
- A defect with an obvious correct behaviour — the criterion is "it does the documented thing".

**Halt conditions / mandatory cites**
- The actor is unstated across the criteria set — "the system shall" hides who, and the answer changes what is tested.
- Existing behaviour undocumented for a change to an existing surface.
- A criterion references an external standard that is unreachable — record `DEFERRED`, never `passing`.
- Any criterion whose verification requires asking its author is a hand-wave — reject it.

## The falsifiability test

For each criterion: **name the observation that would prove it FAILED.**

If no observation could refute it, it cannot be verified, and the disagreement about "done" has been scheduled for after delivery instead of now. The test is mechanical — it gives the same answer for every reviewer, which is why it works where "is this clear enough?" does not.

## The four tests

| Test | Question | Fails when |
|---|---|---|
| falsifiable | what would prove this failed? | nothing could refute it |
| observable | checkable without asking the author? | verification needs the author's intent |
| bounded | are numbers, volumes, conditions stated? | an adjective stands where a bound belongs |
| singular | is this one criterion? | "and" joins independently-testable claims |

The singular test earns its place: a compound criterion passes when half is met, and the resulting argument is unresolvable because both parties are right about their half.

## Failure classes and their replacements

| Class | Disguise | Replacement |
|---|---|---|
| unbounded adjective | fast, responsive, intuitive, easy, robust | a number, a percentile, a measurement point, a load condition |
| deferred standard | properly, correctly, appropriately, as expected | name the standard, or state the behaviour |
| capability not behaviour | "should be able to" | the observable outcome |
| blanket error clause | "handles errors gracefully" | one criterion per named failure, each with its outcome |
| compound | two claims joined by "and" | split |
| intent-dependent | "the user understands that…" | an observable proxy, or move it out of acceptance criteria |
| circular | "works as expected" | state the expectation |

## A number is not automatically a bound

A latency criterion missing its percentile and its measurement point is unbounded despite containing a number — and this is the most common way an unverifiable criterion passes review. Every numeric criterion needs:

- **unit** — seconds, milliseconds, business days
- **percentile** — p50 and p99 are different products
- **measurement point** — server-side, client-side, end-to-end, cold or warm
- **load condition** — at what concurrency, at what data volume

## The coverage grid

Every requirement is checked against all eight cells. Each is specified, explicitly out of scope, or a finding:

| Cell | The question nobody asks |
|---|---|
| **empty** | no data yet, first run, a list with zero items |
| **partial** | some data missing, an optional relationship absent |
| **error** | each named failure mode, with its observable outcome — not one blanket criterion |
| **boundary** | first, last, maximum, minimum, exactly at the limit |
| **concurrent** | two actors on the same object; what wins |
| **permission** | the actor who is not allowed; what they see |
| **migration** | records created before this change; what happens to them |
| **reversal** | undo, cancel, delete, revoke, refund |

The reversal cell is the one most often empty under deadline pressure, and the most expensive to fill later — by then the data model has assumed permanence.

## Non-functional bounds

Any requirement touching a list, a search, an import, an export, a report, or a background job needs: expected volume, maximum volume, latency with a percentile and a measurement point, and **the behaviour above the maximum** (queue and notify, refuse with a message, paginate). Absent bounds are how a feature works in demo and fails on the largest customer.

## Traceability and metric linkage

Every requirement is evidence-backed (cited), a labelled assumption (with its test), or in a stated justification class (regulatory, security, technical prerequisite). And it names the metric it moves — or, honestly, that it moves none, which is legitimate for infrastructural work and is a finding for a feature.

## Detectors

- Criteria written after the implementation, restating what was built.
- A criterion verifiable only by asking its author.
- "Just" ("just show the latest") — almost always hiding a rule about which one.
- Fifteen happy-path criteria and one line for errors.
- A number with no unit, percentile, or measurement point.
- "Same as X" where X is itself unspecified.
- Scope stated only as inclusions.
- A criterion embedded in prose ("it should also…") rather than in the criteria list.

## Related

- `ai/patterns/problem-framing.md` — the brief these criteria descend from.
- `@requirements-reviewer` — the agent that enforces this pattern.
- `acceptance-criteria-check` — the mechanical executor.
- `/audit-requirements` — the command.
- `missing-counterparts` (business pack) — the forward/inverse cycle behind the reversal cell.
