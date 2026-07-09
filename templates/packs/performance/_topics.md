# Performance pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: performance-optimizer
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § "Anti-patterns" (N+1 evidence, etc.) + § Tests (perf tests if any) + _extracted-idioms.md (repo base — relation loading strategy)
  sections: [persona, project_perf_signals, n_plus_one_recipes, cache_opportunities, db_index_recommendations, output_format]
  fallback: _examples/performance-optimizer.md
  cite_evidence: strict

- name: performance-principles
  kind: rule
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" (cache layer) + § "Data model"
  sections: [project_specific_first, no_unbounded_lists, pagination_required, cache_first_for_reads, async_for_io_heavy, measure_before_optimize]
  mirror_existing: true
  fallback: _examples/performance-principles.md

- name: perf-audit
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-codebase.md (full)
  sections: [understand, retrieve, generate]
  fallback: _examples/perf-audit.md

- name: n-plus-one-scan
  kind: skill
  triggers: { orm_detected: true }
  fallback: _examples/n-plus-one-scan.md

- name: profile-endpoint
  kind: skill
  triggers: { api_surface_detected: true }
  fallback: _examples/profile-endpoint.md

- name: load-test
  kind: skill
  triggers: { api_surface_detected: true }
  sections: [premise, when_to_run, test_taxonomy, adapt_to_codebase, procedure, output, gotchas, halt_conditions, related]
  mirror_existing: true
  fallback: _examples/load-test.md

- name: web-vitals-field
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  fallback: _examples/web-vitals-field.md

- name: caching-architect
  kind: agent
  triggers: { always: true }
  fallback: stub-from-sections

- name: lazy-loading
  kind: pattern
  triggers: { primary_frontend_framework_detected: true }
  fallback: stub-from-sections

- name: inp-responsiveness
  kind: pattern
  triggers: { primary_frontend_framework_detected: true }
  fallback: _examples/inp-responsiveness.md

- name: bundle-perf
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  fallback: stub-from-sections

- name: profile-perf
  kind: command
  triggers: { always: true }
  fallback: stub-from-sections
```
