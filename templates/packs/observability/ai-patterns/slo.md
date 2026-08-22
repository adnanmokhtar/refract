---
name: slo
description: 'Pattern: SLOs + Error Budgets + Burn-Rate Alerting'
kind: ai-pattern
pack: observability
---

# Pattern: SLOs + Error Budgets + Burn-Rate Alerting

> **Hard rule:** Every user-facing service has ≥1 SLO with an explicit SLI (symptom-based, not cause-based), a derived error budget (`budget = 1 − SLO`), and a **multi-window multi-burn-rate** alert set — two burn *pages* (fast and medium) AND a slow-burn *ticket*, each gated by a short confirmation window. A threshold on a single window is not an SLO alert, and a two-tier set with no slow-burn ticket cannot see a leak burning at target rate. Raw CPU / queue-depth thresholds are not SLIs.

**When to apply**
- A service has users (internal or external) who feel latency, errors, or staleness — and "how reliable should this be?" needs a number, not a vibe.
- On-call is drowning in threshold alerts that don't map to user pain, or an SLA is being negotiated and needs an internal SLO with headroom underneath it.
- A team wants to trade reliability work against feature work with a shared, quantified budget.

**When NOT to apply**
- A batch job or internal tool where "did it finish?" (exit code + absent-alert) is the whole reliability story — no continuous request stream to measure a ratio over.
- Pre-product-market-fit prototypes with no users to disappoint — an SLO with no traffic behind it is theater.

