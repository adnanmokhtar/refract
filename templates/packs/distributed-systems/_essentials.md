---
track: distributed-systems
purpose: Design and review patterns for resilient multi-service architectures.
essentials:
  agents: [resilience-reviewer]
  commands: [design-system, ds-audit, ds-fix]
  skills: [messaging-scan, dual-write-scan]
  rules: [distributed-principles]
  ai-patterns: [idempotency]
---

# Distributed-systems — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: resilience-reviewer is the broad reviewer; system-architect (qualitative boundaries + ADRs), capacity-planner (quantitative — back-of-envelope estimation, bottleneck ledger, scaling strategy, migration-at-scale cutover; the system-design pair with system-architect), event-sourcing-architect, workflow-orchestrator are specialists kept out of minimal.
- commands: design-system is the entry point for architectural work; ds-audit (find, judge, rank) and ds-fix (failing-first fix per finding) are the audit pair every pack ships. Under `--minimal`, ds-audit runs the two essential detectors and prints the other four `not run (detector absent)` where their surface exists, so a whole-repo verdict is GO-UNVERIFIED until standard mode installs them; workflow and event-contract rows have no judge there and go to `@verifier`.
- skills: messaging-scan and dual-write-scan cover the two classes that lose or duplicate data (an ack before the effect, a consumer with no reserve, a publish after commit with nothing durable); messaging-scan carries scripts/ds-inventory.py, which retry-deadline-scan also reads. retry-deadline-scan, coordination-scan, workflow-scan and event-contract-scan are signal-gated and kept out of minimal; chaos-test and dlq-replay are advanced and project-specific.
- rules: distributed-principles is the single rules file in the pack.
- ai-patterns: idempotency is the universal must-have; CQRS, sagas (now with the isolation countermeasures), outbox, event-sourcing, circuit-breaker are situational. consistency-models (CAP/PACELC + the ladder + delivery semantics), distributed-lock (fencing tokens / Redlock caveat), sharding-partitioning, and backpressure (bounded queues / load-shedding / bulkhead) close the consistency+coordination+scale half a system designer needs.
