# finops pack — changelog

Release history for `templates/packs/finops/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record.

## 1.0.0 — 2026-08-20

- NEW pack. The infrastructure pack already ships `/cost-audit` — a point-in-time sweep of existing
  resources for idle, over-provisioned, and forgotten spend. This pack deliberately does NOT
  duplicate it. It owns the *discipline* around that sweep: what a unit costs, whose spend it is,
  what the commitment posture should be, what prevents the next surprise, and the cost lens on a
  diff before it merges. `/cost-audit` stays where it is and is cross-referenced from every artifact
  that would otherwise overlap it.
- agents (3): `cost-architect` (opus — pricing dimensions, driver tree, cost at target and 10×
  target, idle floor, exit cost, the trade-off table), `cost-reviewer` (opus — the missing review
  lens: always-on resources, per-row paid calls, retry and fan-out bounds, cross-zone movement,
  retention and log-volume defaults, scan cost, allocation tags), `finops-analyst` (sonnet —
  mechanical: parse the cost/usage export, group by every allocation axis, compute unit costs
  against the declared model, split deltas into rate/usage/mix).
- commands (4): `/cost-model`, `/cost-review`, `/audit-cost-attribution`, `/cost-guardrails`.
- skills (4): `unit-cost-probe`, `commitment-coverage`, `egress-trace`, `spend-anomaly-triage`.
- rules (1): `finops-principles`.
- ai-patterns (4): `unit-economics`, `spend-allocation`, `commitment-strategy`,
  `cost-anomaly-detection`.
- The pack's central discipline is the three-label rule — every cost figure is `measured`,
  `ALLOCATED (basis: <named proxy>)`, or `NOT DERIVABLE — <instrumentation>`. There is no fourth
  label, and an estimate presented as a measurement is treated as a defect, because a fabricated
  number gets quoted in a planning meeting and outlives everyone who knew it was a guess.
- Boundaries stated in every artifact: `infrastructure` `/cost-audit` owns the resource sweep;
  `performance` owns latency and throughput (the same N+1 is often a finding on both sides — the
  lens that produced it is named); `ai-engineering` owns model and token spend discipline, which
  this pack treats as one more billed dependency; `observability` owns alert routing, which cost
  alerts reuse rather than duplicating; `data-engineering`'s `warehouse-scan-audit` owns the SQL
  that produces warehouse spend, and hands the money total here.
