---
track: observability
purpose: Logging, metrics, tracing, and incident response wiring.
essentials:
  agents: [observability-reviewer, telemetry-architect]
  commands: [add-telemetry]
  skills: [alert-audit]
  rules: [observability-principles]
  ai-patterns: [structured-logging]
---

# Observability — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: `observability-reviewer` is the universal auditor; `telemetry-architect` is here because `/add-telemetry` Phase 4 dispatches it — a minimal install without it ships a command that cannot reach its own generate step.
- commands: `add-telemetry` is the only creation command — the day-one entry point, and the owner of the ledger the two narrow entry points route back to.
- skills: `alert-audit` only, because `/add-telemetry`'s closure gate requires its dispatch to return clean; without it that command can never compute COMPLETE.
- rules: `observability-principles` is the single rules file in the pack.
- ai-patterns: `structured-logging` is the foundational pattern; `metrics` / `tracing` build on it, and `slo` / `audit-logging` / `profiling` are signal-gated — all kept out of minimal.

Cross-pack boundaries this pack asserts live in `STACK.md`, not here.
