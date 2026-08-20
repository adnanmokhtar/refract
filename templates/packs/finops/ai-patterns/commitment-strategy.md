---
name: commitment-strategy
description: 'Pattern: Commitment Strategy (coverage vs utilisation, the sustained floor, break-even, expiry as a decision)'
kind: ai-pattern
pack: finops
---

# Pattern: Commitment Strategy

> **Hard rule:** Commit at or below the *sustained floor* of usage, never at the average. Coverage and utilisation are reported together — optimising either alone is a mistake. Every purchase states its break-even and the bet it represents. Every expiry is a scheduled decision with an owner, because the default outcome of an expiry is a bill increase.

**When to apply**
- Before a commitment purchase or renewal.
- Quarterly, as a standing review.
- When an expiry falls inside the next two months.
- When a spend change is classified as a **rate** change.

**When NOT to apply**
- Workloads with less than a full seasonal cycle of history — the floor is a guess, and a guess committed for a year is expensive.
- Systems with a known re-platform or migration inside the candidate term.
- Flat-rate capacity environments where commitments may not apply at all.

**Halt conditions / mandatory cites**
- Baseline usage undetermined (no full seasonal cycle).
- A planned architectural change inside the term, undisclosed.
- Existing commitment inventory unknown — you cannot recommend a purchase without knowing what is owned and when it expires.
- Any recommendation without a break-even figure is a hand-wave — reject it.

## The two numbers, which pull in opposite directions

**Coverage** — the share of eligible usage that receives a discount. Raising it means buying more.
**Utilisation** — the share of what was purchased that is actually consumed. Raising it means buying less.

100% coverage means over-buying. 100% utilisation usually means under-buying. The target is high on both, and reporting either alone produces the wrong decision:

> 100% coverage at 60% utilisation is worse than 70% coverage at 95% utilisation.

Report them together, always, per scope — aggregate coverage hides a fully-covered service subsidising an uncovered one.

Also report what is **not eligible**: usage types no commitment covers. Chasing coverage on ineligible usage is a common and expensive misunderstanding.

## The sustained floor, not the average

A commitment is a bet on a floor of usage. The relevant statistic is the **sustained minimum** — usage present in essentially every hour over a full seasonal cycle, expressed as a low percentile of hourly usage, not the mean.

Committing at the average guarantees under-utilisation during every trough, and troughs are where most systems spend their nights and weekends.

Then subtract the **non-durable** part of the floor: usage attached to a workload with a known end date, or a system scheduled for migration, is not a floor. What remains is the safe commitment quantity.

## Break-even, stated as a bet

Every recommendation states, in one sentence:

> *This saves `<$>` if usage stays above `<level>` for `<n>` of `<term>` months; it loses `<$>` if `<named workload>` is retired before month `<n>`.*

That sentence is the deliverable. A discount percentage is not a decision; a bet with a stated downside is.

Compute the break-even explicitly: at the offered discount, what fraction of the term must the usage persist for the commitment to beat on-demand? Compare that fraction against the actual confidence in the workload's lifetime, and say which one you are relying on.

## Flexibility has a price and it is usually worth paying

Instruments differ in what they can float across — accounts, instance families, regions, sizes, services. Rigid instruments discount more; flexible ones survive a change of shape.

In a system that is still evolving, the option to change shape is worth real money, and it should be named rather than assumed away. A stranded commitment on a family you migrated off is a total loss; a slightly smaller discount that followed the migration is not.

## Payment options and term

Longer terms and larger upfront payments discount more and commit harder. The choice is a function of confidence, not of the discount table:
- High confidence in both the level and the shape → longer term, more upfront.
- Confident in the level, unsure of the shape → shorter term or a more flexible instrument.
- Unsure of the level → do not commit; fix the forecast first.

A large upfront payment also distorts monthly reporting unless amortised — always amortise, or every purchase month looks like an anomaly.

## Expiry is a decision, not a renewal

The most reliably surprising cost event is a commitment lapsing. Nothing changed architecturally, usage is flat, and the bill steps up. Treat every expiry as a scheduled decision:
- An expiry calendar with an owner per entry, in `/cost-guardrails`.
- A notification well before the date, with the resulting bill increase already computed.
- A re-run of the floor analysis before renewal, because the floor moved.

Auto-renewal without re-running the analysis renews last year's shape.

## Detectors

- Coverage reported without utilisation, or vice versa.
- A commitment purchased at or above average usage.
- A commitment whose utilisation has been below its threshold for a full period — money already spent for nothing, reported in currency and not just a percentage.
- An expiry inside 90 days with no owner and no computed bill impact.
- A long term purchased for a workload with a shorter roadmap.
- Unamortised upfront purchases in a cost report, producing phantom anomalies.
- A commitment scoped so narrowly it strands after a routine instance-family change.
- A "saving" computed against list price rather than against on-demand.

## Related

- `ai/patterns/unit-economics.md` — commitment amortisation is what makes its branches honest.
- `ai/patterns/cost-anomaly-detection.md` — an expiry is a classic rate-change anomaly with no usage cause.
- `commitment-coverage` — the executor.
- `@finops-analyst` — classifies rate changes and supplies the usage history.
- `@cost-architect` — a design about to change shape invalidates a long commitment.
