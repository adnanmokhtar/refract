# Frontend pack — topic specs (AUTHOR mode)

Schema + semantics: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: <framework>-architect            # nuxt-architect / nextjs-architect / vue-architect / etc.
  kind: agent
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (framework + component layout + state lib + routing) + _extracted-idioms.md (composables/hooks if any)
  sections: [persona, when_to_invoke, preflight_reading, component_decisions, state_decisions, routing_decisions, output_format, verification]
  fallback: _examples/ui-architect.md
  cite_evidence: strict

- name: <framework>-reviewer
  kind: agent
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md + _extracted-idioms.md
  sections: [persona, review_checklist, framework_specific_checks, output_format]
  fallback: _examples/ui-reviewer.md

- name: accessibility-auditor
  kind: agent
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (UI components dir) + ai/runtime if relevant
  sections: [persona, audit_methodology, axe_recipes, project_specific_components_to_check, output_format]
  fallback: _examples/accessibility-auditor.md

- name: i18n-auditor
  kind: agent
  triggers: { i18n_lib_detected: true }
  extracts_from: _extracted-codebase.md (i18n lib + locale files + key convention)
  sections: [persona, key_convention_in_use, missing_key_detection, untranslated_string_detection, output_format]
  fallback: _examples/i18n-auditor.md

- name: data-flow-auditor
  kind: agent
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (state lib + service layer + API client)
  sections: [persona, data_flow_in_this_app, anti_patterns_to_flag, output_format]
  fallback: _examples/data-flow-auditor.md

- name: api-contract-sentry
  kind: agent
  triggers: { api_client_detected: true }
  extracts_from: _extracted-codebase.md (API client + DTO mirror) + sibling backend repo if cross-repo
  sections: [persona, contract_drift_detection, type_mirroring_strategy, output_format]
  fallback: _examples/api-contract-sentry.md

- name: technical-seo
  kind: agent
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (metadata primitive in use — generateMetadata / useSeoMeta / svelte:head / Meta service / react-helmet / next-seo / shared <Seo>; router; i18n locales) + _extracted-idioms.md (shared SEO component/composable if any)
  sections: [persona, preflight_reading, adapt_to_metadata_primitive, checklist, example_findings, output_format]
  fallback: _examples/technical-seo.md
  cite_evidence: strict

- name: forms
  kind: pattern
  triggers: { forms_lib_detected_OR_form_components_present: true }
  extracts_from: _extracted-codebase.md (form lib if any) + sample form components
  sections: [overview, validation_strategy, schema_or_decorators, error_display, accessibility_in_forms, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/forms.md

- name: i18n
  kind: pattern
  triggers: { i18n_lib_detected: true }
  extracts_from: _extracted-codebase.md (i18n lib + key convention + locales)
  sections: [overview, key_convention, locale_files, fallback_strategy, formatting_dates_currencies, RTL_handling, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/i18n.md

- name: rendering-strategy
  kind: pattern
  triggers: { ssr_capable_framework_detected: true }
  extracts_from: _extracted-codebase.md (framework + render mode config)
  sections: [overview, ssr_vs_csr_per_route, isr_or_revalidation, hydration_concerns, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/rendering-strategy.md

- name: ssr-safety
  kind: pattern
  triggers: { ssr_enabled: true }
  extracts_from: _extracted-codebase.md + sample components using window/document
  sections: [overview, server_only_apis, client_only_apis, hydration_mismatches, examples_from_codebase, pitfalls]
  mirror_existing: true
  fallback: _examples/ssr-safety.md

- name: frontend-principles
  kind: rule
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md § Conventions (frontend section) + _extracted-idioms.md (composables/hooks)
  sections: [project_specific_first, component_naming, state_lib_usage, api_client_usage, accessibility_required, observability_in_browser]
  mirror_existing: true
  fallback: _examples/frontend-principles.md

- name: migration-frontend
  kind: rule
  triggers:
    migration_layout_detected: true   # only ships when migration pack is loaded (mirrors backend/migration-backend)
  extracts_from: _extracted-codebase.md § Stack + § Layering + _extracted-idioms.md (full)
  sections: [stack_aware_primitive_set, frontend_audit_axes, anti_pattern_catalogue, transposition_trap_fingerprints, phase_3_retrieve_specifics, locale_parity, cross_references]
  mirror_existing: true
  fallback: rules/migration-frontend.md   # canonical authored shape; AUTHOR mode anchors stack-aware substitutions to project

- name: add-page
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (router + page convention)
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: _examples/add-page.md

- name: add-component
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (component dir + naming)
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: _examples/add-component.md

- name: add-crud-page
  kind: command
  triggers: { primary_frontend_framework_detected: true, AND: { api_client_detected: true } }
  extracts_from: _extracted-codebase.md (page + form + table conventions)
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: _examples/add-crud-page.md

- name: add-feature
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md § Modules (sibling pages + module shape) + _extracted-idioms.md (wrappers/composables)
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: commands/add-feature.md

- name: a11y-audit
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  fallback: _examples/a11y-audit.md

- name: i18n-audit
  kind: command
  triggers: { i18n_lib_detected: true }
  fallback: _examples/i18n-audit.md

- name: visual-check
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  fallback: _examples/visual-check.md

- name: ssr-audit
  kind: skill
  triggers: { ssr_enabled: true }
  fallback: _examples/ssr-audit.md

- name: streaming-ssr
  kind: skill
  triggers: { ssr_enabled: true }
  fallback: _examples/streaming-ssr.md

- name: navigation-speed
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  fallback: _examples/navigation-speed.md

- name: lcp-audit
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  fallback: _examples/lcp-audit.md

- name: seo-audit
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (framework metadata primitive + router + i18n locales + sitemap/robots setup)
  fallback: _examples/seo-audit.md

- name: lighthouse-ci
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  fallback: _examples/lighthouse-ci.md

- name: bundle-analyze
  kind: skill
  triggers: { build_tool_detected: true }
  fallback: _examples/bundle-analyze.md

- name: a11y-scan
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  fallback: _examples/a11y-scan.md
```
