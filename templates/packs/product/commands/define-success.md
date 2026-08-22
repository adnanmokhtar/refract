---
description: Define what success and damage look like before a change ships — the success metric with a baseline and a target, the counter-metric with a rollback threshold, the instrumentation each requires, and the kill criteria with a named owner and a review date.
kind: command
pack: product
---

# /define-success [<change or feature>]

Turn "we think this will help" into two numbers, a threshold, a date, and an owner — while there is still time to instrument them. A metric decided after launch is a metric that will be chosen to fit the result.

## When to use / NOT to use

- USE: before a change to a behavioural surface ships; when `@requirements-reviewer` blocks on a missing counter-metric; when a launch is imminent and nobody can say how it will be judged; when a previous launch was declared a success with no evidence either way.
- NOT: to choose which metrics a domain's dashboard should carry — that is `/suggest-metrics` in the business pack, which answers a broader question.
- NOT: to instrument telemetry — that is `/add-telemetry` in the observability pack; this command decides what to instrument and hands it over.
- NOT: to decide whether the change is worth making — that is `/frame-problem`.

## Phases applied

1-3 + 4 + 5 + 6 + 7 (the handoff to the pre-launch gate).

## The Premise (read this first, internalize, do not deviate)

**Every optimisation has a counter-metric.** Conversion up / refund rate up. Engagement up / retention down. Speed up / accuracy down. Activation up / support volume up. A change with a success metric and no counter-metric optimises one number at the expense of an unwatched one, and it will be declared a success.

**A metric that cannot be measured at launch will not be measured after launch.** Instrumentation status is part of the definition, not a follow-up. If the metric needs new events, that work lands before the change or the change ships unjudgeable.

**Outcome, not activity.** Screens viewed, features used, and clicks are activity. They move when you make something more prominent, which is not the same as making something better. State the outcome the activity is a proxy for, and say it is a proxy.

**A threshold is a pre-commitment.** The rollback threshold is set before the result is known, because a threshold chosen afterwards is chosen to justify. Write it down and name who enforces it.

**Escalation triggers (halt and ask):**
- No baseline exists for the proposed metric, and none can be computed — a target with no baseline is a wish.
- The metric cannot be measured by anything the system emits or could emit — name the instrumentation gap and stop.
- The change is expected to move a metric that another team owns — that is a negotiation, not a definition.
- The proposed success metric is a launch date. Shipping is not an outcome.

## Phase 1 — Understand

Confirm:
- **The change** and the behaviour it is expected to alter.
- **The brief** — `/frame-problem`'s success metric, if one exists. This command refines and instruments it rather than inventing a second one.
- **The population** — everyone, a segment, a cohort, new users only. A metric moving for new users and not existing ones is a different result and needs the split declared up front.
- **The window** — how long until the result is readable, given traffic. A metric that needs six weeks to be readable cannot be judged at two.
- **Who decides** — the named person who will call it.

## Phase 2 — Organize

Five components, each required:

1. **Success metric** — one primary. Not three; three primaries means no primary, and whichever moves will be the one reported.
2. **Counter-metric** — the number that reveals damage, with the threshold at which the change is rolled back.
3. **Guardrail metrics** — the ones that must not degrade even though they are not the point (error rate, latency, support volume). Fewer than five; a guardrail list nobody reads is not a guardrail.
4. **Instrumentation plan** — per metric: measurable today, needs a new event, or needs a new derivation. Each gap is work with an owner and a date, before the change ships.
5. **Decision rule** — the pre-committed statement: what result means keep, iterate, or roll back, and by when.

## Phase 3 — Retrieve

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Additionally:
- `ai/patterns/problem-framing.md`, `ai/patterns/opportunity-sizing.md`.
- `.claude/rules/product-principles.md`.
- `ai/product/briefs/<slug>.md` — the brief's metric pair.
- The existing metric definitions — a metric defined twice with different filters produces two answers and a dispute. If the semantic layer or the metric catalogue already defines this, use that definition rather than a new one.
- Historical values for the proposed metric, to establish the baseline and its natural variance. A target inside the metric's normal week-to-week variance is not detectable.

## Phase 4 — Generate

1. **Baseline** — the metric's current value, over a stated window, with its variance. State the smallest change that would be distinguishable from noise given the current volume. If the expected effect is smaller than that, say so — the change may be worth making and simply not measurable, which is an honest and important conclusion.
2. **Target** — a value and a date, derived from the sizing in the brief where one exists, or explicitly labelled a guess.
3. **Counter-metric and rollback threshold** — pre-committed.
4. **Guardrails** — with their acceptable ranges.
5. **Instrumentation plan** — per metric, the gap, the owner, the date, and whether it blocks the launch.
6. **Decision rule** — written as a sentence with a date.

## Phase 5 — Update

- Write `ai/product/success/<slug>.md` with all five components.
- Hand every instrumentation gap to `/add-telemetry` (observability pack) or `/suggest-metrics` (business pack) as appropriate, with the metric definition attached.
- Record the review date so the decision actually gets made. An unreviewed decision rule is the same as no decision rule.

## Phase 6 — Validate

