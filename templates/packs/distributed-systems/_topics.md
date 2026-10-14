# Distributed-systems pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: system-architect
  kind: agent
  triggers: { repo_shape: monorepo, OR: { signal_confirmed_any: [event-sourced, real-time, background-jobs] } }
  extracts_from: _extracted-codebase.md § Architecture + § "Repository shape" + § "Cross-cutting concerns"
  sections: [persona, current_topology, service_boundaries, data_consistency_decisions, communication_patterns, output_format]
  fallback: _examples/system-architect.md   # generated-from copy of agents/system-architect.md (COPY-DRIFT gated)
  cite_evidence: strict

- name: resilience-reviewer
  kind: agent
  triggers: { service_count_above_1: true }
  extracts_from: _extracted-codebase.md § Modules + § "Cross-cutting concerns"
  sections: [persona, failure_modes_for_this_app, retry_idempotency_check, circuit_breaker_check, output_format]
  fallback: _examples/resilience-reviewer.md   # generated-from copy of agents/resilience-reviewer.md (COPY-DRIFT gated)

- name: capacity-planner
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § "Scale targets" + SLO + datastore + § Modules (write-path)
  sections: [persona, capacity_model, bottleneck_ledger, scaling_strategy, migration_cutover, output_format]
  fallback: _examples/capacity-planner.md   # generated-from copy of agents/capacity-planner.md (COPY-DRIFT gated)
  cite_evidence: strict

- name: event-sourcing-architect
  kind: agent
  triggers: { signal_confirmed: event-sourced }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" § event-sourced + sample aggregates
  sections: [persona, aggregate_design, event_versioning, snapshot_strategy, projection_strategy, output_format]
  fallback: _examples/event-sourcing-architect.md   # generated-from copy of agents/event-sourcing-architect.md (COPY-DRIFT gated)

- name: workflow-orchestrator
  kind: agent
  triggers: { signal_confirmed: background-jobs, OR: { signal_confirmed: workflow-orchestration } }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" + sample workflows
  sections: [persona, orchestration_engine, saga_vs_choreography, retry_strategy, output_format]
  fallback: _examples/workflow-orchestrator.md   # generated-from copy of agents/workflow-orchestrator.md (COPY-DRIFT gated)

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
  fallback: _examples/outbox.md   # generated-from copy of ai-patterns/outbox.md (COPY-DRIFT gated)

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
  fallback: _examples/idempotency.md   # generated-from copy of ai-patterns/idempotency.md (COPY-DRIFT gated)

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
  fallback: skills/chaos-test/SKILL.md   # source-as-fallback: the old abridged copy ran bare kubectl against the default context

- name: add-event-handler
  kind: command
  triggers: { service_count_above_1: true, OR: { signal_confirmed: event-sourced } }
  fallback: commands/add-event-handler.md   # source-as-fallback (phase-4.2-apply.md step 2). Was `stub-from-sections` with NO `sections:` list, so step 2 had nothing to build a stub FROM and greenfield received an EMPTY FILE while the finished 183-line command sat beside it on disk.

- name: add-saga
  kind: command
  triggers: { service_count_above_1: true }
  fallback: commands/add-saga.md   # source-as-fallback — was `stub-from-sections` with no `sections:` list, i.e. an empty file on greenfield.

- name: audit-distributed-tx
  kind: command
  triggers: { service_count_above_1: true }
  fallback: commands/audit-distributed-tx.md   # source-as-fallback — was `stub-from-sections` with no `sections:` list, i.e. an empty file on greenfield.

- name: dlq-replay
  kind: skill
  triggers: { signal_confirmed: background-jobs, OR: { service_count_above_1: true } }   # same trigger as audit-distributed-tx, which names it for DLQ rows (it no longer halts without it)
  fallback: skills/dlq-replay/SKILL.md   # source-as-fallback — was `stub-from-sections` with no `sections:` list, i.e. an empty file on greenfield.

- name: messaging-scan
  kind: skill
  triggers:
    signal_confirmed_any: [background-jobs, event-sourced]
    OR_grep_evidence: "\"(bullmq|bull|kafkajs|@confluentinc/kafka-javascript|amqplib|sqs-consumer|@aws-sdk/client-sqs|nats|@nats-io/jetstream|@google-cloud/pubsub)\"\\s*:|^\\s*(celery|kombu|dramatiq)\\b|gem ['\"](sidekiq|solid_queue|good_job)['\"]|spring-kafka|spring-rabbit|MassTransit|confluent-kafka-go|segmentio/kafka-go|twmb/franz-go|IBM/sarama|nats\\.go"   # a broker client in any manifest: the consumer and producer semantics are the subject
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" (queues, brokers and their client versions) + sample consumers and producers
  fallback: skills/messaging-scan/SKILL.md   # source-as-fallback; stacks.md and scripts/ds-inventory.py ship beside it

- name: coordination-scan
  kind: skill
  triggers:
    signal_confirmed_any: [background-jobs]
    OR_grep_evidence: "\"(redlock|redlock-universal|@nestjs/schedule|node-cron|node-schedule|@kubernetes/client-node)\"\\s*:|['\"]NX['\"]|\\bpg_(try_)?advisory_|redisson|shedlock|go-redsync|k8s\\.io/client-go|DistributedLock|celery-redbeat|apscheduler"   # a lock primitive, a leader election or a scheduler library: the lock mechanics and the time decisions are the subject
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" (locks, leader keys, schedulers, the process time zone) + sample lock helpers
  fallback: skills/coordination-scan/SKILL.md   # source-as-fallback; stacks.md ships beside it

