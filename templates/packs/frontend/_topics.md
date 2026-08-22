# Frontend pack — topic specs (AUTHOR mode)

Schema + semantics: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
# The two central agents keep their CANONICAL names. AUTHOR mode makes them framework-aware through
# `extracts_from` / `sections` — never by renaming the file. Nine dispatch sites (`/add-page`,
# `/add-crud-page`, `/add-feature`, `/refactor`), `_essentials.md`, and both `_examples/` fallbacks
# all say `ui-architect` / `ui-reviewer`; a `<framework>-*` topic name orphaned every one of them.
# `agents/ui-reviewer.md` § Related states the reason outright: the framework lens lives INSIDE the
# agent, so there is no separate per-framework reviewer to name.
- name: ui-architect
  kind: agent
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (framework + component layout + state lib + routing) + _extracted-idioms.md (composables/hooks if any)
  sections: [persona, when_to_invoke, preflight_reading, component_decisions, state_decisions, routing_decisions, output_format, verification]
  fallback: _examples/ui-architect.md
  cite_evidence: strict

- name: ui-reviewer
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

- name: data-fetching
  kind: pattern
  triggers: { query_lib_detected_OR_client_data_fetching_present: true }
  extracts_from: _extracted-codebase.md (query lib — TanStack Query / SWR / RTK Query / Apollo — or the hand-rolled fetch layer + cache convention)
  sections: [overview, server_state_vs_client_state, cache_contract, loading_error_empty_states, request_cancellation, optimistic_updates, avoiding_waterfalls, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/data-fetching.md

- name: list-virtualization
  kind: pattern
  triggers: { large_list_or_table_rendering_detected: true }
  extracts_from: _extracted-codebase.md (virtualizer lib if any + list/table components > ~100 rows)
  sections: [overview, windowing_and_overscan, fixed_vs_variable_height, infinite_scroll, cls_safety, accessibility, seo_findinpage_tradeoff, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/list-virtualization.md

- name: error-boundaries
  kind: pattern
  triggers: { component_framework_detected: true }
  extracts_from: _extracted-codebase.md (boundary primitive + error sink — Sentry etc.)
  sections: [overview, catch_surface_and_async_gap, granularity, fallback_ux_and_reset, error_reporting, suspense_and_hydration_pairing, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/error-boundaries.md

- name: code-splitting
  kind: pattern
  triggers: { bundler_detected: true }
  extracts_from: _extracted-codebase.md (bundler + router + heavy deps)
  sections: [overview, route_vs_component_splitting, eager_vs_lazy_tradeoff, over_splitting_and_manualchunks, barrel_file_trap, suspense_and_error_boundary_pairing, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/code-splitting.md

- name: realtime-client
  kind: pattern
  triggers: { websocket_or_sse_or_realtime_lib_detected: true }
  extracts_from: _extracted-codebase.md (realtime transport/lib + auth + cache reconcile points)
  sections: [overview, transport_choice, reconnection_backoff_heartbeat, auth_and_reauth, backpressure, message_dedup, cache_reconciliation, teardown_and_offline, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/realtime-client.md

- name: auth-session-client
  kind: pattern
  triggers: { auth_or_login_detected: true }
  extracts_from: _extracted-codebase.md (auth lib/SDK + token storage + HTTP client interceptor + router guards) + _extracted-idioms.md (session composable/service if any)
  sections: [overview, ownership_boundary, token_storage_trade, single_flight_refresh, logout_fanout, cross_tab_sync, route_vs_render_guard, accessible_authentication, detectors, pitfalls]
  mirror_existing: true
  fallback: _examples/auth-session-client.md

- name: frontend-principles
  kind: rule
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md § Conventions (frontend section) + _extracted-idioms.md (composables/hooks)
  sections: [project_specific_first, component_naming, state_lib_usage, api_client_usage, accessibility_required, observability_in_browser]
  mirror_existing: true
  fallback: _examples/frontend-principles.md

# `i18n-rules` is deliberately NOT named `i18n`: that topic name is taken by the ai-pattern above
# (kind: pattern), and validate-pack-consistency check 5 greps by NAME ONLY
# (scripts/validate-pack-consistency.sh:134). A `- name: i18n` rule entry would collide with the
# pattern's and the gate would stay blind to whichever of the two went missing. Frontend is the only
# pack in the repo with a rule and an ai-pattern sharing a stem. Keep these as whole-line comments:
# a trailing comment on the `kind:` line is read as part of the kind value by scripts/pack-search.py.
- name: i18n-rules
  kind: rule
  triggers: { i18n_lib_detected: true }
  extracts_from: _extracted-codebase.md § i18n (lib + locale set + translation field type + available-languages source + default/fallback locale) + _extracted-idioms.md (t()/$t() call convention, empty-translations factory, per-module locale layout)
  sections: [project_specific_anchored, dynamic_key_types, locale_parity, active_language_refs, rtl_logical_properties, named_anti_patterns]
  mirror_existing: true
  fallback: rules/i18n.md      # canonical authored shape (same strategy as migration-frontend below);
                               # there is no _examples/ file for it — `_examples/i18n.md` is the
                               # ai-pattern's abridgement and declares `# Pattern: i18n`, so pointing
                               # here would ship a pattern where a rule is required.

- name: migration-frontend
  kind: rule
  triggers:
    migration_layout_detected: true   # only ships when migration pack is loaded (mirrors backend/migration-backend)
  extracts_from: _extracted-codebase.md § Stack + § Layering + _extracted-idioms.md (full)
  sections: [stack_aware_primitive_set, frontend_audit_axes, density_gates, anti_pattern_catalogue, transposition_trap_fingerprints, phase_3_retrieve_specifics, cross_references]
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

- name: refactor
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (component/state conventions) + STACK.md
  sections: [pack_overlay_gates, dispatch, when_not]
  fallback: commands/refactor.md   # self-fallback — the same strategy as add-feature above and
                                   # i18n / migration-frontend. The overlay's three declared
                                   # sections ARE commands/refactor.md; the former
                                   # `_examples/refactor.md` was a six-line usage anecdote carrying
                                   # none of them, so a no-signal install received an anecdote in
                                   # place of the gates — including the code-quality absent-branch
                                   # at commands/refactor.md § What happens internally (silent).

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

- name: image-optimization
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (image primitive in use — next/image / NuxtImg / NgOptimizedImage / astro:assets / <picture> / image CDN)
  fallback: _examples/image-optimization.md

- name: font-optimization
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (font mechanism — next/font / @nuxt/fonts / Fontsource / @font-face / remote Google Fonts; i18n locales for subset safety)
  fallback: _examples/font-optimization.md

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
  extracts_from: _extracted-idioms.md (the project's own modal / dropdown / drawer wrapper names, for the interactive-surface trigger enumeration)
  fallback: _examples/a11y-scan.md

- name: dev-server-start
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (workspace layout + app members + package manager + dev script + configured port)
  fallback: _examples/dev-server-start.md

- name: verify-with-playwright
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (routes to drive + auth gate + role set for the unauthorised lane + i18n locale mechanism) + .mcp.json (playwright MCP entry)
  fallback: _examples/verify-with-playwright.md

- name: component-playground
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (component dir + shared input primitives + dev-route convention + existing component explorer, if any)
  fallback: _examples/component-playground.md
```
