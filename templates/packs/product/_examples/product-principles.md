---
name: product-principles
description: Product Principles
kind: example
pack: product
---

# Product Principles

> **Hard rule.** Every claim about users is cited or labelled an assumption — there is no third category, and nothing is invented. Every acceptance criterion names the observation that would prove it failed. Every change to a behavioural surface has a success metric AND a counter-metric, both instrumented before launch. Every commitment has kill criteria, a date, and a named owner.

## Must

- State the problem before the solution, with the mechanism removed. If any noun in it names a feature, it is not a problem statement.
- Label every claim as evidence-backed (with a locator, a count, and a date) or as an assumption (with its cheapest test).
- Name the evidence class and its limits; state what each finding does NOT support.
- Count with a denominator. Never a percentage on an unknown or tiny one.
- Score the do-nothing baseline and name what users do today instead.
- Make every acceptance criterion falsifiable; numeric criteria carry unit, percentile, measurement point, and load condition.
- Specify empty, partial, each named error, boundary, concurrent, permission, migration, and reversal — or state each as out of scope.
- Pair every success metric with a counter-metric and a pre-committed rollback threshold.
- Instrument both metrics before launch.
- Set kill criteria with a date and a named decision owner before commitment.
- Give every deferral a revisit trigger, and every must-have a stated consequence of omission.

## Must not

- Invent a quote, participant, persona, percentage, or finding.
- Upgrade an evidence class, or present internal opinion in the same voice as data.
- Write a criterion verifiable only by asking its author.
- Use "fast", "intuitive", "robust", "properly", "as expected", or "gracefully" as a bound.
- Join two independently-testable claims with "and" in one criterion.
- Smuggle a mechanism into a requirement where an outcome belongs.
- Declare success with a metric chosen after the result was known, or use an activity count as the outcome.
- Ship something that creates, shares, or connects without its reversal or a stated gap.
- Classify everything as must-have, or rewrite a requirement in place during a review.
- Produce a brief to justify a decision already made.
- Target a change smaller than the metric's natural variance and call it measurable.

## Should

- Rank assumptions by impact × uncertainty with the **cheapest** test attached, and give each an expiry.
- Report disconfirming material in every synthesis, or state explicitly that none was found.
- Separate observed from said from interpreted at every finding.
- State the smallest distinguishable change before setting a target.
- Present scope with its "won't" half.
- Reuse an existing metric definition rather than creating a second one.

## Review checklist

- [ ] The problem statement names no mechanism.
- [ ] Every claim cited or labelled; every count has a denominator; every quote has a locator.
- [ ] Every criterion has a named refuting observation.
- [ ] Numeric criteria carry unit, percentile, measurement point, load condition.
- [ ] No coverage cell unspecified that is not explicitly out of scope.
- [ ] Success and counter-metric named and instrumented.
- [ ] Rollback threshold set before the result was known.
- [ ] Kill criteria carry a date and a named owner.
- [ ] Anything created or shared has its reversal in scope, or a stated gap.

## Enforcement

- `@requirements-reviewer` reviews prose with the severity a code reviewer applies to a diff, and BLOCKs on unfalsifiable primary criteria, missing reversal on destructive actions, and missing counter-metrics.
- `acceptance-criteria-check` applies the falsifiability test mechanically, one row per criterion, no sampling.
- These gates are **agent-enforced** — no external validator checks requirement prose, and none is planned. The discipline holds because the ledgers are enumerative and their inputs are inspectable.
