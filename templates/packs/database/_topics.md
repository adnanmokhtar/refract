# Database pack — topic specs (AUTHOR mode)

Schema + semantics: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: schema-architect
  kind: agent
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md § "Data model" + § "Cross-cutting concerns" + db engine AND VERSION (FK auto-indexing, timestamp semantics and the cascade/LOCK=NONE trade differ per engine) + any declared retention/compliance policy (absent one, retention ships as <TBD>, never invented)
  sections: [dispatch, premise_and_halts, preflight, table_and_column_design, index_design, constraints, multi_tenancy, audit_and_compliance, migration_design, output_format, hard_rules, sibling_boundary]
  fallback: _examples/schema-architect.md
  cite_evidence: strict

- name: schema-reviewer
  kind: agent
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md § "Data model" + § Anti-patterns + db engine AND VERSION (the concurrent-write-safety table is per-engine and keyed on operation class, not row count)
  sections: [premise_and_halts, preflight, entity_review, data_access_review, query_review, operation_class_safety, metadata_lock_preflight, approve_gate, example_findings, engine_specific, output_format, hard_rules, sibling_boundary]
  fallback: _examples/schema-reviewer.md

- name: query-optimizer
  kind: agent
  triggers: { orm_detected: true }
  extracts_from: _extracted-idioms.md § (repo base class) + _extracted-codebase.md (slow query log if present) + db engine AND VERSION (plan vocabulary and the online index-build path are engine-specific) + whether pg_stat_statements / performance_schema digest stats are available (the worth-it verdict needs them)
  sections: [premise_and_halts, preflight, method, bottleneck_classification_per_engine, query_rewrites, index_proposal_process, worth_it_verdict, output_format, hard_rules, sibling_boundary]
  fallback: _examples/query-optimizer.md

- name: database-optimizer
  kind: agent
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md § "Data model" (biggest tables by bytes) + db engine AND VERSION + host RAM/storage class + where the LIVE config is read from (parameter group / postgresql.conf / my.cnf) — every finding cites the current value and its source
  sections: [premise_and_halts, boundary_table, preflight, memory_and_cache, reclaim_path_per_engine, storage_tier, diagnosis_table, output_format, hard_rules, forbidden, sibling_boundary]
  fallback: _examples/database-optimizer.md

- name: indexing-strategy
  kind: pattern
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md § "Data model" + sample migrations + § "Data model" (engine + version — the worth-it inputs and the FK-index behaviour are engine-specific)
  sections: [overview, current_indexes_observed, project_query_patterns, worth_it_verdict, index_shape_choice, what_NOT_to_index, detect_existing_problems, foreign_key_index_behaviour, forbidden]
  mirror_existing: true
  fallback: _examples/indexing-strategy.md

- name: migrations
  kind: pattern
  triggers: { migration_dir_detected: true }
  extracts_from: _extracted-codebase.md (migration tool + dir + recent migrations + db engine AND VERSION — the operation class of every statement below is version-specific) + _extracted-idioms.md (repo base if migrations affect tenant filter)
  sections: [overview, project_migration_tool, naming_convention_observed, reversibility, operation_class_per_engine, definition_lock_and_timeout, expand_contract_sequences, examples_from_codebase, pitfalls]
  mirror_existing: true
  fallback: _examples/migrations.md

- name: sharding-partitioning
  kind: pattern
  triggers: { signal_confirmed: multi-tenant, OR: { entity_count_above: 30 } }
  extracts_from: _extracted-codebase.md § "Data model" (largest tables + their primary/unique keys — the unique-key check below cannot be answered without them) + ai/decisions/ (existing partitioning or sharding ADR if any)
  sections: [overview, partitioning_vs_sharding, unique_key_constraint_check, what_partitioning_buys, operational_cost, sharding_threshold_signals, forbidden]
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

# Named `database-principles`, matching rules/database-principles.md — the topic name is what
# validate-pack-consistency check 5 greps for, and `- name: database` (copied from the BACKEND
# pack's own data-access rule, a different file with different sections) left this one unmatched.
- name: database-principles
  kind: rule
  triggers: { orm_detected: true }
  extracts_from: _extracted-idioms.md § (repo base) + _extracted-codebase.md § Conventions + § "Data model" (engine + version — every Must-not below is engine-conditional)
  sections: [project_specific_first, must, must_not, should, review_and_enforcement]
  mirror_existing: true
  fallback: _examples/database-principles.md

- name: add-migration
  kind: command
  triggers: { migration_tool_detected: true }
  extracts_from: _extracted-codebase.md (migration tool + naming + dir + db engine AND VERSION — Phase 2 classifies by operation class, which is version-specific)
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: _examples/add-migration.md

- name: db-audit
  kind: command
  triggers: { orm_detected: true }
  extracts_from: _extracted-codebase.md § "Data model" + db engine (two of the seven checks are a different check per engine, not a translation)
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
  extracts_from: _extracted-codebase.md (migration tool + recent migrations + db engine AND VERSION — a verdict asserts an operation class, which is version-specific)
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
  sections: [purpose, when_to_use, inputs, outputs, the_11_detectors, procedure, hard_rules, failure_modes]
  fallback: skills/schema-consistency-audit/SKILL.md
  cite_evidence: strict
```
