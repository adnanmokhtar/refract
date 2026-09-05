---
name: synthetic-monitoring
description: Audit blackbox / synthetic coverage of critical user journeys — find journeys with no scripted probe, alerting that fires only on white-box signals, probes with no probe-SLO, single-location probes, and probes that ping /health instead of the real journey.
allowed-tools: [Read, Grep, Glob, Bash]
---

# synthetic-monitoring

White-box metrics say the server is healthy. They can't say the user got through checkout. A synthetic probe drives the real journey from outside and catches "everything green, nobody can log in".

## Premise

Every critical user journey (login, checkout, primary CRUD, payment) has a scripted blackbox probe that runs from outside the system on a cadence, from more than one location, with its own probe-SLO and its own alert route. Find the journeys that don't. Every "no probe", "single location", "pings /health not the journey", "no probe-SLO" finding cites the specific journey, the probe config path (or its absence), and the alert rule that does — or does not — page on probe failure. A "synthetic alert only routes to a channel nobody watches" finding cites the route. No hand-waves: if you claim a journey is uncovered, name the journey and show there is no probe script that exercises it end to end.

## When to run

- A new critical journey ships (a new checkout flow, a new signup path) — the probe is part of the definition of done.
- After an incident where internal metrics stayed green but users were blocked (the classic "we found out from Twitter").
- Quarterly journey-coverage review, alongside `alert-audit`.
- On a synthetic-probe PR — same rigor as an alert-rule PR.
- When on-call can't answer "would we page if login broke right now?" with a probe name.

## Adapt to the project's synthetic stack

Extract what's already in use before prescribing:

- **Scripted API + browser synthetics** — k6 (k6 browser + scenarios), Checkly (Playwright-backed, checks-as-code), raw Playwright / Puppeteer synthetics on a scheduler.
- **Vendor synthetic monitoring** — Datadog Synthetic Monitoring, Grafana Cloud Synthetic Monitoring / k6, New Relic Synthetics.
- **Uptime pingers** — Pingdom, UptimeRobot, Better Uptime. Fine for "is the domain up", NOT a substitute for a journey probe (see gotchas).
- **Blackbox exporter** — Prometheus `blackbox_exporter` (HTTP / TCP / ICMP / DNS probes) scraped like any target; multi-target probing via relabeling.
- **Cloud-native** — CloudWatch Synthetics (canaries), Azure Application Insights availability tests, GCP Uptime checks.

Mirror the sibling probes' shape (naming, cadence, region set, SLO convention) rather than inventing a parallel one.

## API vs browser synthetics

- **API synthetics** — hit the endpoints the journey depends on (POST /login → GET /cart → POST /checkout), assert status + body + latency. Cheap, fast, stable; catch backend / contract breakage. Run these at high cadence.
- **Browser synthetics** — drive a real headless browser through the rendered flow (fill the form, click checkout, read the confirmation). Catch what API probes can't: broken JS bundles, a CSP that blocks the payment iframe, a button that no longer submits, an SSR/hydration break. Slower and flakier; run at lower cadence on the top 1-3 journeys.

Most critical journeys want both: an API probe for fast breakage detection and a browser probe for the true user path.

## Probe cadence + multi-location

- **Cadence** — high for API probes (30s-1m), lower for browser probes (2-5m). Fast enough that the probe-SLO's fast-burn alert has samples to burn; not so fast it self-DDoSes a checkout with real side effects (use a synthetic test account / idempotent test-mode path).
- **Multi-location** — probe from ≥2 geographic locations / networks. A failure from one location + success from another = a regional network / CDN / DNS issue, not an app outage. A failure from ALL locations = your outage. A single-location probe can't tell those apart, and a single-location outage will page you for someone else's ISP.

## Probe-SLO — probes get an SLO too

A probe without a target is just a graph. Give each journey probe two SLIs:

- **Probe success rate** — proportion of probe runs that completed the journey and passed every assertion. This is a request-based availability SLI (see `slo.md`); wire multi-window burn-rate alerts on it exactly as for a service SLO.
- **Probe latency** — proportion of probe runs that finished the journey under a threshold T (a *count* under T, not a raw p99 — same framing as any latency SLI). A journey that "works" but takes 40s is a broken journey.

The probe-SLO lives in the live SLO registry (`ai/runtime/slos.md`) next to the service SLOs; the method stays in `slo.md`.

## Blackbox-vs-whitebox alerting split

This is the whole point, so keep the routes separate:

- A **synthetic (blackbox) failure pages on its own**, even when every white-box signal is green. "Login probe failed from 2/2 locations for 3 minutes" is a page regardless of what the internal RED/USE dashboard says — the blackbox is the ground truth of user experience.
- White-box alerts (error rate, saturation, SLO burn) stay on their own routes. They tell you *why*; the synthetic tells you *that the user is blocked*.
- Never gate the synthetic page behind a white-box condition ("only page if error rate is also high") — the entire value is catching the case where internals look fine and users are stuck (bad deploy of a static bundle, expired TLS cert, DNS/CDN misconfig, a downstream the app swallows).

## The boundary with RUM (real-user monitoring)

Synthetic and RUM are complements, not substitutes:

