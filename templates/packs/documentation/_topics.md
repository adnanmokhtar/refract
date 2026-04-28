# Documentation pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: doc-writer
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Modules + § "API surface" + ai/README.md if exists
  sections: [persona, audience_target, doc_layering_rule, project_glossary_use, output_format]
  fallback: _examples/doc-writer.md
  cite_evidence: lenient

- name: api-documenter
  kind: agent
  triggers: { api_surface_detected: true }
  extracts_from: _extracted-codebase.md § "API surface" + DTOs
  sections: [persona, openapi_strategy, dto_to_schema, example_payloads, error_doc, output_format]
  fallback: _examples/api-documenter.md

- name: doc-principles
  kind: rule
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Conventions + ai/conventions.md if exists
  sections: [project_specific_first, no_redundant_docs, why_not_what, code_comment_discipline, adr_when_required, link_back_to_code]
  mirror_existing: true
  fallback: _examples/doc-principles.md

- name: adr-template
  kind: pattern
  triggers: { always: true }
  fallback: _examples/adr-template.md

- name: slo
  kind: pattern
  triggers: { logger_lib_detected: true, OR: { metrics_lib_detected: true } }
  extracts_from: _extracted-codebase.md § Observability + ai/project-goals.md (KPIs)
  sections: [overview, slo_for_this_app, slis_to_track, error_budget, examples]
  mirror_existing: true
  fallback: _examples/slo.md

- name: system-design
  kind: pattern
  triggers: { always: true }
  extracts_from: _extracted-codebase.md (full)
  sections: [overview, architecture_diagram, components, data_flow, deploy_topology]
  mirror_existing: true
  fallback: _examples/system-design.md

- name: doc-refresh
  kind: command
  triggers: { always: true }
  fallback: _examples/doc-refresh.md

- name: add-adr
  kind: command
  triggers: { always: true }
  fallback: _examples/add-adr.md

- name: doc-drift-scan
  kind: skill
  triggers: { always: true }
  fallback: _examples/doc-drift-scan.md
```
