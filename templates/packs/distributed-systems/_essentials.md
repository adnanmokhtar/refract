---
track: distributed-systems
purpose: Design and review patterns for resilient multi-service architectures.
essentials:
  agents: [resilience-reviewer]
  commands: [design-system]
  skills: []
  rules: [distributed-principles]
  ai-patterns: [idempotency]
---

# Distributed-systems — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: resilience-reviewer is the broad reviewer; system-architect/event-sourcing-architect/workflow-orchestrator are specialists kept out of minimal.
- commands: design-system is the only command — the entry point for architectural work.
- skills: none essential — chaos-test is advanced and project-specific.
- rules: distributed-principles is the single rules file in the pack.
- ai-patterns: idempotency is the universal must-have; CQRS, sagas, outbox, event-sourcing, circuit-breaker are situational.
