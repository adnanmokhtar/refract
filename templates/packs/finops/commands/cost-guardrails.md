---
description: Install the preventive cost layer — budgets with owners, anomaly detection with a declared baseline, per-environment quotas, a pre-merge infrastructure cost estimate, and retention and lifecycle defaults. Turns cost from something discovered on an invoice into something detected on the day it changes.
kind: command
pack: finops
---

# /cost-guardrails [--scope <account|project|service>]

Cost problems are found late because nothing is watching. This command installs the watching: a declared expectation, a detector against it, a bound on what can be created, and an estimate that reaches the author before the merge rather than the accountant after the month.

## When to use / NOT to use

- USE: after `/cost-model` has declared an expectation; after a spend surprise; when a new account, environment, or team is created; when infrastructure is defined as code and no cost estimate runs in CI; when nobody is notified of anything until the invoice.
- NOT: to explain a spike that already happened — that is `spend-anomaly-triage`.
- NOT: to reduce existing spend — that is `/cost-audit` in the infrastructure pack.
- NOT: as a substitute for a cost model. A budget with no unit expectation behind it is a number someone made up, and it will be raised rather than investigated.

## Phases applied

1-3 + 4 + 5 + 6.

## The Premise (read this first, internalize, do not deviate)

**A detector needs a declared baseline.** You cannot detect a deviation from an expectation that was never stated. If `ai/finops/unit-economics.md` has no declared cost per unit, this command's first output is that gap, not a budget.

**Every alert has an owner and an action.** A budget alert routed to a shared inbox is a budget alert that will be muted. Name the recipient and name what they do on receipt — investigate, approve, or throttle. An alert whose only action is "be aware" is noise, and noise trains people to ignore the real one.

**Guardrails bound; they do not merely notify.** A notification-only guardrail is a smoke alarm with no fire door. Where the environment allows it — non-production, preview stacks, experimental accounts — install a hard bound (quota, service control, TTL on created resources), not just an alert.

**Not every guardrail fires on a measurement.** The most reliably surprising cost event is a commitment lapsing, and no detector in classes 1–5 can see it coming: usage is flat, the architecture is unchanged, and the threshold is never breached until after the step. That class fires on a calendar, and it is installed here rather than being left to whoever notices.

**Thresholds are derived, not chosen.** Every threshold cites trailing history computed in this run, or the declared expectation from the cost model. A round number picked because it looked reasonable will either never fire or fire constantly.

**Escalation triggers (halt and ask):**
- No declared expectation exists — run `/cost-model` first.
- The alert recipient is undeclared for any guardrail being installed.
- A hard bound is proposed for a production path — that is a reliability decision and needs an explicit human decision about what happens when the bound is hit.

## Phase 1 — Understand

Confirm:
- **Scope** — account, project, service, or environment.
- **The declared expectation** — from `ai/finops/unit-economics.md`. Budgets derive from it; a budget that contradicts the unit model is one of the two being wrong.
- **Recipients** — per guardrail, a named owner and a named action.
- **Bound tolerance** — which environments may be hard-bounded, and what the acceptable failure mode is when a bound is hit.
- **Pricing model** — under flat-rate capacity, budgets are about contention and quota, not dollars.

## Phase 2 — Organize

Five guardrail classes, installed in this order because each is cheaper than the next to act on:

1. **Pre-merge estimate** — an infrastructure cost estimate on the pull request, so the author sees the delta before it exists. The cheapest possible moment to change a decision.
2. **Creation bounds** — quotas, service control policies, allowed resource shapes and sizes, and required tags enforced at creation rather than detected afterwards.
3. **Lifecycle defaults** — retention on stores, TTL on preview and experimental resources, log retention, snapshot expiry. A default that expires is worth more than a policy that reminds.
4. **Anomaly detection** — per-dimension baselines with seasonality, alerting on deviation from the declared expectation and on unexplained period-over-period movement.
5. **Budgets** — the backstop, with a forecast alert (projected to breach) as well as an actual alert (has breached). A budget that only fires on actual breach fires after the money is spent.
6. **Expiry notifications** — every commitment expiry as a dated, owned entry. This class is last because it is the only one that fires on a calendar rather than on a measurement, and it is the one most often missing: nothing in the system changes, usage is flat, and the bill steps up. Dispatch **`commitment-coverage`** for the expiry calendar and the computed bill increase per entry; a notification that says "expires on the 14th" without the resulting monthly delta is not actionable and will be dismissed.

## Phase 3 — Retrieve

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Additionally:
- `ai/finops/unit-economics.md` — the declared expectation and threshold.
- `ai/finops/attribution.md` — a budget can only be scoped to what can be attributed.
- `ai/patterns/cost-anomaly-detection.md`, `ai/patterns/unit-economics.md`, `ai/patterns/spend-allocation.md`.
- `.claude/rules/finops-principles.md`.
- Trailing spend history at the grouping the detectors will use, for threshold derivation. Dispatch **`@finops-analyst`** for it rather than retrieving it by hand — the thresholds inherit its normalisation (amortised, discounted, whole periods), and a threshold derived from a differently-normalised history will fire against the wrong baseline.
- The commitment inventory with expiry dates, from **`commitment-coverage`**, for the class-6 guardrails.
- The observability pack's alert routing conventions — cost alerts reuse them rather than creating a second paging path.

## Phase 4 — Generate

For each guardrail: the definition (as code, checked in), the derived threshold with its derivation recorded inline, the recipient, and the action on fire.

Anomaly detectors specifically:
- Baseline from trailing history at the same grouping, with weekly seasonality handled — most spend has a strong weekday/weekend shape, and a detector that ignores it fires every Monday.
- Detect on **rate of change and on level**, because a slow linear creep never breaches a level threshold and is the most common way spend doubles.
- Detect **per dimension** (service, usage type, account, tag), because a doubling in one small service is invisible in the total.
- Suppress known events (a scheduled backfill, a load test, a launch) by annotation rather than by widening the threshold.