**Halt conditions / mandatory cites**
- Each SLO MUST cite the SLI's emit site at `<path:line>` (the good-events + valid-events queries) AND the burn-rate alert rule that consumes it.
- Each error budget MUST cite the SLO target it derives from and the window it's measured over (28d / 30d / calendar-month — pick one, state it).
- A burn-rate alert with only ONE window (no short confirmation window) is a bug — reject; it fires stale after recovery and misses fast burns.
- An SLI measured on a cause (CPU%, pool saturation, queue depth) rather than a symptom (user-facing latency / errors / freshness) is a bug — reject; move the cause to a saturation *warning*, keep the SLO on the symptom.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this meets its SLO".
- If the SLO backend (the project's TSDB recording rules / SLO service / OpenSLO spec — whatever is in use) isn't extracted, halt.

An SLO is a **target reliability** for a thing users feel, measured by an **SLI** (a ratio of good events to valid events), with an **error budget** that quantifies how much unreliability you're allowed before you stop shipping features and fix reliability. It turns "is it reliable enough?" from an argument into arithmetic.

## Pattern vs. the live registry — do not conflate

This file is the **pattern**: how to choose an SLI, derive a budget, and wire burn-rate alerts. It is stack-agnostic and rarely changes.

The project's **live SLO registry** lives at `ai/runtime/slos.md` — the actual per-service targets, windows, current attainment, and owners. That's *data*, consumed by the `slo-audit` skill and the `alert-design` command. When you define a new SLO, the target + window go in the registry; the *method* stays here. A reviewer citing "the checkout SLO is at 99.2% against a 99.9% target" is reading the registry; a reviewer citing "burn-rate alerts need two windows" is reading this pattern.

## SLI menu — pick the symptom the user feels

An SLI is `good events / valid events`. Choose the flavor that matches what the user actually experiences:

| SLI | Good event | Use for | Shape |
|---|---|---|---|
| **Availability** | Response is not a 5xx / not a failed RPC | Any request/response service | request-based |
| **Latency (percentile)** | Request served **faster than threshold T** | Interactive paths where slow == broken | request-based |
| **Correctness** | Response is complete / accurate (right total, no dropped records) | Pipelines, billing, search results | request-based |
| **Freshness** | Data served is within staleness bound (e.g., ≤5 min old) | Caches, read replicas, feeds, ML features | windows-based |

Two critical framings:

- **Latency SLI is a *count*, not a value.** The SLI is "proportion of requests under 300 ms", NOT "p99 latency". You threshold once (T = 300 ms) and count good vs. bad — this composes into a budget; a raw p99 number does not.
- **Request-based vs. windows-based.** Request-based = good requests / valid requests over the whole period (best when you have a steady request stream). Windows-based = good *time windows* / total windows, where a window (say 1 min) is "good" if it clears a per-window bar (e.g., <1% errors that minute). Windows-based suits freshness / low-traffic services where a per-request ratio is noisy; it deliberately weights every minute equally regardless of traffic.

**Symptom, not cause.** SLIs measure what the user feels at the edge — errors, latency, staleness. CPU%, DB-pool saturation, and queue depth are *causes*; they belong on USE saturation *warnings* (see `metrics.md`), never on an SLO. If your "SLO" is "CPU < 80%", you've written a cause-based detector wearing an SLO costume.

## Error budget — the arithmetic

```
error budget = 1 − SLO
```

Over a 30-day window (43,200 minutes), the budget of *allowed* unreliability is:

| SLO | Budget (1 − SLO) | Allowed downtime / bad-request time per 30d |
|---|---|---|
| 99%    | 1%    | 7.2 hours |
| 99.9%  | 0.1%  | **43 minutes** |
| 99.95% | 0.05% | 21.6 minutes |
| 99.99% | 0.01% | 4.3 minutes |

The budget is the currency: when it's healthy, ship features; when it's exhausted, the policy is "reliability work only until it recovers". Each nine roughly costs 10× more engineering — pick the *lowest* SLO users will tolerate, then keep headroom below any contractual SLA (SLA 99.9% → internal SLO 99.95%, so you fix before the customer notices).

## Multi-window multi-burn-rate alerting — the canonical three tiers

A **burn rate** is how fast you're spending budget relative to "exactly on target". Burn rate 1× spends the whole 30-day budget in exactly 30 days; 14.4× spends it 14.4× faster.

The problem with a **single-window** alert (e.g., "error ratio > threshold over 1h"): a short window pages late and keeps firing for an hour *after* recovery (the window drains slowly); a long window catches slow burns but is hours late to a hard outage. The fix is **two burn rates, each confirmed by a short window** — the alert fires only when the long window AND its short confirmation window both exceed the threshold. The short window makes the burn *current* (kills the alert seconds after recovery); the long window kills flapping on a momentary spike.

The canonical table is **three** tiers, not two — this is Table 5-8 of the SRE Workbook, reproduced exactly, because the pack's own artifacts have contradicted each other on it:

| Severity | Budget consumed if sustained | Long window | Short (confirmation) window | Burn rate |
|---|---|---|---|---|
| **Page** (fast burn) | 2% | 1h | 5m | **14.4×** |
| **Page** (medium burn) | 5% | 6h | 30m | **6×** |
| **Ticket** (slow burn) | 10% | 3d | 6h | **1×** |

Two things about this table are routinely gotten wrong, and both change behaviour:

- **6h / 6× is a PAGE, not a ticket.** Losing 5% of the month's budget in six hours is an ongoing
  outage that a human should be woken for. Demoting it to a ticket means a Saturday-morning
  regression waits until Monday, by which time a third of the budget is gone.
- **The tier that *is* a ticket is 3d / 1×**, and it is the one most often dropped entirely. It is
  the only detector for a persistent low-grade leak — a burn rate of exactly 1× never trips either
  page tier by construction, because 1× is "precisely on target". Without this row you have no
  alarm at all for the failure mode "we will miss the SLO at the end of the month and nothing ever
  fired".

**Deriving the burn rates** (so you can compute a tier this table doesn't have): at 1× you spend
`window / 720h` of a 30-day budget. Fast: 2% in 1h → `0.02 / (1/720) = 14.4×`. Medium: 5% in 6h →
`0.05 / (6/720) = 6×`. Slow: 10% in 3d (72h) → `0.10 / (72/720) = 1×`. Write **14.4**, not 14 — the
rounded value is a different threshold and it propagates into generated rules.

**Deriving the confirmation window:** make the short window **1/12 the long window**. That is where
5m/1h and 30m/6h come from, and it is what lets you pick a window pair this table doesn't list — a
2h long window takes a 10m confirmation window, not a memorized guess.

All three tiers compare `error-ratio(long) > threshold AND error-ratio(short) > threshold`, where
`threshold = (1 − SLO) × burn_rate`. Precompute the ratios as recording rules so the alert
expression stays cheap.

## SLO-as-code

Do not hand-maintain burn-rate PromQL — it's error-prone (four windows, two thresholds, recording rules). Generate it from a spec:

- **Sloth** — compiles a small per-SLO YAML into Prometheus recording + multi-window burn-rate alerting rules. The pragmatic default on a Prometheus stack.
- **OpenSLO** — a vendor-neutral SLO spec (YAML); portable across tools, good as the source of truth checked into the repo.
- **Pyrra** (Prometheus, with a UI) and **Nobl9** (commercial, multi-source) — same idea, richer surfaces.

Keep the *spec* in version control next to the service; let the tool emit the rules. The registry (`ai/runtime/slos.md`) then references the spec, not copy-pasted queries.

## Detectors (what a reviewer flags)

- **SLO with no error budget or no burn-rate alert** — a target number with nothing enforcing it is a poster, not an SLO.
- **Single-window burn alert** — one window, no short confirmation window: fires stale after recovery and is blind to fast burns. Rewrite as multi-window, short = 1/12 long.
- **Only two tiers wired** — fast + medium pages configured and no `3d / 1×` ticket. A budget leak that burns at exactly the target rate trips neither page tier and reaches month-end unannounced.
- **6h / 6× demoted to a ticket** — a page tier relabelled, so a six-hour outage waits for business hours. Google's ticket tier is `3d / 1×`; this one pages.
- **Cause-based SLI** — the SLI thresholds CPU / pool / queue depth instead of a user-facing symptom. Move it to a saturation warning; put the SLO on latency/errors/freshness.
- **Latency SLO stated as a raw percentile** (`p99 < 300ms` *as the SLO*) rather than a good-request count — it doesn't compose into a budget.
- **SLA with no headroom** — internal SLO equals the contractual SLA, so you find out you breached from the customer.

## Related

- `metrics.md` — the SLI numerator/denominator come from RED metrics; saturation (the *causes*) stays on USE warnings, not the SLO.
- `ai/runtime/slos.md` — the project's live SLO registry (data), distinct from this pattern (method).
- `skills/slo-audit/SKILL.md` — audits the registry against achieved attainment; consumes the budget math defined here.
- `commands/alert-design.md` — wires the burn-rate alerts this pattern specifies.
- `agents/sre-engineer.md`, `agents/incident-responder.md` — blameless retros are scored against budget spend defined here.

## References

- Google SRE Workbook, "Alerting on SLOs" — Table 5-8 (the three tiers above) and the 1/12 short-window guideline: `https://sre.google/workbook/alerting-on-slos/`
- Google SRE Book, "Service Level Objectives": `https://sre.google/sre-book/service-level-objectives/`
- OpenSLO specification: `https://github.com/OpenSLO/OpenSLO`
- Sloth (Prometheus SLO generator): `https://sloth.dev/`
