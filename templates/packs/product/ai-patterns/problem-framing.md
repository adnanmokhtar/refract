---
name: problem-framing
description: 'Pattern: Problem Framing (mechanism-free statement, labelled evidence, the do-nothing baseline, metric pair, kill criteria)'
kind: ai-pattern
pack: product
---

# Pattern: Problem Framing

> **Hard rule:** The problem statement names no mechanism. Every claim is cited or labelled an assumption — there is no third category and nothing is invented. The do-nothing baseline is a scored option. The success metric has a counter-metric. Kill criteria carry a date and a named owner, written before commitment.

**When to apply**
- A solution arrived with no problem attached.
- A feature request needs assessing before it enters a roadmap.
- "Why are we building this" has no one-sentence answer.
- Before committing to anything larger than a sprint.

**When NOT to apply**
- A defect with a known correct behaviour — the problem is already framed and framing it again is ceremony.
- A stated regulatory or contractual obligation. The obligation is the frame; what remains is scope and approach.
- Work already agreed and specified, where the brief would be retrofitted justification.

**Halt conditions / mandatory cites**
- The statement, after questioning twice, is still a solution.
- The target segment is "everyone".
- Success cannot be measured by anything the system emits or could emit — name the instrumentation gap.
- No evidence source is reachable at all — produce an assumption ledger instead of a brief, and say so.
- Any claim about users presented without a citation or an assumption label is a hand-wave — reject it.

## The mechanism test

A problem statement must survive one check: **does any noun in it name a feature?**

> "We need an integrations marketplace" → the discussion becomes marketplace design. Nobody establishes which integration, for whom, or whether building the top two directly resolves most of the demand at a fraction of the cost. The likely outcome is a platform with three listings.

> "Finance-role users cannot get order data into their accounting system without a weekly manual export, which takes about two hours and introduces transcription errors" → now the marketplace is one option among several, and it can lose.

The test is cheap and catches most bad briefs in one pass.

## The five slots

| Slot | Requirement | Failure |
|---|---|---|
| **who** | a named segment | "users" |
| **when** | the trigger situation | a permanent condition |
| **trying to** | the outcome, in their words | the product's vocabulary |
| **blocked by** | the specific obstacle | "it's hard" |
| **costing them** | in their terms | in the business's terms |

## Evidence classes, ranked, with limits

| Class | Supports | Does NOT support |
|---|---|---|
| observed behaviour (metrics, session data) | that it happens, how often | why |
| support and sales records | frequency, severity, who | prevalence among non-complainers |
| direct research (interviews, observation) | the mechanism, the workaround | how many |
| stated preference (surveys, votes) | direction of interest | what people will do |
| internal opinion | a hypothesis | anything |

Every source carries a count and a recency. Evidence from before a significant product change is a historical note.

**Never invent.** No fabricated quotes, no imagined personas, no invented numbers. "No direct evidence; assumption ranked 1" is a better brief than a confident one, because it says what to go and find out.

## The do-nothing baseline

The alternative always exists, even when it is "suffer and continue". Name it precisely — a competitor's product, a spreadsheet, a manual process, an internal tool — and state the **switching cost**: what must be true for someone to move off it. Switching costs are why well-built features go unused.

Score do-nothing as a row in the options table, with its consequence attached. A comparison against an unnamed alternative is not a comparison.

## The metric pair

- **Success metric** — one number, with its current value, its target, its window, and its instrumentation status. An outcome, not an activity count.
- **Counter-metric** — the number that reveals damage, with the threshold at which the change is rolled back.

Every optimisation has a counter-metric. Conversion up / refund rate up. Engagement up / retention down. Speed up / accuracy down. Activation up / support volume up. A brief with only the first number is asking for it at any price.

Both must be instrumented before launch. A metric that cannot be measured at launch will not be measured after launch.

## Kill criteria

What result, by when, means stop — written before commitment, with a named decision owner. A project with no stated failure condition cannot fail; it can only be quietly extended, and that is how roadmaps fill with work nobody would start today.

## The assumption ledger closes the brief

Everything not evidence-backed, ranked by impact × uncertainty, each with its cheapest test. This is usually the most actionable part: it says what to find out this week.

## Detectors

- A problem statement containing a feature name.
- Internal opinion in the same voice as data.
- "Users want X" with no observation of anyone doing anything.
- A market size with no derivation, or one assuming total reach.
- A success metric that counts activity rather than outcome.
- No counter-metric.
- A do-nothing row described as "we fall behind" with nothing attached.
- Competitor parity as the entire rationale.
- Kill criteria with no date, or a review date that has passed unnoticed.
- A brief dated after the work started.

## Related

- `ai/patterns/opportunity-sizing.md` — the arithmetic behind the options table.
- `ai/patterns/research-synthesis.md` — where the evidence comes from, at its real strength.
- `ai/patterns/acceptance-criteria.md` — what the agreed problem becomes downstream.
- `@product-strategist` — the agent that enforces this pattern.
- `assumption-ledger` — the closing section.
- `/frame-problem` — the command.
