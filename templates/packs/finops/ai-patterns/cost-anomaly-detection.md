---
name: cost-anomaly-detection
description: 'Pattern: Cost Anomaly Detection (declared baseline, per-dimension seasonal detectors, rate-of-change, suppression with expiry)'
kind: ai-pattern
pack: finops
---

# Pattern: Cost Anomaly Detection

> **Hard rule:** A detector requires a declared expectation — you cannot detect deviation from a baseline that was never stated. Detect per dimension, not only on the total; detect on rate of change as well as level; handle seasonality or the detector fires every Monday. Every detector has a derived threshold, a named recipient, and a named action, and is proved to fire before it counts as coverage.

**When to apply**
- After a unit-economics model declares an expected cost per unit.
- After a spend surprise that nothing detected.
- When a new account, environment, or team is created.
- When the only thing that notices cost is the invoice.

**When NOT to apply**
- Before a cost model exists. A budget with no unit expectation behind it is a number someone made up, and it will be raised rather than investigated.
- On spend too small for a deviation to be distinguishable from noise — say so rather than installing a detector that cries wolf.

**Halt conditions / mandatory cites**
- No declared expectation exists — the first output is that gap, not a detector.
- Recipient undeclared for any detector being installed.
- Daily (ideally hourly) cost granularity unavailable — monthly data cannot support detection.
- Any threshold with no derivation from trailing history or the declared expectation is a hand-wave — reject it.

## Detect per dimension, not on the total

A service tripling inside a flat total is invisible. Total-only detection is the most common reason a cost anomaly is found on an invoice: growth in one place offsets a reduction in another, and the aggregate looks calm.

Detect at the grouping where a mechanism lives:
- account / project
- service **× usage type** — the usage type is the mechanism (requests versus storage versus transfer); service-level detection cannot distinguish them
- tag (team, product, environment)
- region

More dimensions means more detectors and more noise, so pick the groupings that carry material spend and let the rest roll up.

## Detect on level *and* on rate of change

A level threshold catches spikes. It never catches the slow creep — 4% a week, no single day remarkable, doubled in a quarter — which is how most cost problems actually happen.

Two detector shapes, both needed:
- **Level** — today's spend against a seasonal baseline. Catches the step change.
- **Rate of change** — the slope of the trailing window against its own history. Catches the creep, and it is the one almost nobody installs.

## Seasonality is not optional

Most spend has a strong weekday/weekend shape and often a monthly one (batch closes, billing runs, reporting cycles). A detector without seasonality fires every Monday until someone mutes it, and a muted detector is worse than none because it creates false confidence.

Baseline against the same day-of-week over a trailing multi-week window rather than against yesterday.

## Thresholds are derived, not chosen

Every threshold cites either:
- trailing history computed when the detector was set — the window, the statistic, the tolerance, recorded inline; or
- the declared expectation from the cost model (`$/unit ± threshold`).

A round number picked because it looked reasonable either never fires or fires constantly. Record the derivation next to the detector so the next person tuning it has a baseline instead of a preference.

## Every detector has a recipient and an action

An alert whose action is "be aware" is noise, and noise trains people to ignore the real one. Each detector declares:
- **recipient** — a named owner, not a shared inbox
- **action** — investigate, approve, or throttle
- **runbook** — what to do first, which for cost is almost always "run the triage: rule out billing artefacts, split rate/usage/mix, localise, correlate"

Reuse the observability pack's existing alert routing. A second paging path fragments on-call and halves the chance anyone responds.

## Suppression with an expiry

Known events — a scheduled backfill, a load test, a launch, a migration — should be suppressed by annotation, not by widening the threshold. Widening is permanent and silent; annotation is scoped and visible.

Every suppression carries an expiry date. A permanent suppression is a deleted detector wearing a disguise, and it will be discovered during the next incident.

## Prove it fires

A detector that has never fired is unverified. Replay a historical period containing a known spike and confirm it would have fired; record the **lead time** — how much earlier it would have been caught than the spike actually was.

That lead time is the detector's value, stated as a number. A detector with a lead time of zero is decoration.

## Close the loop

Every triage of a real anomaly ends by either validating the detector or improving it — a new dimension, a tightened threshold, a rate-of-change detector where only a level detector existed. A triage that ends without touching the detector guarantees a repeat, and the second occurrence is always more expensive because it ran longer.

## Detectors (for the detection itself)

- A budget with no unit expectation behind it.
- Detection on the total only.
- A threshold with no recorded derivation.
- A detector with no seasonality on spend that obviously has a weekly shape.
- No rate-of-change detector anywhere.
- A detector routed to a shared inbox.
- A suppression with no expiry, or one older than the event it was created for.
- A detector never observed firing, live or by replay.
- An anomaly triage that closed with no detector change.

## Related

- `ai/patterns/unit-economics.md` — supplies the declared expectation.
- `ai/patterns/spend-allocation.md` — a detector can only be scoped to what can be attributed.
- `ai/patterns/commitment-strategy.md` — expiries are a classic rate-change anomaly with no usage cause.
- `spend-anomaly-triage` — what runs when a detector fires.
- `/cost-guardrails` — the command that installs and proves these detectors.
- `alert-design` (observability pack) — the routing conventions these alerts reuse.
