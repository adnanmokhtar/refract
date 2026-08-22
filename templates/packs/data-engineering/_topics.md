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
  fallback: ai-patterns/transformation-layers.md   # source-as-fallback (phase-4.2-apply.md step 2). `stub-from-sections` shipped greenfield a skeleton of six empty headings while the finished pattern sat beside it on disk.

- name: data-contract
  kind: pattern
  triggers: { signal_confirmed_any: [data-pipeline, analytics, reporting] }
  extracts_from: _extracted-codebase.md § Cross-cutting concerns (external sources + their owners) + § API surface (published datasets)
  sections: [overview, what_a_contract_declares, change_classes, hunting_semantic_breaks, notice_and_migration, enforcement_points, detectors]
  mirror_existing: true
  fallback: ai-patterns/data-contract.md   # source-as-fallback. The stub dropped `hunting_semantic_breaks` — the SEMANTIC-BREAKING class and how to detect it distributionally, which is the one thing in this pattern nobody writes down unprompted.

- name: data-quality-tests
  kind: pattern
  triggers: { signal_confirmed_any: [data-pipeline, reporting] }
  extracts_from: _extracted-codebase.md § Tests (assertion framework) + § Data layer (models + owners)
  sections: [overview, structural_floor, temporal_floor, distributional_floor, reconciliation_floor, severity_and_routing, threshold_derivation, detectors]
  mirror_existing: true
  fallback: ai-patterns/data-quality-tests.md   # source-as-fallback. The four floors are the pack's central idea; a greenfield project received their four headings and none of their content.

- name: semantic-layer
  kind: pattern
  triggers: { signal_confirmed_any: [analytics, reporting] }
  extracts_from: _extracted-codebase.md § Modules (metric definitions / BI model files) + ai/business-domain.md (metric vocabulary)
  sections: [overview, why_a_metric_drifts, definition_contents, altitude_choice, additivity, changing_a_definition, detectors]
  mirror_existing: true
  fallback: ai-patterns/semantic-layer.md   # source-as-fallback.

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
  fallback: commands/add-data-model.md   # source-as-fallback. A seven-heading stub is not a command; the phase bodies, the sibling-shape rule and the closure verbs ARE the command.

- name: audit-data-model
  kind: command
  triggers: { signal_confirmed_any: [data-pipeline, reporting] }
  extracts_from: _extracted-codebase.md § Data layer (analytical tables in scope)
  sections: [understand, organize, retrieve, validate]
  dispatches: warehouse-modeler
  fallback: commands/audit-data-model.md   # source-as-fallback. The stub dropped "cardinality probes are run, not reasoned" — the line the whole audit rests on.

- name: audit-data-quality
  kind: command
  triggers: { signal_confirmed_any: [data-pipeline, reporting] }
  extracts_from: _extracted-codebase.md § Tests (assertion framework + run history) + § Data layer
  sections: [understand, organize, retrieve, generate, update, validate]
  dispatches: data-quality-auditor
  fallback: commands/audit-data-quality.md   # source-as-fallback. The stub dropped the prove-an-assertion-can-fail step, which is the only thing separating this command from counting test files.

- name: backfill-plan
  kind: command
  triggers: { signal_confirmed: data-pipeline }
  extracts_from: _extracted-codebase.md § Data layer (partitioning + incremental config) + § Modules (orchestration schedules)
  sections: [understand, organize, retrieve, generate, validate]
  fallback: commands/backfill-plan.md   # source-as-fallback. The stub dropped the shadow-target/idempotency-proof/UNEXPLAINED-DELTA gate — i.e. every safety property the rule's hard rule promises a backfill will have.

- name: grain-probe
  kind: skill
  triggers: { signal_confirmed_any: [data-pipeline, reporting] }
  fallback: skills/grain-probe/SKILL.md   # source-as-fallback. This entry declared `stub-from-sections` with NO `sections:` list, so phase-4.2-apply step 2 had nothing to build a stub FROM and greenfield received an EMPTY FILE. Same defect repaired in security (CHANGELOG:87) and infrastructure (CHANGELOG:106).

- name: lineage-trace
  kind: skill
  triggers: { signal_confirmed_any: [data-pipeline, analytics, reporting] }
  fallback: skills/lineage-trace/SKILL.md   # source-as-fallback — was `stub-from-sections` with no `sections:` list, i.e. an empty file on greenfield.

- name: contract-diff
  kind: skill
  triggers: { signal_confirmed_any: [data-pipeline, analytics] }
  fallback: skills/contract-diff/SKILL.md   # source-as-fallback — was `stub-from-sections` with no `sections:` list, i.e. an empty file on greenfield.

- name: warehouse-scan-audit
  kind: skill
  triggers: { signal_confirmed_any: [data-pipeline, reporting] }
  fallback: skills/warehouse-scan-audit/SKILL.md   # source-as-fallback — was `stub-from-sections` with no `sections:` list, i.e. an empty file on greenfield.
```
