# Performance pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: performance-optimizer
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Performance (harness, budgets, APM) + § Tests (perf tests if any) + _extracted-idioms.md (the project's concurrency, cache and pool primitives)
  sections: [premise, inputs, halt_conditions, ranking, output_format, guardrail_matrix]
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

- name: perf-fix
  kind: command
  triggers: { always: true }
  fallback: commands/perf-fix.md   # the source IS the fallback, as for security-fix — no _examples/ stub ships

# n-plus-one-scan moved to the database pack (database round trips are that pack's); its topic lives in
# templates/packs/database/_topics.md.

- name: request-path-scan
  kind: skill
  triggers: { api_surface_detected: true }   # its scale and queue classes also read deploy manifests; a repo with no server reports each class N/A
  fallback: skills/request-path-scan/SKILL.md   # the source IS the fallback — no _examples/ stub ships

- name: memory-growth-scan
  kind: skill
  triggers: { api_surface_detected: true }   # its limit class also reads deploy manifests; a repo with no long-running server reports each class N/A
  fallback: skills/memory-growth-scan/SKILL.md   # the source IS the fallback — no _examples/ stub ships

- name: caching-scan
  kind: skill
  triggers: { api_surface_detected: true }   # a repo with no cache library or HTTP cache headers reports each class N/A
  fallback: skills/caching-scan/SKILL.md   # the source IS the fallback — no _examples/ stub ships

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