- **Synthetic** = *scripted, active*. A known journey, run on a schedule from controlled locations, on your test account. Deterministic, works with zero live traffic, catches breakage before a real user hits it, isolates "is the path itself broken". It cannot see what real users on real devices/networks actually experience.
- **RUM** = *real users, passive*. Field measurement from actual sessions — real devices, real networks, the long tail of geographies and browsers. Catches "slow for users on 3G in region X" that a synthetic from a datacenter never sees. It cannot alert you at 3am on a journey that has no traffic right now, and it can't run before you ship.

RUM field measurement + attribution is owned by the **performance** pack — see `web-vitals-field` (performance pack). This skill owns the *scripted active probe* and its alerting; it does not audit field CWV. If a finding is "real users see slow LCP", that's the performance pack's `web-vitals-field`, not a synthetic gap.

## Scans for (detectors)

- **Critical journey with no blackbox probe** — checkout / login / payment / primary CRUD has zero scripted probe exercising it end to end. The headline defect.
- **Alerting only on white-box signals** — no alert route fires on synthetic failure; the only signals are internal error rate / saturation. You'll miss "green internals, blocked user".
- **No probe-SLO** — a probe exists but has no success-rate / latency target and no burn-rate alert. It's a dashboard nobody pages on.
- **Single-location probe** — one probe location, so a regional network fault is indistinguishable from an outage (and pages you for someone else's ISP).
- **A probe that only pings `/health`** — the probe hits a liveness/health endpoint (or the bare domain) and calls the journey "covered". `/health` returning 200 says the process is up, not that login works. Flag as *no real journey coverage*.
- **Synthetic alert routed to a dead channel** — the probe fails and files into a channel nobody watches / never pages. Coverage on paper, not in practice.

## Output (illustrative shape)

```
Synthetic coverage — <synthetic backend> + <paging service>

Critical journeys: 6
Covered by a real journey probe: 3
Uncovered / health-only: 3

Uncovered journeys (add a probe):
  - checkout             NO probe — highest-revenue path, blackbox blind. Add API + browser probe, 2 locations.
  - password_reset       probe pings /health only — doesn't exercise the reset flow. Rewrite to drive the journey.
  - guest_checkout       no probe at all.

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

## False positives / gotchas

- An uptime pinger (Pingdom / UptimeRobot on the bare domain) is real coverage for "is the site reachable" — but it is NOT journey coverage. Don't accept "we have Pingdom" as covering checkout; flag the journey gap while crediting the uptime check.
- A `/health` probe is correct *as a liveness check* — don't delete it. Flag only the claim that it covers a user journey.
- A browser synthetic is flakier than an API one; a single red run isn't an outage. Confirm the probe-SLO uses a short confirmation window (per `slo.md`) before calling a probe "noisy".
- A probe that mutates real data (places a real order) is worse than no probe — verify it uses a test account / test-mode / idempotent path before endorsing higher cadence.
- Internal-only services with no external user journey don't need a browser synthetic — an API/TCP blackbox probe is enough. Don't prescribe a browser probe where there's no rendered UI.
- Multi-location noise: if one location flaps constantly on network, that's a probe-location problem, not an app outage — fix the location set, don't page on it.

Invariants this audit enforces: every critical journey has a real scripted probe (not a `/health` ping); every probe runs from ≥2 locations with its own probe-SLO; synthetic failures page on their own route independent of white-box signals; synthetic (active/scripted) and RUM (passive/real-user, performance pack) coverage are both present and not confused for each other.

## Halt conditions

- Refuse to call a journey "covered" without a probe script that drives the journey end to end — a `/health` or domain ping does not count.
- Refuse to call a journey "uncovered" without confirming no probe exercises it (grep the synthetic config; cite the absence).
- Halt on "we have synthetics" without naming which journeys have probes and which don't.
- Don't prescribe a probe-SLO number here — the target + window go in `ai/runtime/slos.md`; this skill flags the *absence*, the registry holds the value. If the registry does not exist yet, the finding is "no probe-SLO" and the fix routes to `/alert-design` Phase 1, which dispatches `slo-audit` to create it. Never invent the number to fill the gap you just reported.
- Don't propose gating a synthetic page behind a white-box condition — that defeats blackbox monitoring; halt and keep the routes separate.

## Related

### Invoked by
- `/alert-design` Phase 2 — dispatched whenever the service in scope owns a critical user journey. Blackbox coverage is one of that command's four alert classes, so an uncovered journey is an alerting gap it must close before COMPLETE, not a separate initiative.

### Skills
- `alert-audit` — owns alert quality (dead / noisy / runbook / owner); the synthetic page routes it audits should meet that bar.
- `slo-audit` — creates the `ai/runtime/slos.md` entries this skill's probe-SLO findings point at.
- `slo-audit` — the probe-SLO lives in the same registry it audits.

### Agents
- `@sre-engineer` — owns probe-SLO / error-budget policy for journey probes.
- `@incident-responder` — a synthetic page is often the first signal in a live incident.
- `@observability-reviewer` — reviews new synthetic-probe PRs at the code-change level.

### Patterns
- `ai/patterns/slo.md` — the probe-SLO uses this burn-rate method.
- `ai/patterns/metrics.md` — white-box RED/USE, the other half of the blackbox-vs-whitebox split.

### Cross-pack
- `web-vitals-field` (performance pack) — RUM / field measurement, the passive-real-user complement to this skill's active-scripted probes. The RUM boundary.
