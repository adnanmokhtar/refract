# Database pack — topic specs (AUTHOR mode)

Schema + semantics: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: schema-architect
  kind: agent
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md § "Data model" + § "Cross-cutting concerns"
  sections: [persona, when_to_invoke, preflight_reading, methodology, schema_decisions_for_this_codebase, output_format, verification]
  fallback: _examples/schema-architect.md
  cite_evidence: strict

- name: schema-reviewer
  kind: agent
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md § "Data model" + § Anti-patterns
  sections: [persona, review_checklist, project_specific_constraints, output_format]
  fallback: _examples/schema-reviewer.md

- name: query-optimizer
  kind: agent
  triggers: { orm_detected: true }
  extracts_from: _extracted-idioms.md § (repo base class) + _extracted-codebase.md (slow query log if present)
  sections: [persona, methodology, explain_analyze_recipe, n_plus_one_signals, indexing_decisions, output_format]
  fallback: _examples/query-optimizer.md

- name: database-optimizer
  kind: agent
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md § "Data model" (entity count, biggest tables) + recent activity (migrations)
  sections: [persona, schema_optimization, partitioning_decisions, archival_strategy, output_format]
  fallback: _examples/database-optimizer.md

- name: indexing-strategy
  kind: pattern
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md § "Data model" + sample migrations
  sections: [overview, current_indexes_observed, project_query_patterns, what_to_index, what_NOT_to_index, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/indexing-strategy.md

- name: migrations
  kind: pattern
  triggers: { migration_dir_detected: true }
  extracts_from: _extracted-codebase.md (migration tool + dir + recent migrations) + _extracted-idioms.md (repo base if migrations affect tenant filter)
  sections: [overview, project_migration_tool, naming_convention_observed, reversibility, online_vs_offline, locking_concerns, examples_from_codebase, pitfalls]
  mirror_existing: true
  fallback: _examples/migrations.md

- name: sharding-partitioning
  kind: pattern
  triggers: { signal_confirmed: multi-tenant, OR: { entity_count_above: 30 } }
  extracts_from: _extracted-codebase.md § "Data model" (largest tables) + ai/decisions/ (existing sharding ADR if any)
  sections: [overview, current_state, when_we_will_shard, sharding_key_candidates, partitioning_strategy, migration_path]
  fallback: _examples/sharding-partitioning.md

- name: transaction-isolation
  kind: pattern
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md (db engine + version) + _extracted-idioms.md § (repo base / unit-of-work) + hot read-modify-write paths (balance/inventory/counter/job-queue)
  sections: [overview, isolation_levels, pessimistic_locking, optimistic_locking, deadlock_avoidance, advisory_locks, mvcc_bloat, retry_on_serialization_failure, write_skew, detectors]
  mirror_existing: true
  fallback: _examples/transaction-isolation.md

- name: data-retention-pii
  kind: pattern
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md § "Data model" (PII-bearing tables + FK graph) + migration history (retention/partition schemes) + db engine
  sections: [overview, pii_classification, retention_enforcement, erasure_vs_anonymization, erasure_fk_cascade, encryption_at_rest, backups_replicas_derived, detectors]
  mirror_existing: true
  fallback: _examples/data-retention-pii.md

- name: full-text-search
  kind: pattern
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md (db engine + version) + text columns + search endpoints (LIKE '%..%' usages)
  sections: [overview, fts_primitive_and_index, maintenance_rule, gin_vs_gist, ranking_phrase_prefix, fuzzy_trgm, mysql_fulltext, graduate_to_external, adapt, detectors]
  mirror_existing: true
  fallback: _examples/full-text-search.md

- name: connection-pooling
  kind: pattern
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md (db engine + server max_connections) + _extracted-idioms.md (driver/pool config) + deploy topology (instance/replica count)
  sections: [overview, sizing, pooler_modes, exhaustion_symptoms, serverless, idle_lifetime_validation, held_across_external_call, adapt, detectors]
  mirror_existing: true
  fallback: _examples/connection-pooling.md

- name: read-replicas
  kind: pattern
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md (db engine + version + replication mode) + read/write routing config + read-heavy query paths
  sections: [overview, topology_replication_mode, lag_reality, read_your_writes, routing_strategies, lag_monitoring_failover, stale_read_blast_radius, adapt, detectors]
  mirror_existing: true
  fallback: _examples/read-replicas.md

- name: database
  kind: rule
  triggers: { orm_detected: true }
  extracts_from: _extracted-idioms.md § (repo base) + _extracted-codebase.md § Conventions
  sections: [project_specific_first, queries_through_repo, parameterized_only, soft_delete_filter, tenant_filter, never_inject_dataSource, examples_anti_patterns]
  mirror_existing: true
  fallback: _examples/database-principles.md

- name: add-migration
  kind: command
  triggers: { migration_tool_detected: true }
  extracts_from: _extracted-codebase.md (migration tool + naming + dir)
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: _examples/add-migration.md

- name: db-audit
  kind: command
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md § "Data model"
  sections: [understand, retrieve, generate]
  fallback: _examples/db-audit.md

- name: optimize-query
  kind: command
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md (db engine + query analysis tool)
  sections: [understand, retrieve, validate]
  fallback: _examples/optimize-query.md

- name: migration-review
  kind: command
  triggers: { migration_tool_detected: true }
  extracts_from: _extracted-codebase.md (migration tool + recent migrations)
  sections: [understand, retrieve, generate]
  fallback: _examples/migration-review.md

- name: schema-diff
  kind: skill
  triggers: { orm_detected: true }
  fallback: _examples/schema-diff.md

- name: migration-rehearsal
  kind: skill
  triggers: { migration_tool_detected: true }
  fallback: _examples/migration-rehearsal.md

- name: schema-consistency-audit
  kind: skill
  triggers: { db_introspection_available: true }
  extracts_from: _extracted-idioms.md § "Schema conventions" + ai/schema-conventions.md + migration history
  sections: [purpose, when_to_use, inputs, outputs, the_12_detectors, procedure, hard_rules, failure_modes]
  fallback: skills/schema-consistency-audit.md
  cite_evidence: strict
```
