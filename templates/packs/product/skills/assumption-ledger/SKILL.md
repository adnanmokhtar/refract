---
name: assumption-ledger
description: Extract the implicit assumptions from a brief, spec, or plan, rank them by impact × uncertainty, and attach the cheapest test that would move each one. Run after framing a problem, when a plan depends on beliefs nobody has stated, before committing to work larger than a sprint, and when a project keeps being extended without a decision. Makes the BETS visible and testable — `evidence-trace` finds which requirements have no source, and this skill turns those into ranked, testable claims.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# Skill: assumption-ledger

## Premise

Every plan rests on beliefs. The dangerous ones are not the beliefs that are wrong; they are the beliefs nobody noticed they were holding, because those are the ones that go untested for the whole project and are discovered at launch.

An assumption is not a defect. An *unexamined* one is. The output of this skill is a ranked list where the top rows are the cheapest things to find out this week, which is usually the most actionable artifact attached to any brief.

## Halt conditions

- **No plan, brief, or spec to read** — assumptions are extracted from a stated intention, not from a topic.
- **The plan is entirely evidence-backed and says so** — verify with `evidence-trace` before concluding this; it is rare, and usually means the assumptions are implicit rather than absent.
- **Ranking requested with no impact context** — impact means "impact on what". Without a stated success metric or objective, the ranking is arbitrary; get it or report the ledger unranked and say why.

## When to run

- Immediately after `/frame-problem`, as the brief's closing section.
- Before committing to work larger than a sprint.
- When a plan depends on beliefs about users, demand, capability, or timing that nobody has stated aloud.
- When a project keeps being extended — an unexamined assumption is usually why the finish line moves.
- After `evidence-trace` reports an unsourced set.

## Procedure

### 1. Extract, by category

Assumptions hide in confident sentences. Read the plan for each category and write what must be true for the sentence to hold:

| Category | The belief | Typical wording that hides it |
|---|---|---|
| **desirability** | someone wants this enough to change behaviour | "users will finally be able to…" |
| **prevalence** | enough people have this problem | "customers keep asking for…" |
| **willingness** | they will pay, switch, or migrate | "this unblocks the enterprise segment" |
| **feasibility** | it can be built at this cost, in this time | "straightforward once the schema is in place" |
| **viability** | the economics work | "at scale the cost per user is negligible" |
| **dependency** | something outside our control will hold | "the vendor's API supports this" |
| **timing** | the window is open, and staying open | "we need this before the competitor ships" |
| **capability** | the team can do this well | "we've done something similar" |
| **adoption path** | people will discover and reach it | "it'll be in the main navigation" |

The wording column is the practical part: these phrases are where an assumption is most often disguised as a fact.

### 2. State each as a falsifiable claim

Rewrite as something that could be shown false: *"at least 30% of accounts on the mid-tier plan perform this workflow monthly"* rather than *"lots of customers need this"*. An assumption that cannot be false cannot be tested, and it will be argued about instead.

### 3. Score impact and uncertainty

- **Impact** — if this is false, what happens? `fatal` (the plan does not work) / `major` (significant rework or a much smaller outcome) / `minor` (an adjustment).
- **Uncertainty** — how confident are we, and on what basis? `high` (nobody has checked) / `medium` (indirect or dated evidence) / `low` (direct current evidence, though it remains an assumption about the future).

Rank by impact × uncertainty. The `fatal` × `high` rows are the whole point of the ledger: they are what to find out before committing, and there are usually only two or three.

### 4. Attach the cheapest test

For each row, the cheapest thing that would meaningfully move the uncertainty — not the most rigorous. Rough ascending cost:

- Query existing data (often minutes; frequently sufficient for prevalence)
- Read existing tickets or call notes
- Ask five customers
- A concierge or manual version of the capability
- A landing page or interest-to-action measurement
- A prototype
- A limited build behind a flag

State the test, its cost, and **what result would change the decision**. A test whose outcome would not alter anything is not worth running, and saying so out loud saves more time than the test would have.

### 5. Set expiry

Each row gets a date by which it must be tested or accepted. An assumption carried past its expiry without a decision has quietly become a fact, which is exactly the failure this ledger exists to prevent.

### 6. Report

```
## assumption-ledger — <plan / brief> — <date>

Objective the impact is measured against: <success metric or goal>

| # | Assumption (falsifiable) | Category | Impact | Uncertainty | Rank | Cheapest test | Cost | Would change | Expiry | Owner |
|---|--------------------------|----------|--------|-------------|------|---------------|------|--------------|--------|-------|

Top rows (fatal × high): <n> — these block commitment
Tests runnable this week: <n>
Assumptions past expiry from prior ledgers: <n> (named)

Recommendation: <test before committing | commit and monitor | do not commit>
```

## Inputs

- The brief, spec, or plan.
- The declared success metric or objective, for the impact axis.
- `evidence-trace` output, where an unsourced set already exists.
- Prior ledgers in `ai/product/assumptions.md`, to carry forward unexpired rows.

## Outputs

- The ledger, appended to `ai/product/assumptions.md` and included as the closing section of the brief.
- The `fatal × high` rows, which `@product-strategist` treats as blocking commitment.
- The runnable-this-week set, which is the immediate research plan.

## False positives / gotchas

- **Listing everything.** A forty-row ledger is a document; a six-row ledger is a plan. Merge the minor rows or drop them.
- **Assumptions stated so they cannot be false** ("users value convenience"). Rewrite as a claim with a threshold.
- **Choosing the most rigorous test rather than the cheapest.** The goal is to move uncertainty, not to publish.
- **A test whose result would not change the decision.** Note it and skip it; that observation is itself valuable.
- **Scoring impact against an unstated objective**, so the ranking reflects the scorer's preference.
- **Never revisiting.** A ledger with no expiry dates becomes a list of things everyone once worried about.
- **Confusing a dependency with an assumption.** "The vendor's API supports this" is checkable in an afternoon — that is a task, not an assumption. Move it.

## Related

### Skills
- `evidence-trace` — supplies the unsourced set this skill ranks.
- `acceptance-criteria-check` — an assumption inside an acceptance criterion is a different defect; that skill catches it.
- `launch-readiness` — checks whether the fatal assumptions were ever tested.

### Agents
- `@product-strategist` — the brief closes with this ledger.
- `@scope-arbiter` — items flagged NO-EVIDENCE arrive here.
- `@user-research-synthesizer` — runs the tests this ledger names.

### Commands
- `/frame-problem` — dispatches this skill.
- `/audit-requirements` — converts UNSOURCED findings into rows here.

### Patterns
- `ai/patterns/problem-framing.md`, `ai/patterns/opportunity-sizing.md`