- **Confirm each metric is queryable today**, or that its gap has an owner and a date before launch. Run the query; a metric that "should be available" and is not is the most common launch-day discovery.
- **Confirm the baseline query returns the stated value** — re-run it, do not trust a screenshot.
- **Confirm the counter-metric can actually move independently.** A counter-metric mathematically coupled to the success metric is decoration; test the pair against a historical period where one moved.
- **Confirm the window is long enough** given current volume for the target effect to be distinguishable from variance.

### Success definition ledger — REQUIRED OUTPUT ARTIFACT

```
Role      | Metric                  | Baseline (window)   | Target / threshold | Queryable today | Gap owner | Blocks launch
success   | activation rate, 7-day  | 34% ± 2.1 (8 weeks) | 40% by <date>      | yes             | —         | —
counter   | 30-day retention        | 61% ± 1.4           | rollback below 58% | yes             | —         | —
guardrail | support tickets / 1k    | 4.2 ± 0.8           | must stay < 6      | needs derivation| <name>    | yes
```

## Phase 7 — Hand the ledger to the gate that checks it is live

This command's output is a *definition*; nothing here proves it will still be true on launch day. That
proof is `launch-readiness`, and it is the step most often skipped because nothing schedules it.

- **Dispatch `launch-readiness` before the change is enabled for real users** — by deploy, by flag, or
  by a rollout percentage increase past the point where rollback stops being cheap. Not now: it verifies
  the metrics are *arriving*, and at the moment this command runs the events may not exist yet.
- Record the scheduled run alongside the review date in `ai/product/success/<slug>.md`, so it is a
  calendar entry rather than an intention. A gate nobody schedules is a gate that runs after launch,
  where a `NOT READY` verdict is unactionable.
- Where any instrumentation gap was marked `blocks launch: yes`, that gap and this dispatch are the
  same piece of work — the gate cannot pass until the gap closes, so closing it is what unblocks both.

## Output format

```
## /define-success — <change> — <date>

Population: <who>   Window: <how long>   Decision owner: <named person>

Success definition ledger: <the table above, verbatim>

Detectability: smallest distinguishable change at current volume: <x>
               expected effect: <y>   → <detectable | NOT DETECTABLE in this window>

Decision rule: if <success metric> reaches <target> and <counter-metric> stays above <threshold>
               by <date>, keep. If <counter> breaches <threshold> at any point, roll back.
               If neither, <iterate | stop> — decided by <owner> on <review date>.

Instrumentation gaps blocking launch: <n> (each with owner and date)
launch-readiness scheduled: <date / trigger>   (verifies this ledger is live before enable)

Status: <see gate below>
```

### Closure gate — COMPLETE only when both metrics are queryable and the rule is pre-committed

- **`Status: COMPLETE`** — success and counter-metric both defined against existing definitions, both queryable (or gaps owned and dated before launch), baselines re-run in this session, the decision rule written with a threshold and a date, and a named owner.
- **`Status: INCOMPLETE — unmet: <list>`** — a metric with no baseline, a counter-metric that cannot move independently, an instrumentation gap with no owner, a decision rule with no date, or an undetectable target. Name each.

This gate is **[self-policed]** on the Status line; the baseline queries and the coupling test are reproducible. `@requirements-reviewer` will BLOCK a spec whose success definition is INCOMPLETE.

## Hard rules

- **One primary success metric.** Three primaries means none.
- **A counter-metric with a pre-committed rollback threshold**, always.
- **Instrumentation status is part of the definition**, and blocking gaps land before launch.
- **Outcome over activity**; where a proxy is used, say it is a proxy and say what it proxies for.
- **Re-run the baseline query in this session.** Do not trust a prior figure.
- **Never define a metric that already has a definition.** Reuse it or the two answers will be disputed.
- **A target inside the metric's natural variance is not a target.** Say so.
- **The `launch-readiness` run is scheduled here, not assumed.** A definition nobody re-checks on launch day is a definition, not a gate.

## Failure modes

- Metrics chosen after the result is known.
- Three success metrics, so whichever moved is the one reported.
- A counter-metric mathematically coupled to the success metric, so it can never contradict it.
- An activity proxy treated as the outcome.
- Instrumentation deferred to "right after launch" and never done.
- A window too short for the effect to clear noise, producing a confident null result.
- A decision rule with no review date, so the change is neither kept nor rolled back — it is simply forgotten.
- A complete, well-formed success definition that nobody re-checked before enabling — the events were implemented, never verified end-to-end, and launch day is when that is discovered.

## Related

- `@product-strategist` — declares the metric pair in the brief; this command instruments it.
- `@requirements-reviewer` — blocks specs whose success definition is incomplete.
- `launch-readiness` — dispatched at Phase 7, before the change is enabled; checks this ledger is live rather than merely defined.
- `/frame-problem` — supplies the brief.
- `/suggest-metrics` (business pack) — the broader question of which metrics a domain should carry.
- `/add-telemetry` (observability pack) — implements the instrumentation gaps.
- `semantic-layer` (data-engineering pack) — where a metric definition lives once, so it is not defined twice.
