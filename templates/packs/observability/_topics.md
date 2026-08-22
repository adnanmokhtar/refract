# Observability pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: telemetry-architect
  kind: agent
  triggers: { logger_lib_detected: true }
  extracts_from: _extracted-codebase.md § Observability (logger / metrics / tracer detected)
  sections: [persona, current_stack, what_to_instrument_per_request, sampling_strategy, dashboard_recommendations, output_format]
  fallback: _examples/telemetry-architect.md
  cite_evidence: strict

- name: observability-reviewer
  kind: agent
  # always: this reviewer's first check is "no direct stdout / unstructured print calls in
  # committed code". Gating it on logger_lib_detected installed it only where that defect had
  # already been solved — the projects that need it most were the ones that never received it.
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Observability + sample handlers
  sections: [persona, review_checklist, missing_correlation_id_check, log_level_discipline, output_format]
  fallback: _examples/observability-reviewer.md

- name: sre-engineer
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Tests + § Observability + ai/runbooks/ if exists
  sections: [persona, slo_definition_for_this_app, runbook_authoring, alert_design, postmortem_template]
  fallback: _examples/sre-engineer.md

- name: incident-responder
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Modules + § Observability + ai/runbooks/incident-response.md if exists
  sections: [persona, severity_definitions, comms_template, rollback_decisions, postmortem_required]
  fallback: _examples/incident-responder.md

- name: structured-logging
  kind: pattern
  # always: the pattern carries the pick-a-logger and migrate-off-stdout guidance, which is
  # precisely what a project with no structured logger needs. Gating it on logger_lib_detected
  # withheld it from the only projects that had the problem.
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Observability (logger lib) + sample log calls
  sections: [overview, logger_in_use, schema_required_fields, correlation_id_propagation, what_to_log_what_not, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/structured-logging.md

- name: metrics
  kind: pattern
  triggers: { metrics_lib_detected: true }
  extracts_from: _extracted-codebase.md § Observability (metrics) + sample counters
  sections: [overview, lib_in_use, naming_convention, cardinality_rules, dashboard_links, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/metrics.md

- name: tracing
  kind: pattern
  triggers: { tracer_lib_detected: true }
  extracts_from: _extracted-codebase.md § Observability (tracer)
  sections: [overview, lib_in_use, span_naming, what_to_trace, sampling, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/tracing.md

- name: slo
  kind: pattern
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Observability (SLOs + error budgets) + ai/runtime/slos.md if present
  sections: [sli_menu, error_budget, multi_window_burn_rate, slo_as_code, detectors]
  mirror_existing: true
  fallback: _examples/slo.md

- name: audit-logging
  kind: pattern
  triggers: { signal_confirmed_any: [compliance, payment, multi-tenant] }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" (audit trail + retention regime)
  sections: [audit_vs_debug, tamper_evidence, schema, retention_by_regime, boundary, detectors]
  mirror_existing: true
  fallback: _examples/audit-logging.md

- name: profiling
  kind: pattern
  triggers: { signal_confirmed: performance_critical }
  extracts_from: _extracted-codebase.md § Observability (profiler) + runtime
  sections: [fourth_signal, profile_types, low_overhead, exemplar_linkage, boundary, detectors]
  mirror_existing: true
  fallback: _examples/profiling.md

- name: dashboards
  kind: pattern
  triggers: { metrics_lib_detected: true }
  extracts_from: _extracted-codebase.md § Observability (dashboards / provisioning tool) + existing boards + alert rules
  sections: [tier_hierarchy, panel_taxonomy_red_use, dashboards_as_code, alert_panel_linkage, vanity_and_sprawl, detectors]
  mirror_existing: true
  fallback: _examples/dashboards.md

- name: observability-principles
  kind: rule
  # always: the rule's first Must-not forbids direct stdout / unstructured print calls. Gating it
  # on logger_lib_detected meant the rule that bans them declined to install on the projects that
  # use them. A capability signal is the wrong gate for a rule whose subject is the capability's
  # absence — see the integrator note in the pack changelog.
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Observability + § Anti-patterns
  sections: [project_specific_first, no_console_log, structured_only, correlation_required, error_logging_pattern, secret_redaction]
  mirror_existing: true
  fallback: _examples/observability-principles.md

- name: add-telemetry
  kind: command
  # always: the pack's day-one entry point. It now carries the greenfield convention ledger and the
  # migrate-off-stdout move, so "no structured logger yet" is the case it handles, not a reason to
  # withhold it.
  triggers: { always: true }
  fallback: _examples/add-telemetry.md

- name: alert-audit
  kind: skill
  triggers: { metrics_lib_detected: true }
  fallback: _examples/alert-audit.md

- name: synthetic-monitoring
  kind: skill
  triggers: { always: true }
  fallback: _examples/synthetic-monitoring.md

- name: add-metrics
  kind: command
  triggers: { metrics_lib_detected: true }
  fallback: stub-from-sections

- name: add-tracing
  kind: command
  triggers: { tracer_lib_detected: true }
  fallback: stub-from-sections

- name: alert-design
  kind: command
  triggers: { metrics_lib_detected: true }
  fallback: stub-from-sections

- name: slo-audit
  kind: skill
  triggers: { metrics_lib_detected: true }
  fallback: stub-from-sections
```
