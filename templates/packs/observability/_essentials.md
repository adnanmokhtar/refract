---
track: observability
purpose: Logging, metrics, tracing, and incident response wiring.
essentials:
  agents: [observability-reviewer, telemetry-architect]
  commands: [add-telemetry, obs-audit, obs-fix]
  skills: [log-signal-scan, trace-propagation-scan, metric-hygiene-scan, error-tracking-scan, alert-rule-lint, slo-rule-scan, telemetry-config-scan, alert-audit, synthetic-monitoring]
  rules: [observability-principles]
  ai-patterns: [structured-logging]
---

# Observability — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: `observability-reviewer` is the judge that grades the seven detectors' rows (it runs them through the Skill tool on a diff); `telemetry-architect` is here because `/add-telemetry` Phase 4 dispatches it — a minimal install without it ships a command that cannot reach its own generate step.
- commands: `add-telemetry` is the only creation command — the day-one entry point, and the owner of the ledger the two narrow entry points route back to; `obs-audit` is the pack's audit and `obs-fix` the loop that closes its findings, so a minimal install can find and fix what it instruments.
- skills: the seven detectors (`log-signal-scan`, `trace-propagation-scan`, `metric-hygiene-scan`, `error-tracking-scan`, `alert-rule-lint` with `rule-inventory.py`, `slo-rule-scan` with `burn-check.py`, `telemetry-config-scan`), because `/obs-audit` dispatches every one on a whole-repo run and `@observability-reviewer` judges their rows; `burn-check.py` imports `rule-inventory.py`, so `slo-rule-scan` needs `alert-rule-lint` beside it. `alert-audit` because `/add-telemetry`'s closure gate dispatches it after `alert-rule-lint`. `synthetic-monitoring` because `/obs-audit` treats a `not run` Synthetic coverage row as GO-UNVERIFIED, so a minimal install without it could never reach GO. `slo-audit` is standard-mode only: `/obs-audit` prints its SLO-attainment row `not run (detector absent)`, one of the rows exempt from that rule, and `/alert-design` (which writes the registry through it) is not minimal either.
- rules: `observability-principles` is the single rules file in the pack.
- ai-patterns: `structured-logging` is the foundational pattern (it carries the per-logger error-argument table `log-signal-scan` §2 fixes against); `metrics` / `tracing` build on it, and `slo` / `audit-logging` / `profiling` are signal-gated — all kept out of minimal.

Cross-pack boundaries this pack asserts live in `STACK.md`, not here.
