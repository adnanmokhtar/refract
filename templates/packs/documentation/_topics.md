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

- name: slo-doc-template
  kind: pattern
  # RENAMED from `slo`. Both this pack and `observability` shipped `ai-patterns/slo.md`, and
  # phase-4.2-apply.md installs ai-patterns with a plain `cp -R ... ai/patterns/` (no -n), so
  # whichever track applied second silently CLOBBERED the other. `documentation` is always-applied
  # and `observability` detects on OTel/Datadog/Sentry/Prometheus, so the collision fired on most
  # production services. The two files are complementary (1 shared heading out of 17 vs 8): this one
  # owns the SLO DOCUMENT template, observability owns the alerting arithmetic. Distinct filenames
  # are the fix that needs no change to templates/phases/.
  triggers: { logger_lib_detected: true, OR: { metrics_lib_detected: true } }
  extracts_from: _extracted-codebase.md § Observability + ai/project-goals.md (KPIs)
  sections: [overview, slo_for_this_app, slis_to_track, error_budget, examples]
  mirror_existing: true
  fallback: _examples/slo-doc-template.md

- name: system-design
  kind: pattern
  triggers: { always: true }
  extracts_from: _extracted-codebase.md (full)
  sections: [overview, architecture_diagram, components, data_flow, deploy_topology]
  mirror_existing: true
  fallback: _examples/system-design.md

- name: doc-refresh
  kind: command
  triggers: { always: true }   # three modes: the post-change refresh (default), --audit (read-only ledger + verdict), --from-audit (failing-first docs fix)
  fallback: commands/doc-refresh.md   # source-as-fallback: the class ledger, the refute step and the STOP list are the command

- name: add-adr
  kind: command
  triggers: { always: true }
  fallback: _examples/add-adr.md

- name: add-runbook
  kind: command
  triggers: { always: true }
  fallback: _examples/add-runbook.md

- name: doc-drift-scan
  kind: skill
  triggers: { always: true }   # human docs vs code and config: dead paths, symbols, scripts, flags, env, endpoints, pins, breaking notes, runbook commands and resources
  fallback: skills/doc-drift-scan/SKILL.md

- name: doc-structure-scan
  kind: skill
  # Docs against docs. Gated on a doc set with structure to rot: cross-doc links, an ADR directory, a changelog,
  # a docs-site config, translated pages, or alert rules that link runbooks.
  triggers:
    grep_evidence: "\\]\\([^)#]+\\.mdx?(#[^)]*)?\\)|(^|/)(adr|adrs|decisions)/[0-9]{3,4}-|mkdocs\\.ya?ml|docusaurus\\.config|book\\.toml|SUMMARY\\.md|^## \\[?[0-9]+\\.[0-9]+\\.[0-9]+|runbook_url|docs/[a-z]{2}(-[a-z]{2})?/"
    OR_codebase_section: "the repo commits human docs that link to each other, an ADR directory, a CHANGELOG, a docs-site config (MkDocs, Docusaurus, Sphinx, mdBook), translated docs, or alert rules with runbook_url"
  fallback: skills/doc-structure-scan/SKILL.md

- name: doc-sample-scan
  kind: skill
  # Samples that must run. Gated on fences in a compiled language, doctest prompts, embeds, a doc harness or a committed spec.
  triggers:
    grep_evidence: "```(ts|tsx|typescript|js|javascript|py|python|go|rust|java|kotlin|elixir)\\b|^\\s*>>> |--doctest-glob|pytest-examples|typescript-docs-verifier|embedme|literalinclude|--8<--|\"openapi\"\\s*:|^openapi:"
    OR_codebase_section: "the docs carry code fences in a compiled language, doctest prompts, embedded snippets or a doc-sample harness, or the repo commits an OpenAPI spec with examples"
  fallback: skills/doc-sample-scan/SKILL.md

- name: quickstart-verify
  kind: skill
  triggers: { always: true }   # DS-1: every repo with a README has a setup section to run; the safe container lane, else the static pre-pass
  fallback: skills/quickstart-verify/SKILL.md   # source-as-fallback: the safe-lane invariants must reach every install

- name: diagram-sync
  kind: skill
  # Was `always: true`, which installed a skill that HARD-DEPENDS on code-quality's
  # ai/optimize/_dep-graph.json into projects that have neither a diagram nor that pack —
  # where its only possible action was to halt. Now gated on the surface it actually serves.
  triggers:
    grep_evidence: "```mermaid|C4Context|C4Container|C4Component|@startuml|structurizr|\\.puml\\b|\\.dot\\b|flowchart (LR|TD|TB)|graph (LR|TD|TB)"
    OR_codebase_section: "the repo commits an architecture diagram (mermaid / C4 / PlantUML / Graphviz) in its docs, OR code-quality's architectural-diagnosis is installed and emits ai/optimize/_dep-graph.json"
  fallback: skills/diagram-sync/SKILL.md   # source-as-fallback

- name: docstring-coverage
  kind: skill
  triggers: { always: true }   # DD-1/2/3; an app with no public package prints N/A (no public package) and advisory rows only (precedents § 23)
  fallback: skills/docstring-coverage/SKILL.md   # source-as-fallback

- name: changelog-generate
  kind: skill
  triggers: { always: true }   # release-time generator; DH-1 / DH-2 detection is doc-drift-scan §12 and doc-structure-scan §9
  fallback: skills/changelog-generate/SKILL.md   # source-as-fallback
```
