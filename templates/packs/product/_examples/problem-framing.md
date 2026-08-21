---
name: problem-framing
kind: example
pack: product
---

# Pattern: Problem Framing

> **Hard rule:** The problem statement names no mechanism. Every claim is cited or labelled an assumption. The do-nothing baseline is a scored option. The success metric has a counter-metric. Kill criteria carry a date and a named owner, written before commitment.

**Halt conditions / mandatory cites**
- The statement, after questioning twice, is still a solution.
- The target segment is "everyone".
- Success cannot be measured by anything the system emits or could emit — name the instrumentation gap.
- No evidence source is reachable at all — produce an assumption ledger instead of a brief, and say so.
- Any claim about users presented without a citation or an assumption label is a hand-wave — reject it.

## The mechanism test

Does any noun in the statement name a feature?

> "We need an integrations marketplace" → the discussion becomes marketplace design; nobody establishes which integration, for whom, or whether building the top two directly resolves most of the demand.

> "Finance-role users cannot get order data into their accounting system without a weekly two-hour manual export that introduces transcription errors" → the marketplace is now one option, and it can lose.

## The five slots

who (a named segment, not "users") · when (the trigger situation) · trying to (the outcome, in their words) · blocked by (the specific obstacle) · costing them (in their terms).

## Evidence classes and limits

| Class | Supports | Does NOT support |
|---|---|---|
| observed behaviour | that it happens, how often | why |
| support / sales records | frequency, severity, who | prevalence among non-complainers |
| direct research | the mechanism, the workaround | how many |
| stated preference | direction of interest | what people will do |
| internal opinion | a hypothesis | anything |

Never invent. "No direct evidence; assumption ranked 1" is a better brief than a confident one.

## Do-nothing is a scored row

Name today's alternative precisely — a competitor, a spreadsheet, a manual process — and state the switching cost: what must be true for someone to move off it. Switching costs are why well-built features go unused.

## The metric pair

Success (an outcome, with baseline, target, window, instrumentation status) and counter-metric (the number that reveals damage, with a rollback threshold). Conversion up / refund rate up. Engagement up / retention down. Speed up / accuracy down.

## Kill criteria

A condition, a date, a named owner — before commitment. A project with no stated failure condition can only be quietly extended.

## Detectors

- A problem statement containing a feature name.
- Internal opinion in the same voice as data.
- A market size with no derivation.
- A success metric that counts activity.
- No counter-metric.
- Kill criteria with no date, or a review date passed unnoticed.
- A brief dated after the work started.

## Related

- `ai/patterns/opportunity-sizing.md`, `ai/patterns/research-synthesis.md`, `ai/patterns/acceptance-criteria.md`
- `@product-strategist`, `assumption-ledger`, `/frame-problem`
