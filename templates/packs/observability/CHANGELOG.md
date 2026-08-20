# observability pack — changelog

Release history for `templates/packs/observability/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.3.0 — 2026-07-10

- add-telemetry: static thresholds replaced with SLO burn-rate alerts (fast 1h/14x page · slow 6h/6x
  ticket); alert-design REQUIRED actionability ledger (per-alert SLO/SLI + burn window +
  runbook-file-exists).
- observability-reviewer: emit-and-assert closure verb BLOCKs Status: COMPLETE when the
  ledger/assertions are missing.

## 1.2.1 — 2026-07-10

- add-telemetry: emit-and-assert gates for metrics (scrape /metrics, assert new series) and traces
  (log-in-span, assert trace_id/span export) + a logs field-assertion — all four primitives now have
  an executable verification gate, not just alerts.

## 1.2.0 — 2026-07-10

- skill +1: synthetic-monitoring (blackbox critical-journey probes + probe-SLO, catches 'server
  healthy, user path broken'); ai-pattern +1: dashboards (tiered RED/USE dashboards-as-code +
  alert-to-panel linkage).

## 1.1.0 — 2026-07-09

- NEW ai-patterns/slo.md (resolves the slo.md dangling in sre-engineer/incident-responder/metrics —
  SLI menu, error budget, two-tier multi-window multi-burn-rate 14.4x@1h page / 6x@6h ticket,
  SLO-as-code, pattern-vs-runtime-registry split, detectors). NEW audit-logging.md (tamper-evident
  append-only/WORM + hash-chain, actor/subject/action/before-after/IP schema, retention-by-regime
  SOC2/PCI 1y / HIPAA 6y / SOX 7y, must-not-redact, security-owns-WHAT/observability-owns-pipeline
  boundary, detectors) — closes the backend OBS-1 audit-log deferral that landed on one line. NEW
  profiling.md (continuous production profiling as the 4th signal —
  eBPF/Pyroscope/Parca/OTel-profiles, CPU/heap/alloc/lock, flame-graph self-time, exemplar->profile
  linkage, perf-owns-adhoc/obs-owns-always-on boundary). Registered all three in _topics +
  _essentials.
- metrics.md: native (Prometheus GA 2024) + OTel exponential histograms noted as the
  auto-scaling-bucket alternative to the fixed-bucket trade-off.
- observability-reviewer.md: added the hand-wave token hard-halt + verdict-matches-body clauses + a
  coverage/pass-fail table + literal rg commands. rules/observability-principles.md: slow-burn 24h
  -> 6h (canonical Google window; +example mirror). telemetry-architect.md -> model:opus, 3-pillars
  reframed to logs/metrics/traces+profiling, NEW RUM/client-telemetry method + cross-pack boundary.
  sre-engineer/incident-responder: +slo/audit-logging/profiling Related + Skills subsections.
  alert-audit/slo-audit: ## Related + name-frontmatter + house headings. tracing.md: reciprocal
  distributed-systems trace-boundary link.
