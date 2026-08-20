---
name: commitment-coverage
description: Analyse committed-spend and reserved-capacity posture — coverage (what share of eligible usage is discounted), utilisation (what share of what was bought is used), expiry exposure, and a buy/hold/let-lapse recommendation with break-even arithmetic. Run before a commitment purchase or renewal, quarterly, and after any material capacity change. Owns the RATE half of spend — `unit-cost-probe` owns the per-unit number and `egress-trace` owns transfer, neither of which commitments affect.
---

# Skill: commitment-coverage

## Premise

Commitments are the one cost lever that changes the bill without changing the architecture — and the one most often bought on intuition. Two numbers decide everything, and they pull in opposite directions: **coverage** (how much eligible usage receives a discount) and **utilisation** (how much of what was bought is actually consumed). Maximising either alone is a mistake; 100% coverage means over-buying, and 100% utilisation usually means under-buying.

Every figure comes from the provider's own coverage and utilisation reporting plus the cost/usage export. No modelled assumptions about future usage without labelling them.

## Halt conditions

- **Baseline usage undetermined** — a commitment is a bet on a floor. Without at least a full seasonal cycle of usage history, the floor is a guess; say so rather than recommending a term.
- **Planned architectural change undisclosed** — a migration, a re-platform, or a major shape change inside the commitment term invalidates the arithmetic. Ask before recommending.
- **Term and payment options unknown** for the provider and account in question.
- **Existing commitment inventory unavailable** — you cannot recommend a purchase without knowing what is already owned and when it expires.
- **Flat-rate capacity environment** — commitments may not apply at all. Confirm the model first.

## When to run

- Before any commitment purchase or renewal.
- Quarterly, as a standing review.
- Before a capacity change large enough to move the baseline.
- When an expiry is inside the next two months — an expiring commitment is a scheduled bill increase that surprises people every time.
- When `@finops-analyst` classifies a spend delta as a **rate** change.

## Procedure

### 1. Inventory what is owned

Per commitment: type, scope (account / shared / service-specific), term, payment option, hourly or monthly value, start and expiry, and current utilisation. Sort by expiry.

### 2. Measure coverage

```
coverage = eligible usage covered by a commitment / total eligible usage
```

Compute per service and per commitment scope, not just in aggregate — aggregate coverage hides a fully-covered service subsidising an uncovered one.

Note explicitly what is *not eligible*: usage types that no commitment covers. Chasing coverage on ineligible usage is a common and expensive misunderstanding.

### 3. Measure utilisation

```
utilisation = commitment value consumed / commitment value purchased
```

Under-utilisation is money already spent for nothing. Report per commitment, with the wasted amount per period in currency, not just a percentage.

### 4. Find the floor

The purchase decision rests on the **sustained minimum** — usage that is present in essentially every hour of the trailing period, not the average. Compute a low percentile of hourly usage over a full seasonal cycle, and commit at or below it. Committing at the average guarantees under-utilisation during troughs.

State the floor, the percentile used, and the window. Then state how much of the floor is *durable*: usage attached to a workload with a known end date, or a system scheduled for migration, is not a floor.

### 5. Break-even

For each recommendation, compute the break-even point: at the discount rate offered, what fraction of the term must the usage persist for the commitment to beat on-demand? Compare that against the confidence in the workload's lifetime.

A commitment is a bet. State the bet: *"this saves X if usage stays above Y for Z months; it loses if the workload is retired before month N."*

### 6. Recommend

One of: **buy** (with type, scope, term, payment option, and quantity), **hold** (coverage adequate; state the number), **partial** (cover the durable floor only), or **let lapse** (with the resulting bill increase stated, so it is a decision rather than a surprise).

Prefer flexible instruments over rigid ones where the discount difference is small — the option to change shape is worth real money in a system that is still evolving, and that value should be named rather than assumed away.

### 7. Report

```
## commitment-coverage — <account/scope> — <date>

### Inventory (by expiry)
| Commitment | Type | Scope | Term | Value/hr | Expiry | Utilisation | Wasted/period |

### Coverage
| Service | Eligible usage | Covered | Coverage % | Ineligible usage (no commitment applies) |

Aggregate coverage: <%>   Aggregate utilisation: <%>

### Floor
Sustained minimum: <value> (p<n> of hourly usage over <window>)
Durable share:     <value> (excluding <named workload> — <reason>)

### Recommendation
Action: buy | hold | partial | let lapse
  <type, scope, term, payment option, quantity>
Break-even: usage must persist <n> of <term> months
The bet:    saves <$> if <condition>; loses <$> if <condition>
Expiry exposure (next 90d): <$/month increase when <commitment> lapses>
```

## Inputs

- The provider's coverage and utilisation reporting.
- Hourly usage history over a full seasonal cycle.
- The current commitment inventory with expiry dates.
- Known upcoming architectural changes.

## Outputs

- The report block above.
- An expiry calendar for `/cost-guardrails` — every expiry becomes a scheduled notification with an owner, so a lapse is a decision rather than an invoice surprise.
- The rate-change explanation for `@finops-analyst`'s delta analysis.

## False positives / gotchas

- **Optimising coverage alone.** 100% coverage with 60% utilisation is worse than 70% coverage with 95% utilisation.
- **Committing at the average.** The average is above the floor by construction; the trough hours are unutilised.
- **Ignoring the seasonal cycle.** A commitment sized on a peak quarter under-utilises for the other three.
- **Missing scope rules.** Commitments differ sharply in what they can float across (accounts, families, regions, sizes); a commitment bought at the wrong scope can strand.
- **Double-counting a discount** that a provider already applies automatically at the organisation level.
- **Recommending a long term for a workload with a shorter roadmap** — the break-even calculation exists to make that visible.
- **Reading utilisation as of today** on a commitment purchased last week; it has not had time to be representative.
- **Treating an expiry as a renewal.** It is a decision point, and the default outcome is a bill increase.

## Related

### Skills
- `unit-cost-probe` — a commitment changes the numerator, so unit costs shift for rate reasons; keep the two explanations separate.
- `spend-anomaly-triage` — a commitment expiry is a common cause of an apparent anomaly with no usage change.

### Agents
- `@finops-analyst` — supplies the usage history and classifies rate changes.
- `@cost-architect` — a design that is about to change shape invalidates a long commitment; run them together.

### Commands
- `/cost-guardrails` — receives the expiry calendar.
- `/cost-model` — commitment amortisation is what makes its branches honest.

### Patterns
- `ai/patterns/commitment-strategy.md`, `ai/patterns/unit-economics.md`
