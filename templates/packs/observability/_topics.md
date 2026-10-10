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
  # always: the judge of the seven detectors' rows (log-signal-scan §3 owns the stdout check this
  # entry was first gated for). Gating it on logger_lib_detected installed it only where logging was
  # already solved — the projects that need it most were the ones that never received it.
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Observability + sample handlers + the sibling service per signal
  sections: [persona, contract, halt_conditions, detector_dispatch, axis_ownership, sibling_divergence_check, emit_and_assert_closure, output_format]
  fallback: _examples/observability-reviewer.md   # generated-from copy of agents/observability-reviewer.md (COPY-DRIFT gated)

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
  fallback: skills/alert-audit/SKILL.md   # source-as-fallback: the rewrite is the behavioural half only and consumes alert-rule-lint

- name: log-signal-scan
  kind: skill
  triggers:
    logger_lib_detected: true
    OR_grep_evidence: "\\b(logger|log|LOG|LOGGER)\\.(error|warn|exception)\\(|\\bconsole\\.(log|error)\\(|NestFactory\\.create|\\bprint\\(|System\\.out\\.print"   # a repo with no logger library still logs: stdout and the Nest default ConsoleLogger are LG-03's subject
  extracts_from: _extracted-codebase.md § Observability (logger libraries and versions, request-log config, exception filters, job processors)
  fallback: skills/log-signal-scan/SKILL.md   # source-as-fallback

- name: alert-rule-lint
  kind: skill
  triggers:
    metrics_lib_detected: true
    OR_grep_evidence: "^\\s*-\\s*alert:|kind:\\s*PrometheusRule|additionalPrometheusRules|^rule_files:|resource \"(datadog_monitor|newrelic_nrql_alert_condition|grafana_rule_group|honeycombio_trigger)\""   # rule, CRD, Helm, monitor surfaces — a repo can ship alert rules with no metrics client in its code
  extracts_from: _extracted-codebase.md § Observability (Prometheus / Alertmanager versions, rule and monitor locations)
  fallback: skills/alert-rule-lint/SKILL.md

- name: synthetic-monitoring
  kind: skill
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Observability (probe configs — k6, Checkly, blackbox, synthetics Terraform — and the route table)
  fallback: skills/synthetic-monitoring/SKILL.md   # source-as-fallback; its pre-flight prints §2–§5 N/A (no probe config) and still lists §1 journeys

- name: add-metrics
  kind: command
  triggers: { metrics_lib_detected: true }
  fallback: commands/add-metrics.md   # source-as-fallback (phase-4.2-apply.md § 4.2-AUTHOR step 2). Was `stub-from-sections` with NO `sections:` list, so step 2 had nothing to build a stub FROM and a no-signal project received an EMPTY FILE while the finished 181-line command sat beside it on disk.

- name: add-tracing
  kind: command
  triggers: { tracer_lib_detected: true }
  fallback: commands/add-tracing.md   # source-as-fallback — was `stub-from-sections` with no `sections:` list, i.e. an empty file on a no-signal project.

- name: trace-propagation-scan
  kind: skill
  triggers:
    tracer_lib_detected: true
    OR_grep_evidence: "OTEL_(EXPORTER_OTLP|TRACES_SAMPLER|SERVICE_NAME|PROPAGATORS)|-javaagent:|opentelemetry-instrument|ddtrace-run|dd-trace|tracesSampleRate|traces_sample_rate"   # zero-code wiring and tracker tracing keys: a repo can trace with no tracer in its own manifests
  extracts_from: _extracted-codebase.md § Observability (tracer, SDK and instrumentation versions, start commands, queue clients)
  fallback: skills/trace-propagation-scan/SKILL.md   # source-as-fallback; the skill's own SDK gate prints N/A (no tracing SDK) for every § but §5's flush half and §10's requirement half

- name: metric-hygiene-scan
  kind: skill
  triggers:
    metrics_lib_detected: true
    OR_grep_evidence: "@nestjs/terminus|MapHealthChecks|management\\.endpoint\\.health|/(healthz|readyz|livez)\\b|@Get\\(['\"](health|ready|live)"   # §7–§8 (lying readiness, probe traffic) need no metrics client: a repo can serve probes with none
  extracts_from: _extracted-codebase.md § Observability (metrics client and version, registry module, health routes, probe paths)
  fallback: skills/metric-hygiene-scan/SKILL.md   # source-as-fallback; the skill's own metrics gate prints N/A (no metrics library) for §1–§6 and still runs §7–§8

- name: alert-design
  kind: command
  triggers: { metrics_lib_detected: true }
  fallback: commands/alert-design.md   # source-as-fallback — was `stub-from-sections` with no `sections:` list, i.e. an empty file on a no-signal project.

- name: slo-audit
  kind: skill
  triggers: { metrics_lib_detected: true }
  fallback: skills/slo-audit/SKILL.md   # source-as-fallback; the single writer of ai/runtime/slos.md (write mode), read-only under /obs-audit (--no-write)

- name: error-tracking-scan
  kind: skill
  triggers:
    api_surface_detected: true
    OR_grep_evidence: "@sentry/|sentry[-_]sdk|getsentry/sentry-go|io\\.sentry|Sentry\\.AspNetCore|@bugsnag/|\"rollbar\"|@datadog/browser-rum|firebase-crashlytics|@Catch\\(|@ControllerAdvice|exception_handler\\("   # a browser-only app ships a tracker with no API surface; §2 and §4 (process hooks, boundary capture) run with no tracker at all
  extracts_from: _extracted-codebase.md § Observability (tracker SDKs and versions, bundler plugins, process types and start commands, global exception filters)
  fallback: skills/error-tracking-scan/SKILL.md   # source-as-fallback; the skill's own tracker gate prints N/A (no tracker SDK) for §1 and §3 and still runs §2 and §4

- name: slo-rule-scan
  kind: skill
  triggers:
    metrics_lib_detected: true
    OR_grep_evidence: "^version:\\s*\"?prometheus/v1|kind:\\s*(PrometheusServiceLevel|ServiceLevelObjective)|apiVersion:\\s*openslo/|\\*\\s*\\(1\\s*-\\s*0?\\.\\d|resource \"(datadog_service_level_objective|honeycombio_slo|newrelic_service_level)\""   # SLO specs, burn rules and vendor SLOs: a deploy repo can declare SLOs with no metrics client in its code
  extracts_from: _extracted-codebase.md § Observability (SLO specs and generators, burn-rule files, the SLO registry, TSDB retention)
  fallback: skills/slo-rule-scan/SKILL.md   # source-as-fallback; burn-check.py ships beside it and imports alert-rule-lint's rule-inventory.py

- name: telemetry-config-scan
  kind: skill
  triggers:
    metrics_lib_detected: true
    OR_grep_evidence: "otelcol|opentelemetry-collector|grafana/(loki|promtail|alloy)|loki\\.(process|write|source)|pipeline_stages:|limits_config:|kind:\\s*(ServiceMonitor|PodMonitor)|\"panels\"\\s*:|^scrape_configs:"   # collector, shipper, Loki, scrape-selection and dashboard config often lives in a deploy tree with no metrics client in the app code
  extracts_from: _extracted-codebase.md § Observability (collector, shipper and Loki configs, chart values and pins, Prometheus CR selectors, dashboards)
  fallback: skills/telemetry-config-scan/SKILL.md   # source-as-fallback; every § prints N/A (<reason>) for a surface the repo does not ship
```
