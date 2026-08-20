---
name: dashboards
description: 'Pattern: Dashboards-as-Code (tiered taxonomy, RED/USE rows, alert↔panel linkage)'
kind: ai-pattern
pack: observability
---

# Pattern: Dashboards-as-Code

> **Hard rule:** Dashboards follow a tiered taxonomy (fleet overview → per-service → instance/debug drill-down), lead with RED/USE rows, are version-controlled as code (not hand-clicked), and every alert links to the panel that explains it while every panel answers a stated question. A hand-clicked dashboard with no alert linkage and no drill path is forbidden.

**When to apply**
- A service (or fleet) has enough surface that on-call needs to answer "is anything broken, and where?" in under a minute.
- A new service ships — its RED/USE dashboard is part of the definition of done, generated from the same spec as its metrics.
- An alert exists but a responder can't get from the page to the graph that explains it in one click.
- Dashboard sprawl has set in: dozens of near-duplicate boards, half of them never opened.

**When NOT to apply**
- A one-off script / batch job — exit code + a log line + an absent-alert is the whole story; a dashboard is cost without a reader.
- A throwaway prototype with no traffic and no on-call — a board with no viewer is theater.

**Halt conditions / mandatory cites**
- Each dashboard MUST be defined as code at `<path>` (Grafana JSON / Terraform / Grafonnet / vendor-as-code) — a board that exists only in the UI, with no file, is a bug — reject.
- Each alert MUST cite the panel (dashboard + panel id / link) it drills into; an alert with no linked panel is a bug — reject.
- Each service dashboard MUST have a RED row (request-driven) and, where it owns resources, a USE row; a service board missing its RED row is a bug — reject.
- Each panel MUST answer a stated question (title or annotation); a panel that answers no question is a vanity panel — flag for removal.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this is dashboarded".
- If the dashboard backend (the project's Grafana / vendor / provisioning tool — whatever is in use) isn't extracted, halt.

A dashboard is the *reading surface* for the metrics defined in `metrics.md`. Metrics without a dashboard are dead weight; a dashboard without discipline is a wall of graphs nobody reads at 3am. This pattern is how the reading surface stays navigable, versioned, and wired to the alerts that send people to it.

## Relationship to `telemetry-architect` — this is the detailed owner

The `@telemetry-architect` agent *recommends* dashboards as part of designing a service's telemetry contract (service board / feature board / SLO board, 6-9 panels, organized by question). **This pattern is the detailed dashboard-design owner that the agent points to.** The agent decides *that* a service needs a dashboard and what signals it emits; this pattern owns *how the dashboard is structured, tiered, versioned, and linked*. When the agent says "add a service dashboard", the shape it must take is defined here. Don't duplicate the taxonomy in both places — the agent references this file.

## The tier hierarchy — three altitudes, one drill path

Dashboards are a taxonomy, not a pile. Each tier answers a different question and drills into the next:

| Tier | Question | Scope | Content |
|---|---|---|---|
| **Overview / fleet** | "Is anything broken across the estate?" | All services / an SLO summary | Per-service health tiles, SLO compliance, error-budget remaining, top burning services |
| **Service** | "Is *this* service healthy, and why?" | One service | RED row + USE row + business KPI row + deploy row |
| **Instance / debug** | "Which replica / dependency / shard is the problem?" | One instance / pool / upstream | Per-instance breakdown, per-dependency latency, saturation drill-down |

The overview tiles link down to the service board; the service board's panels link down to the instance/debug board (and out to logs/traces at the same time range). A responder starts at the top and drills — they should never have to *hunt* for the next board. A dashboard set with no tiering (everything on one giant board, or boards with no links between them) fails this pattern.

## Panel taxonomy — RED for requests, USE for resources

Panels aren't chosen ad hoc; they come from the two frameworks in `metrics.md`:

- **RED** (Rate, Errors, Duration) — the per-service request row. Every request-driven service leads with it: rate per endpoint, error rate %, latency p50/p95/p99. This is the top row of every service board.
- **USE** (Utilization, Saturation, Errors) — the per-resource row. For every resource the service owns (DB pool, job queue, cache, CPU/memory): utilization, saturation (the pending-work signal — pool waiters, queue depth), resource errors.
- **Business** — ≥1 domain KPI row (orders/min, signups/hr, payment auth rate) so the board answers "is the product working", not just "is the process up".
- **Deploy** — build version per replica, replica count, restart count — so "did this start at the last deploy?" is one glance.

Order matters: RED first (what the user feels), then business (what the product feels), then USE (why), then deploy (what changed). A responder reads top-to-bottom from symptom to cause.

Concrete shape of the tiered set (illustrative — the links are the point):

```
[Fleet overview]  per-service health tiles · SLO compliance · budget remaining · top burners
      │  tile "checkout ✗" links ↓
[Service: checkout]
  Row 1 RED       rate/endpoint · error % · p50/p95/p99      ← burn-rate alert links to the error panel
  Row 2 BUSINESS  orders/min · payment auth rate
  Row 3 USE       db pool in-use/waiting · queue depth · cache hit  ← panel "pool waiting" links ↓
  Row 4 DEPLOY    build/replica · replica count · restarts
      │  USE panel links ↓ + "view logs/traces at this range" ↘
[Instance/debug: checkout]  per-replica breakdown · per-upstream latency · saturation drill
```

Every arrow is a real link in the board definition, not a mental note the responder has to make at 3am.

## Dashboards-as-code — never hand-clicked

A dashboard clicked together in the UI is unversioned, unreviewable, and gone when someone fat-fingers it. Define boards as code:

- **Grafana** — export/author as JSON models provisioned from disk, or generate with **Grafonnet** (Jsonnet) / **grafanalib** (Python); manage with Terraform (`grafana_dashboard`) or file provisioning. Same for alert rules.
- **Vendor** — Datadog dashboards via Terraform (`datadog_dashboard`) or the dashboards-as-code API; New Relic via Terraform / NerdGraph.
- **Generated from the SLO/metric spec** — the SLO board's burn panels come from the same Sloth/OpenSLO spec that emits the burn-rate rules (see `slo.md`), so the panel and the alert can never drift.

The spec lives in version control next to the service; PRs to a dashboard get reviewed like code. A board that exists only in the UI is the thing this pattern exists to eliminate.

## Every alert links to a panel; every panel answers a question

Two reciprocal disciplines that make the board usable under pressure:

- **Every alert → a panel.** The alert annotation carries a link (dashboard + panel + the firing time range) so the page drops the responder straight onto the graph that explains it. An alert with no panel is a 3am scavenger hunt.
- **Every panel → a question.** Each panel exists to answer one question a responder or reviewer actually asks ("Is checkout erroring?", "Which upstream is slow?", "How much budget is left?"). If you can't state the question, the panel is vanity — remove it.

This is the same "declared with the feature, consumed by a reader" contract as `metrics.md`: a metric with no dashboard/alert is dead; a panel with no question or no alert traffic is dead the other direction.

## Avoiding vanity panels + dashboard sprawl

- **Vanity panels** — graphs that look impressive and answer nothing (raw CPU on a board where nobody acts on CPU, a metric with no threshold anyone cares about). Cut them; they dilute signal.
- **Duplicate panels** — the same query on three boards drifts and confuses. One canonical panel; link to it.
- **Sprawl** — dozens of boards, most never opened. Keep the tiered set small (6-9 panels per board, per `telemetry-architect`); if a board hasn't been opened in 90 days, delete it (same rule as dead metrics in `metrics.md`).
- **Screenshot-in-incident** — a panel screenshot doesn't reproduce; link the dashboard at the time range instead.

## Detectors (what a reviewer flags)

- **Alert with no linked panel** — the page can't get the responder to a graph; wire the annotation to a panel + time range.
- **No overview / drill-down tiering** — one giant board, or boards with no links between tiers; a responder can't drill symptom → cause. Impose the three tiers.
- **Hand-clicked (non-versioned) dashboard** — a board that exists only in the UI with no file in version control. Move it to dashboards-as-code.
- **Missing RED/USE row for a service** — a service board with no RED row (or no USE row where it owns resources). Add the standard rows from `metrics.md`.
- **Vanity / duplicate panel** — a panel that answers no stated question, or a query duplicated across boards. Remove or consolidate to one canonical panel.

## Related

- `metrics.md` — the source of RED / USE / business panels; a panel visualizes a metric defined there, and the "delete dead panels/metrics" rule is shared.
- `slo.md` — the SLO/burn-rate board comes from the same spec as the burn-rate alerts; panel and alert must not drift.
- `skills/alert-audit/SKILL.md` — audits alert quality; the alert→panel link this pattern requires is part of an alert being well-formed.
- `agents/telemetry-architect.md` — recommends *that* a service gets a dashboard; points here for *how* it's structured, tiered, and versioned.
- `agents/observability-reviewer.md` — reviews dashboard-as-code PRs against these detectors at the code-change level.
