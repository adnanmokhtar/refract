---
name: product-principles
description: Product Principles
kind: rule
pack: product
severity: must
applies-to: product-track, every-brief-requirement-or-success-definition-written
---

# Product Principles

> **Hard rule.** Every claim about users is cited or labelled an assumption — there is no third category, and nothing is ever invented. Every acceptance criterion names the observation that would prove it failed. Every change to a behavioural surface has a success metric AND a counter-metric, both instrumented before launch. Every commitment has kill criteria, a date, and a named owner.

Prevents the most expensive failure in software — building the wrong thing correctly — and the one that enables it: confident prose with nothing underneath, which everyone downstream treats as fact.

## Must

- **State the problem before the solution**, with the mechanism removed. Who has it, when it occurs, what they are trying to accomplish, what blocks them, what it costs them — in their vocabulary, not the product's. If any noun in the problem statement names a feature, it is not a problem statement.
- **Label every claim** as evidence-backed (cited to a source with a locator, a count, and a date) or as an assumption (with the cheapest test that would confirm it). Unlabelled claims are read as fact by everyone downstream.
- **Name the evidence class and its limits.** Observed behaviour supports *that*; direct research supports *why*; stated preference supports direction of interest only. State what each finding does NOT support.
- **Count with a denominator.** "5 of 8 participants", "31 of 214 tickets in the period". Never a percentage on an unknown or tiny denominator.
- **Score the do-nothing baseline** as an option, and name what users do today instead — a competitor, a spreadsheet, a manual process, nothing.
- **Make every acceptance criterion falsifiable**: name the observation that would prove it FAILED. Numeric criteria carry a unit, a percentile where they are a distribution, a measurement point, and a load condition.
- **Specify the states nobody specifies**: empty, partial, each named error, boundary, concurrent, permission-denied, migration of existing records, and reversal. Each is specified or explicitly out of scope.
- **Pair every success metric with a counter-metric** and a pre-committed rollback threshold. Every optimisation has a number that would reveal it doing damage.
- **Instrument both metrics before launch.** A metric that cannot be measured at launch will not be measured after launch.
- **Set kill criteria with a date and a named decision owner** before commitment.
- **Give every deferral a revisit trigger.** A "won't" with no trigger is a quiet deletion that will reappear as a surprise.
- **State the consequence of omission for every must-have**, naming what specifically fails. Without it, it is a preference in formal clothing.

## Must not

- Invent a quote, a participant, a persona, a percentage, or a research finding. "No direct evidence" is the correct output when there is none.
- Upgrade an evidence class — a survey never becomes proof that people will act.
- Present internal opinion in the same voice as data.
- Write an acceptance criterion that can only be verified by asking its author.
- Use "fast", "intuitive", "robust", "properly", "correctly", "as expected", or "gracefully" as the bound in a criterion.
- Ship a criterion that joins two independently-testable claims with "and" — it passes when half is met and the argument is unresolvable.
- Smuggle a mechanism into a requirement where an outcome belongs, unless the mechanism is genuinely constrained — and then say by what.
- Declare success with a metric chosen after the result was known.
- Use an activity count (screens viewed, features used) as the outcome. Where a proxy is used, say it is a proxy and say what it proxies for.
- Ship a change that creates, shares, or connects something without its reversal, or without an explicitly communicated gap.
- Classify everything as must-have. That is not a classification.
- Rewrite a requirement in place during a review — the author never sees the defect rate and writes the next one the same way.
- Produce a brief to justify a decision already made. Say that is what is happening.
- Target a change smaller than the metric's natural variance and call it measurable.

## Should

- Rank assumptions by impact × uncertainty and attach the **cheapest** test to each, not the most rigorous. The `fatal × high` rows are what to find out before committing.
- Give every assumption an expiry date. One carried past its expiry without a decision has quietly become a fact.
- Report disconfirming material in every synthesis, or state explicitly that none was found.
- Separate observed from said from interpreted at every finding.
- State the smallest change distinguishable from noise at current volume before setting a target.
- Present scope with its "won't" half — it is the half that prevents the argument recurring.
- Reuse an existing metric definition rather than creating a second one; two definitions produce two answers and a dispute.
- Check the reversal set at scope time, where it is cheapest, rather than at launch, where it is most expensive.

## Enforcement

- `@requirements-reviewer` reviews prose with the severity a code reviewer applies to a diff, and BLOCKs on unfalsifiable primary criteria, missing reversal on destructive actions, and missing counter-metrics.
- `acceptance-criteria-check` applies the falsifiability test mechanically, one row per criterion, no sampling.
- `evidence-trace` reports the unsourced set by name before estimation, while cutting is still cheap.
- `launch-readiness` gates on whether the launch can be judged: metrics queried live, rollback exercised, decision rule pre-committed with an owner and a calendar entry.
- These gates are **agent-enforced** — no external validator checks requirement prose, and none is planned. The discipline holds because the ledgers are enumerative and their inputs are inspectable.
