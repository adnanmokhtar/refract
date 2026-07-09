---
track: observability
purpose: Logging, metrics, tracing, and incident response wiring.
essentials:
  agents: [observability-reviewer]
  commands: [add-telemetry]
  skills: []
  rules: [observability-principles]
  ai-patterns: [structured-logging]
---

# Observability — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: observability-reviewer is the universal auditor; sre-engineer/incident-responder/telemetry-architect are specialists kept out of minimal.
- commands: add-telemetry is the only creation command — the day-one entry point.
- skills: none essential — alert-audit becomes useful only once telemetry exists.
- rules: observability-principles is the single rules file in the pack.
- ai-patterns: structured-logging is the foundational pattern; metrics/tracing build on it and are kept out of minimal. slo (SLI/error-budget/multi-window burn-rate — resolves the previously-dangling slo.md), audit-logging (tamper-evident compliance trail — the target backend OBS-1 + security A09 defer here; security owns WHAT, observability owns the pipeline), and profiling (continuous production profiling — the 4th signal, distinct from performance's dev-time profiling) are signal-gated. Boundary: observability owns RUM ingestion/retention (performance owns field-CWV measurement) + the trace HOW (distributed-systems owns trace-coverage-as-SLO).
