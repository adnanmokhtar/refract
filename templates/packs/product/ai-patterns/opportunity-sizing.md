---
name: opportunity-sizing
description: 'Pattern: Opportunity Sizing (every input sourced or labelled, confidence driven by the weakest input, ranges over point estimates)'
kind: ai-pattern
pack: product
---

# Pattern: Opportunity Sizing

> **Hard rule:** Every input to a sizing is a number with a source or an explicitly-labelled guess with a range. Confidence is set by the weakest input, not the average. A sizing whose inputs are mostly guesses is a guess with arithmetic on top and must say so on its confidence line, not in a footnote. Point estimates are avoided where inputs are guessed; state a range.

**When to apply**
- Comparing options in a problem brief, including do-nothing.
- Deciding whether something is worth a sprint or a quarter.
- A request is being escalated on the basis of an unstated size.
- Prioritising a backlog where everything currently looks equally important.

**When NOT to apply**
- Obligations — regulatory, contractual, security. Sizing an obligation is theatre; the decision is scope and approach.
- Items whose cost is smaller than the sizing effort. Just do it.
- As a ranking mechanism that replaces judgment. A sizing informs an argument; it does not settle one.

**Halt conditions / mandatory cites**
- The population cannot be counted or estimated from anything — say so and size nothing.
- The effect size is pure invention with no comparable — label it a guess with a wide range, or drop the sizing entirely.
- The success metric is undeclared — there is nothing for the sizing to be denominated in.
- Any input presented without a source or a guess label is a hand-wave — reject it.

## The shape

A sizing is a chain of multiplications, and a chain is only as sound as its weakest link:

```
opportunity = reach × affected share × effect size × value per unit
```

| Input | Where it comes from | How it goes wrong |
|---|---|---|
| **reach** | a countable population — accounts, users, sessions in a window | using the total addressable market instead of who will actually encounter this |
| **affected share** | prevalence from research or from a metric, with its denominator | promoting a small-sample research prevalence to a population rate |
| **effect size** | a comparable prior change, a benchmark, or an explicit guess | the most-invented input, and usually the one that dominates the answer |
| **value per unit** | revenue, retained revenue, cost avoided, time saved × a rate | counting the same value twice across two initiatives |

## Label every input

Three labels, exactly as in unit economics:

- **measured** — a query, a count, a metric, with the source
- **derived** — computed from measured inputs, with the derivation shown
- **guess** — explicitly labelled, with a range, and a note on what would narrow it

An unlabelled input turns the whole chain into a number that looks computed. That number then gets quoted, and its provenance is unrecoverable within a week.

## Confidence is the weakest link

Confidence is not an average of the inputs' confidence — it is set by the weakest input that materially moves the answer. One guessed effect size in an otherwise measured chain makes the sizing a guess, and the confidence line must name which input drives it:

> *"Confidence: low — effect size is a guess (range 2–15%), and it drives the answer. Reach and value per unit are measured."*

That sentence is more useful than the number above it, because it says what to go and measure.

## Ranges, not points

Where an input is guessed, carry the range through the arithmetic and present a range. A point estimate derived from a guess communicates a precision that does not exist, and precision is what makes people stop asking questions.

Where a range spans a decision boundary — profitable at the top end, not at the bottom — that is the finding. Say it plainly: the sizing does not settle the decision, and here is the cheapest thing that would narrow the range.

## Do-nothing is a row

Every sizing table includes doing nothing, with its consequence attached. An options table without it compares alternatives against an unstated baseline, which flatters all of them.

## Beware double-counting

Two initiatives that both claim the same retained revenue produce a portfolio that sums to more value than exists. When sizing more than one thing against the same population, state the overlap.

## Detectors

- A market size with no derivation.
- Reach set to the total addressable population rather than to who will encounter the change.
- An effect size with no comparable and no guess label.
- A point estimate where an input was guessed.
- A confidence line that averages rather than naming the weakest input.
- No do-nothing row.
- Two initiatives claiming the same value.
- A sizing produced after the decision, matching it closely.
- Research prevalence from a small sample applied directly as a population rate.

## Related

- `ai/patterns/problem-framing.md` — the options table this feeds.
- `ai/patterns/research-synthesis.md` — supplies prevalence with its denominator and its limits.
- `ai/patterns/unit-economics.md` (finops pack) — the same three-label discipline applied to cost; use it for the cost side of any option.
- `@product-strategist`, `@scope-arbiter` — the agents that consume sizings.
- `assumption-ledger` — every guessed input is an assumption with a test.
