---
name: dashboards
kind: example
pack: observability
---

# Pattern: Dashboards-as-Code

> **Hard rule:** Dashboards follow a tiered taxonomy (fleet overview → per-service → instance/debug drill-down), lead with RED/USE rows, are version-controlled as code (not hand-clicked), and every alert links to the panel that explains it while every panel answers a stated question. A hand-clicked board with no alert linkage and no drill path is forbidden.

**When to apply** — a service/fleet has enough surface that on-call needs "is anything broken, and where?" in under a minute; a new service ships (its RED/USE board is part of done); an alert can't get a responder to the explaining graph in one click.

**When NOT to apply** — a one-off script (exit code + log + absent-alert is the whole story); a throwaway prototype with no on-call.

A dashboard is the *reading surface* for the metrics in `metrics.md`: metrics without a board are dead weight; a board without discipline is a wall of graphs nobody reads at 3am. `@telemetry-architect` decides *that* a service needs a dashboard; this pattern owns *how* it's structured, tiered, versioned, and linked.

## The tier hierarchy — three altitudes, one drill path

| Tier | Question | Content |
|---|---|---|
| **Overview / fleet** | "Is anything broken across the estate?" | Per-service health tiles, SLO compliance, budget remaining, top burners |
| **Service** | "Is *this* service healthy, and why?" | RED row + USE row + business KPI row + deploy row |
| **Instance / debug** | "Which replica / dependency / shard?" | Per-instance breakdown, per-dependency latency, saturation drill |

Overview tiles link down to the service board; service panels link down to instance/debug (and out to logs/traces at the same time range). Every arrow is a real link, not a mental note.

## Panel taxonomy — RED for requests, USE for resources

Panels come from the two frameworks in `metrics.md`: **RED** (rate/errors/duration — top row of every service board), **USE** (utilization/saturation/errors per resource it owns), **Business** (≥1 domain KPI row), **Deploy** (build per replica, restarts). Order = symptom → cause: RED, business, USE, deploy.

## Dashboards-as-code — never hand-clicked

Author boards as code — Grafana JSON provisioned from disk, Grafonnet / grafanalib, or Terraform (`grafana_dashboard` / `datadog_dashboard`). The SLO board's burn panels come from the same Sloth/OpenSLO spec as the burn-rate rules (see `slo.md`), so panel and alert can't drift. A UI-only board is the thing this pattern eliminates.

## Every alert → a panel; every panel → a question

The alert annotation carries a link (dashboard + panel + firing time range) so the page drops the responder onto the explaining graph. Each panel answers one question a responder actually asks — if you can't state it, the panel is vanity; remove it.

## Detectors

- **Alert with no linked panel** — 3am scavenger hunt; wire the annotation.
- **No overview / drill-down tiering** — one giant board or no links between tiers.
- **Hand-clicked (non-versioned) dashboard** — move to dashboards-as-code.
- **Missing RED/USE row for a service** — add the standard rows.
- **Vanity / duplicate panel** — answers no question, or a query duplicated across boards.

## Related

- `metrics.md` — source of RED/USE/business panels; the "delete dead panels/metrics" rule is shared.
- `slo.md` — the SLO/burn board comes from the same spec as the burn-rate alerts.
- `skills/alert-audit/SKILL.md` — the alert→panel link is part of an alert being well-formed.
- `agents/telemetry-architect.md` — recommends *that* a service gets a board; points here for *how*.
