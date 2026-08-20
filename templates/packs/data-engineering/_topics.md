# Data-engineering pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: warehouse-modeler
  kind: agent
  triggers: { signal_confirmed_any: [data-pipeline, analytics, reporting] }
  extracts_from: _extracted-codebase.md § Modules (warehouse/model directories) + § Data layer (analytical tables, partition + cluster keys)
  sections: [persona, halt_conditions, model_inventory_and_grain, fact_and_dimension_review, join_cardinality, conformance, output_format]
  mirror_existing: true
  fallback: _examples/warehouse-modeler.md
  cite_evidence: strict

- name: analytics-engineer
  kind: agent
  triggers: { signal_confirmed_any: [data-pipeline, analytics, reporting] }
  extracts_from: _extracted-idioms.md § <role:transformation-model> + _extracted-codebase.md § Modules (layer directories, reference function, materialization defaults)
  sections: [persona, halt_conditions, layer_map_in_this_project, materialization_decisions, incremental_correctness, metric_definitions, output_format]
  mirror_existing: true
  fallback: _examples/analytics-engineer.md
  cite_evidence: strict

- name: data-quality-auditor
  kind: agent
  triggers: { signal_confirmed_any: [data-pipeline, analytics, reporting] }
  extracts_from: _extracted-codebase.md § Tests (assertion framework + placement) + § Data layer (models, owners, freshness expectations)
  sections: [persona, halt_conditions, four_floors_in_this_project, severity_and_routing, coverage_ledger, output_format]
  mirror_existing: true
  fallback: _examples/data-quality-auditor.md

- name: dag-reviewer
  kind: agent
  triggers: { signal_confirmed_any: [data-pipeline, background-jobs] }
  extracts_from: _extracted-codebase.md § Modules (orchestration definitions) + § Cross-cutting concerns (schedules, retries, pools)
  sections: [persona, halt_conditions, per_task_scan, dag_level_scan, output_format]
  mirror_existing: true
  fallback: _examples/dag-reviewer.md

- name: dimensional-model
  kind: pattern
  triggers: { signal_confirmed_any: [data-pipeline, reporting] }
  extracts_from: _extracted-codebase.md § Data layer (analytical tables + their keys) + _extracted-idioms.md § <role:fact-model>
  sections: [overview, grain_declaration, fact_types_in_this_project, measure_additivity, keys_and_scd, conformed_dimensions, cardinality, physical_layout, detectors]
  mirror_existing: true
  fallback: _examples/dimensional-model.md
  cite_evidence: strict

- name: transformation-layers
  kind: pattern
  triggers: { signal_confirmed_any: [data-pipeline, analytics, reporting] }
  extracts_from: _extracted-idioms.md § <role:transformation-model> + _extracted-codebase.md § Modules (layer directory shape)
  sections: [overview, layers_in_this_project, materialization_decision_table, incremental_declarations, naming_and_exposure, detectors]
  mirror_existing: true
  fallback: stub-from-sections

- name: data-contract
  kind: pattern
  triggers: { signal_confirmed_any: [data-pipeline, analytics, reporting] }
  extracts_from: _extracted-codebase.md § Cross-cutting concerns (external sources + their owners) + § API surface (published datasets)
  sections: [overview, what_a_contract_declares, change_classes, hunting_semantic_breaks, notice_and_migration, enforcement_points, detectors]
  mirror_existing: true
  fallback: stub-from-sections

- name: data-quality-tests
  kind: pattern
  triggers: { signal_confirmed_any: [data-pipeline, reporting] }
  extracts_from: _extracted-codebase.md § Tests (assertion framework) + § Data layer (models + owners)
  sections: [overview, structural_floor, temporal_floor, distributional_floor, reconciliation_floor, severity_and_routing, threshold_derivation, detectors]
  mirror_existing: true
  fallback: stub-from-sections

- name: semantic-layer
  kind: pattern
  triggers: { signal_confirmed_any: [analytics, reporting] }
  extracts_from: _extracted-codebase.md § Modules (metric definitions / BI model files) + ai/business-domain.md (metric vocabulary)
  sections: [overview, why_a_metric_drifts, definition_contents, altitude_choice, additivity, changing_a_definition, detectors]
  mirror_existing: true
  fallback: stub-from-sections

- name: data-engineering-principles
  kind: rule
  triggers: { signal_confirmed_any: [data-pipeline, analytics, reporting] }
  extracts_from: _extracted-codebase.md § Data layer + § Anti-patterns + dynamic/feedback-learned.md
  sections: [project_specific_first, grain_and_additivity, layer_direction, incremental_declarations, assertion_floors, backfill_safety, review_checklist]
  mirror_existing: true
  fallback: _examples/data-engineering-principles.md

- name: add-data-model
  kind: command
  triggers: { signal_confirmed_any: [data-pipeline, analytics, reporting] }
  extracts_from: _extracted-idioms.md § <role:transformation-model> (sibling model shape + assertion placement)
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: stub-from-sections

- name: audit-data-model
  kind: command
  triggers: { signal_confirmed_any: [data-pipeline, reporting] }
  extracts_from: _extracted-codebase.md § Data layer (analytical tables in scope)
  sections: [understand, organize, retrieve, validate]
  dispatches: warehouse-modeler
  fallback: stub-from-sections

- name: audit-data-quality
  kind: command
  triggers: { signal_confirmed_any: [data-pipeline, reporting] }
  extracts_from: _extracted-codebase.md § Tests (assertion framework + run history) + § Data layer
  sections: [understand, organize, retrieve, generate, update, validate]
  dispatches: data-quality-auditor
  fallback: stub-from-sections

- name: backfill-plan
  kind: command
  triggers: { signal_confirmed: data-pipeline }
  extracts_from: _extracted-codebase.md § Data layer (partitioning + incremental config) + § Modules (orchestration schedules)
  sections: [understand, organize, retrieve, generate, validate]
  fallback: stub-from-sections

- name: grain-probe
  kind: skill
  triggers: { signal_confirmed_any: [data-pipeline, reporting] }
  fallback: stub-from-sections

- name: lineage-trace
  kind: skill
  triggers: { signal_confirmed_any: [data-pipeline, analytics, reporting] }
  fallback: stub-from-sections

- name: contract-diff
  kind: skill
  triggers: { signal_confirmed_any: [data-pipeline, analytics] }
  fallback: stub-from-sections

- name: warehouse-scan-audit
  kind: skill
  triggers: { signal_confirmed_any: [data-pipeline, reporting] }
  fallback: stub-from-sections
```
