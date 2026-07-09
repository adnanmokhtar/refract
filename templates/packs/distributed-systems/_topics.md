# Distributed-systems pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: system-architect
  kind: agent
  triggers: { repo_shape: monorepo, OR: { signal_confirmed_any: [event-sourced, real-time, background-jobs] } }
  extracts_from: _extracted-codebase.md § Architecture + § "Repository shape" + § "Cross-cutting concerns"
  sections: [persona, current_topology, service_boundaries, data_consistency_decisions, communication_patterns, output_format]
  fallback: _examples/system-architect.md
  cite_evidence: strict

- name: resilience-reviewer
  kind: agent
  triggers: { service_count_above_1: true }
  extracts_from: _extracted-codebase.md § Modules + § "Cross-cutting concerns"
  sections: [persona, failure_modes_for_this_app, retry_idempotency_check, circuit_breaker_check, output_format]
  fallback: _examples/resilience-reviewer.md

- name: capacity-planner
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § "Scale targets" + SLO + datastore + § Modules (write-path)
  sections: [persona, capacity_model, bottleneck_ledger, scaling_strategy, migration_cutover, output_format]
  fallback: _examples/capacity-planner.md
  cite_evidence: strict

- name: event-sourcing-architect
  kind: agent
  triggers: { signal_confirmed: event-sourced }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" § event-sourced + sample aggregates
  sections: [persona, aggregate_design, event_versioning, snapshot_strategy, projection_strategy, output_format]
  fallback: _examples/event-sourcing-architect.md

- name: workflow-orchestrator
  kind: agent
  triggers: { signal_confirmed: background-jobs, OR: { signal_confirmed: workflow-orchestration } }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" + sample workflows
  sections: [persona, orchestration_engine, saga_vs_choreography, retry_strategy, output_format]
  fallback: _examples/workflow-orchestrator.md

- name: saga
  kind: pattern
  triggers: { signal_confirmed_any: [event-sourced, payment, background-jobs] }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" + sample saga code if any
  sections: [overview, saga_pattern_in_use, compensation_actions, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/saga.md

- name: outbox
  kind: pattern
  triggers: { signal_confirmed_any: [event-sourced, background-jobs] }
  extracts_from: _extracted-codebase.md § "Data model" (outbox table presence) + sample handlers
  sections: [overview, outbox_table, dispatcher_strategy, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/outbox.md

- name: cqrs
  kind: pattern
  triggers: { signal_confirmed: event-sourced }
  fallback: _examples/cqrs.md

- name: event-sourcing
  kind: pattern
  triggers: { signal_confirmed: event-sourced }
  fallback: _examples/event-sourcing.md

- name: reconciliation
  kind: pattern
  triggers: { signal_confirmed: event-sourced, OR: { service_count_above_1: true } }
  fallback: _examples/reconciliation.md

- name: idempotency
  kind: pattern
  triggers: { signal_confirmed_any: [webhook, payment, background-jobs] }
  extracts_from: _extracted-codebase.md (idempotency-key handling if detected)
  sections: [overview, idempotency_key_strategy, dedup_window, retry_safe_operations, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/idempotency.md

- name: circuit-breaker
  kind: pattern
  triggers: { external_dependency_count_above_2: true }
  fallback: _examples/circuit-breaker.md

- name: consistency-models
  kind: pattern
  triggers: { service_count_above_1: true }
  fallback: _examples/consistency-models.md

- name: distributed-lock
  kind: pattern
  triggers: { grep_evidence: "distributed lock|Redlock|SETNX|advisory_lock|SELECT .*FOR UPDATE|fencing|lease" }
  fallback: _examples/distributed-lock.md

- name: sharding-partitioning
  kind: pattern
  triggers: { signal_confirmed: high-scale }
  fallback: _examples/sharding-partitioning.md

- name: backpressure
  kind: pattern
  triggers: { service_count_above_1: true }
  fallback: _examples/backpressure.md

- name: distributed-principles
  kind: rule
  triggers: { service_count_above_1: true, OR: { signal_confirmed: event-sourced } }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns"
  sections: [project_specific_first, idempotent_handlers, retry_with_backoff, no_distributed_transactions, observability_required]
  mirror_existing: true
  fallback: _examples/distributed-principles.md

- name: design-system
  kind: command
  triggers: { service_count_above_1: true }
  fallback: _examples/design-system.md

- name: chaos-test
  kind: skill
  triggers: { service_count_above_1: true }
  fallback: _examples/chaos-test.md

- name: add-event-handler
  kind: command
  triggers: { service_count_above_1: true, OR: { signal_confirmed: event-sourced } }
  fallback: stub-from-sections   # ships in commands/; no _examples sibling

- name: add-saga
  kind: command
  triggers: { service_count_above_1: true }
  fallback: stub-from-sections

- name: audit-distributed-tx
  kind: command
  triggers: { service_count_above_1: true }
  fallback: stub-from-sections

- name: dlq-replay
  kind: skill
  triggers: { signal_confirmed: background-jobs }
  fallback: stub-from-sections
```