## Phase 5 — Update

- Check every guardrail definition into the repository. A budget configured in a console is undiscoverable and unreviewable.
- Write `ai/finops/guardrails.md`: one row per guardrail — scope, threshold, derivation, recipient, action, and the date it was last reviewed.
- Record the suppression list with expiry dates. A permanent suppression is a deleted guardrail wearing a disguise.

## Phase 6 — Validate

Each guardrail is proved to fire, or it is not installed:

- **Pre-merge estimate** — open a throwaway change that adds a priced resource and confirm the estimate appears with a non-zero delta.
- **Creation bound** — attempt to create a resource that violates the quota or the required-tag rule in a non-production scope, and confirm rejection.
- **Lifecycle default** — confirm the expiry is set on a newly created resource, by reading it back.
- **Anomaly detector** — replay a historical period containing a known spike and confirm it would have fired; state the lead time versus when the spike was actually noticed.
- **Budget** — confirm the forecast alert routes to the named recipient (send a test through the same path).
- **Expiry notification** — confirm the entry exists for the *next* expiry with its computed bill increase attached, and that it fires far enough ahead to act on (a renewal decision needs the floor re-analysed, which is not a same-day task).

### Guardrail ledger — REQUIRED OUTPUT ARTIFACT (the run is not done until this table exists)

```
Guardrail            | Class        | Threshold (derivation)          | Recipient | Action on fire | Proved? | Status
pr-cost-estimate     | pre-merge    | any delta > $0                  | author    | reconsider     | yes     | ARMED
preview-stack-ttl    | lifecycle    | 72h (median preview lifetime 8h)| platform  | auto-destroy   | yes     | ARMED
svc-anomaly-detector | anomaly      | +30% d/d vs 28d seasonal baseline| owner    | triage         | replay  | ARMED
monthly-budget       | budget       | $x (declared expectation × vol) | finance   | approve/throttle| test    | ARMED
commitment-expiry-90d| expiry       | 90d before each expiry (inventory)| owner   | renew/lapse    | yes     | ARMED
```

Per-row `Status`:
- **ARMED** — defined as code, threshold derived, recipient named, action named, and observed firing (or replay-confirmed).
- **UNPROVEN** — installed but never observed firing. Not counted as coverage.
- **NOISE** — fires more often than the recipient can act on. Retune or remove; a muted guardrail is worse than none because it creates false confidence.

## Output format

```
## /cost-guardrails — <scope>

Declared expectation: <$/unit> ± <threshold>   (source: ai/finops/unit-economics.md)
Attributable share:   <%>                       (source: ai/finops/attribution.md)

Guardrail ledger: <the table above, verbatim>

Coverage: pre-merge <y/n> · creation bounds <n> · lifecycle defaults <n> ·
          anomaly detectors <n> · budgets <n> · expiry notifications <n> of <n> commitments
Replay: detector would have caught <n> of <n> historical spikes, median lead time <x>
Suppressions: <n> active, <n> with no expiry (listed)

Status: <see gate below>
```

### Closure gate — COMPLETE only when every ledger row is ARMED

- **`Status: COMPLETE`** — every row ARMED with a derived threshold, a named recipient, a named action, and an observed or replayed firing; every suppression carries an expiry.
- **`Status: INCOMPLETE — unmet: <list>`** — any row UNPROVEN or NOISE, any threshold without a derivation, any recipient unnamed, or any suppression without an expiry. Name each (`monthly-budget — UNPROVEN: forecast alert never routed in a test`).

This gate is **[self-policed]** on the Status line, but each proof is reproducible: the throwaway pull request, the rejected creation attempt, the read-back expiry, the detector replay, the routed test alert.

## Hard rules

- **No guardrail without a derived threshold**, a named recipient, and a named action.
- **No guardrail counted as coverage until it has been observed firing** — live or by replay.
- **Every guardrail defined as code** and checked in. Console configuration is invisible to review.
- **Hard bounds in non-production, alerts in production** — unless a human explicitly decides otherwise and the failure mode is written down.
- **Suppressions expire.** A permanent suppression is a removed guardrail.
- **Reuse the existing alert routing.** A second paging path fragments on-call.

## Failure modes

- A budget set to last year's spend plus 20%, which is raised every year and has never caused an investigation.
- Anomaly detection on the total only, so a service tripling inside a flat total is invisible.
- A detector with no seasonality that fires every Monday until it is muted.
- Preview environments with a TTL that was never proved to run, accumulating for months.
- Pre-merge estimates that appear on the pull request and are never blocking, never read, and never referenced.
- A suppression added during a migration and never removed.
- A commitment expiry nobody scheduled, so the bill steps up with no architectural cause and the next month is spent triaging an anomaly that was on a calendar all along.
- Guardrails installed in a console, invisible to the repository, deleted by whoever restructures the account next.

## Related

- `@cost-architect` — declares the expectation and the guardrail at design time.
- `@finops-analyst` — dispatched in Phase 3 for the trailing history the thresholds are derived from.
- `commitment-coverage` — dispatched in Phase 2 class 6 for the expiry calendar and the bill increase per entry.
- `@cost-reviewer` — the human counterpart to the pre-merge estimate.
- `spend-anomaly-triage` — what runs when a detector fires.
- `/cost-model` — must run first; supplies the declared expectation.
- `/audit-cost-attribution` — bounds what a budget can be scoped to.
- `alert-design` (observability pack) — the routing conventions these alerts reuse.
- `ai/patterns/cost-anomaly-detection.md`, `ai/patterns/unit-economics.md`.
