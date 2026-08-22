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

- name: memory-leak-hunt
  kind: skill
  triggers: { api_surface_detected: true }
  fallback: _examples/memory-leak-hunt.md

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
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" (cache layer + key convention) + § "Data model" (read/write frequency per entity)
  sections: [persona, existing_cache_layers, data_classes, key_design, invalidation, failure_modes, output_format]
  fallback: agents/caching-architect.md   # no _examples/ stub ships — fall back to the live source (as testing/run-tests does), never to an empty stub

- name: lazy-loading
  kind: pattern
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md § Modules (route map) + _extracted-idioms.md (router + image primitive)
  sections: [overview, what_to_defer, route_splitting, component_splitting, media, pitfalls]
  mirror_existing: true
  fallback: ai-patterns/lazy-loading.md   # no _examples/ stub ships — fall back to the live source

- name: inp-responsiveness
  kind: pattern
  triggers: { primary_frontend_framework_detected: true }
  fallback: _examples/inp-responsiveness.md

- name: bundle-perf
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md § Frontend (build tool, route map, bundle budget) + _extracted-idioms.md (image + font primitives)
  sections: [understand, organize, retrieve, generate, validate]
  fallback: commands/bundle-perf.md   # no _examples/ stub ships — fall back to the live source

- name: profile-perf
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Performance (profiler, slow-query log, APM) + § Modules
  sections: [understand, organize, retrieve, generate, validate]
  fallback: commands/profile-perf.md   # no _examples/ stub ships — fall back to the live source
```