- name: dual-write-scan
  kind: skill
  triggers:
    signal_confirmed_any: [background-jobs, event-sourced]
    OR_grep_evidence: "[Oo]utbox|\"(bullmq|kafkajs|@confluentinc/kafka-javascript|amqplib|@aws-sdk/client-(sqs|sns|eventbridge|kinesis)|nats|@nats-io/jetstream|@google-cloud/pubsub|@nestjs/cqrs)\"\\s*:|^\\s*(celery|kombu)\\b|gem ['\"](sidekiq|solid_queue|good_job)['\"]|spring-kafka|spring-rabbit|spring-modulith-events|MassTransit|debezium|confluent-kafka-go|segmentio/kafka-go|ThreeDotsLabs/watermill"   # a database write that may be published: an outbox store, a broker client, an in-process event bus or CDC
  extracts_from: _extracted-codebase.md § "Data model" (outbox, inbox and processed-message tables) + § "Cross-cutting concerns" (brokers, ORM) + sample use cases that write then publish
  fallback: skills/dual-write-scan/SKILL.md   # source-as-fallback

- name: retry-deadline-scan
  kind: skill
  triggers:
    signal_confirmed_any: [background-jobs, event-sourced]
    OR_grep_evidence: "\"(axios-retry|p-retry|async-retry|exponential-backoff|cockatiel|got|bullmq|@aws-sdk/client-[a-z0-9-]+|@grpc/grpc-js|@temporalio/client)\"\\s*:|^\\s*(tenacity|backoff|stamina|celery|grpcio)\\b|Polly|Microsoft\\.Extensions\\.Http\\.Resilience|resilience4j|spring-retry|spring-kafka|go-retryablehttp|cenkalti/backoff|retry-go|MassTransit|gem ['\"](sidekiq|faraday-retry|retriable)['\"]"   # a retry library, an SDK that retries by itself, or a job system whose attempts are an outer layer
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" (outbound clients, retry policies, job options, deadlines) + the shared outbound client or kernel
  fallback: skills/retry-deadline-scan/SKILL.md   # source-as-fallback; F2 reuses messaging-scan's scripts/ds-inventory.py

- name: workflow-scan
  kind: skill
  triggers:
    signal_confirmed_any: [background-jobs, event-sourced]
    OR_grep_evidence: "\"(@temporalio/workflow|@restatedev/restate-sdk|@dbos-inc/dbos-sdk|inngest|durable-functions|@aws-sdk/client-sfn|@camunda8/sdk|zeebe-node|@nestjs/cqrs)\"\\s*:|go\\.temporal\\.io/sdk|^\\s*(temporalio|azure-functions-durable|dbos)\\b|Temporalio|Microsoft\\.DurableTask|temporal-sdk|eventuate-tram-sagas|MassTransit|\\bFlowProducer\\b|addCompensation\\(|\\.withCompensation\\("   # a durable workflow SDK or engine, a BullMQ flow, or a saga framework or helper
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" (workflow engines, sagas, state machines) + sample workflow, activity and saga files
  fallback: skills/workflow-scan/SKILL.md   # source-as-fallback

- name: event-contract-scan
  kind: skill
  triggers:
    signal_confirmed_any: [event-sourced]
    OR_grep_evidence: "\"(@bufbuild/buf|protobufjs|avsc|@kafkajs/confluent-schema-registry|@confluentinc/schemaregistry|@asyncapi/cli|@asyncapi/parser|@pact-foundation/pact|@kurrent/kurrentdb-client|@eventstore/db-client|@event-driven-io/emmett|@nestjs/cqrs)\"\\s*:|^asyncapi:|Marten|KurrentDB\\.Client|EventStore\\.Client|Confluent\\.SchemaRegistry|kafka-avro-serializer|kafka-protobuf-serializer|spring-cloud-contract|au\\.com\\.dius\\.pact|PactNet|axon-|^\\s*(kurrentdbclient|esdbclient|eventsourcing|fastavro|pact-python)\\b"   # an event schema format, a schema registry, a contract-test tool, or an event store: the event contracts and the store's concurrency are the subject
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" (event schemas, registries, event stores, projections) + sample producers, consumers and aggregates
  fallback: skills/event-contract-scan/SKILL.md   # source-as-fallback; stacks.md ships beside it

- name: ds-audit
  kind: command
  # always: each of the six detectors it dispatches carries its own gate (no broker client, no outbox, no lock
  # helper, no workflow SDK, no schema file) and prints N/A for an absent surface, and the pack itself installs
  # only on a distributed signal — a capability-gated trigger here would only withhold the audit
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" (broker, cache, lock, retry and workflow-SDK clients with versions; broker images and managed services — a managed server's settings are UNREAD) + § Deploy (process types, replicas, autoscalers, TZ) + § "Data model" (outbox, inbox, claims and event-store tables) + schema files, the container harness and the CI replay and contract gates
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: commands/ds-audit.md   # the source IS the fallback, as for obs-audit, devops-audit and db-audit; the six-detector dispatch, the outbox-writer pre-flight before dual-write §1, the three-judge hand-off, the fixed class ledger, the runtime lane on named sources only and the six GO-critical controls are the contract

- name: ds-fix
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" (broker and store versions the throwaway containers must match) + the shared roots (base processor, producer wrapper, outbox port, lock helper, retry constant)
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: commands/ds-fix.md   # the source IS the fallback, as for obs-fix and devops-fix; a skeleton would drop the throwaway-broker rule, the loss probe, the loss-trade grep and the delivery-guarantee, DLQ, money-path TTL and consumed-schema STOP lines
```
