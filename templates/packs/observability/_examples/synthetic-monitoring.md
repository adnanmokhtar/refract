---
name: synthetic-monitoring
description: Audit blackbox / synthetic coverage of critical user journeys — journeys with no scripted probe, alerting that fires only on white-box signals, probes with no probe-SLO, single-location probes, and probes that ping /health instead of the real journey.
---

# synthetic-monitoring

White-box metrics say the server is healthy. They can't say the user got through checkout. A synthetic probe drives the real journey from outside and catches "everything green, nobody can log in".

## Premise

Every critical journey (login, checkout, primary CRUD, payment) has a scripted blackbox probe that runs from outside on a cadence, from ≥2 locations, with its own probe-SLO and its own alert route. Find the journeys that don't. Every "no probe / single location / pings /health / no probe-SLO" finding cites the journey, the probe config path (or its absence), and the alert rule that does — or doesn't — page on probe failure.

## API vs browser synthetics

- **API synthetics** — hit the endpoints the journey depends on (POST /login → GET /cart → POST /checkout), assert status + body + latency. Cheap, fast, high cadence (30s–1m).
- **Browser synthetics** — drive a real headless browser through the rendered flow. Catch broken JS bundles, a CSP that blocks the payment iframe, a button that stopped submitting. Slower/flakier; low cadence (2–5m) on the top 1–3 journeys.

Most critical journeys want both. Probe from ≥2 locations — one-location failure + another success = regional net/CDN/DNS, not an outage.

## Probe-SLO — probes get an SLO too

Give each journey probe two SLIs, wired with multi-window burn-rate alerts (see `slo.md`):
- **Probe success rate** — proportion of runs that completed the journey and passed every assertion.
- **Probe latency** — proportion of runs that finished under a threshold T (a *count* under T, not a raw p99). A journey that "works" but takes 40s is broken.

The probe-SLO lives in `ai/runtime/slos.md` next to the service SLOs.

## Blackbox-vs-whitebox alerting split

A synthetic failure **pages on its own**, even when every white-box signal is green — the blackbox is the ground truth of user experience. Never gate the synthetic page behind a white-box condition; that defeats the whole point (a bad static-bundle deploy, expired TLS cert, DNS/CDN misconfig looks fine internally).

Boundary: synthetic = *scripted, active*; RUM = *real users, passive* (owned by `web-vitals-field`, performance pack). Both present, not confused.

## Scans for (detectors)

- **Critical journey with no blackbox probe** — the headline defect.
- **Alerting only on white-box signals** — no route fires on synthetic failure.
- **No probe-SLO** — a probe with no success-rate / latency target + burn-rate alert.
- **Single-location probe** — regional fault indistinguishable from an outage.
- **A probe that only pings `/health`** — liveness ≠ journey coverage.
- **Synthetic alert routed to a dead channel** — coverage on paper, not in practice.

## Output (illustrative shape)

```
Synthetic coverage — <synthetic backend> + <paging service>

Critical journeys: 6
Covered by a real journey probe: 3
Uncovered / health-only: 3

Uncovered journeys (add a probe):
  - checkout             NO probe — highest-revenue path, blackbox blind. Add API + browser probe, 2 locations.
  - password_reset       probe pings /health only — doesn't exercise the reset flow. Rewrite to drive the journey.

Probe-SLO gaps:
  - login_probe          runs, but no success-rate SLO + no burn-rate alert — add both to slos.md.
  - search_probe         success-rate SLO only — add a latency-under-T SLI (journey works but slow == broken).

Location gaps:
  - login_probe          single location (us-east) — add ≥1 more; can't distinguish regional net fault from outage.

Alert-route gaps:
  - checkout (once added) ensure synthetic failure PAGES on its own route, NOT gated behind white-box error rate.
  - signup_probe         failures route to #synthetics (unwatched) — route to the on-call pager.

Action plan:
  1. Add real journey probes for the uncovered critical paths (API + browser on the top flows).
  2. Give every probe a success-rate + latency probe-SLO with multi-window burn-rate alerts.
  3. Add a second probe location to single-location probes.
  4. Split synthetic failures onto their own page route — never gate on white-box signals.
  5. Rewrite /health-only probes to drive the actual journey.
```

## Halt conditions

- Refuse to call a journey "covered" without a probe script that drives the journey end to end — a `/health` or domain ping does not count.
- Refuse to call a journey "uncovered" without confirming no probe exercises it (grep the synthetic config; cite the absence).
- Halt on "we have synthetics" without naming which journeys have probes and which don't.
- Don't prescribe a probe-SLO number here — the target + window go in `ai/runtime/slos.md`; this skill flags the *absence*, the registry holds the value.
- Don't propose gating a synthetic page behind a white-box condition — that defeats blackbox monitoring; halt and keep the routes separate.

## Related

### Skills
- `alert-audit` — owns alert quality; the synthetic page routes must meet that bar.
- `slo-audit` — the probe-SLO lives in the registry it audits.

### Patterns
- `ai/patterns/slo.md` — the probe-SLO uses this burn-rate method.
- `ai/patterns/metrics.md` — white-box RED/USE, the other half of the split.

### Cross-pack
- `web-vitals-field` (performance pack) — RUM / field measurement, the passive-real-user complement.
