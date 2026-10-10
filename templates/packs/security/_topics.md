# Security pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: security-auditor
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" + § Auth + § "Anti-patterns" + ai/failures/_index.md if exists
  sections: [persona, owasp_checklist_for_this_stack, auth_review_for_this_app, signal_specific_checks, output_format]
  fallback: _examples/security-auditor.md

- name: api-security-reviewer
  kind: agent
  triggers: { api_surface_detected: true }
  extracts_from: _extracted-codebase.md § "API surface" (endpoints + OpenAPI/GraphQL + object-ownership + role gates)
  sections: [persona, api_top10_checklist, graphql_checks, output_format]
  fallback: _examples/api-security-reviewer.md

- name: llm-security-reviewer
  kind: agent
  triggers: { llm_usage_detected: true }
  extracts_from: _extracted-codebase.md § "AI/LLM integration" (prompt assembly + tool/function calling + RAG + output sinks + agent loops)
  sections: [persona, llm_top10_checklist, output_format]
  fallback: _examples/llm-security-reviewer.md
  cite_evidence: strict

- name: auth-reviewer
  kind: agent
  triggers: { auth_scheme_detected: true }
  extracts_from: _extracted-codebase.md § Auth + sample guards/middleware
  sections: [persona, scheme_in_use, guard_chain, token_handling, refresh_strategy, output_format]
  fallback: _examples/auth-reviewer.md

- name: tenant-isolation-reviewer
  kind: agent
  triggers: { signal_confirmed: multi-tenant }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" § multi-tenant + _extracted-idioms.md (repo base — auto-tenant-filter)
  sections: [persona, premise, halt_conditions, isolation_contract, probe_kit, places_to_audit, escape_hatch_audit, layer2_grading, output_format, hard_rules, sibling_boundaries]
  fallback: _examples/tenant-isolation-reviewer.md   # was `stub-from-sections`: on greenfield the highest-value reviewer in this pack materialised with no premise, no halt conditions, no probes and no sibling boundaries

- name: data-privacy-reviewer
  kind: agent
  triggers: { signal_confirmed_any: [compliance, pii, payment] }
  extracts_from: _extracted-codebase.md § "Data model" (PII/PHI fields + classification tags) + § "Cross-cutting concerns" § compliance + collection/log/analytics/third-party-SDK sinks + configured jurisdiction(s)
  sections: [persona, pii_inventory, dataflow_egress_checklist, regulation_mapping, output_format]
  fallback: _examples/data-privacy-reviewer.md
  cite_evidence: strict

- name: auth-flow
  kind: pattern
  triggers: { auth_scheme_detected: true }
  extracts_from: _extracted-codebase.md § Auth + sample login/refresh handlers
  sections: [overview, scheme, token_lifecycle, guard_application, refresh_handling, logout, examples_from_codebase, pitfalls]
  mirror_existing: true
  fallback: _examples/auth-flow.md

- name: zero-trust
  kind: pattern
  triggers: { signal_confirmed_any: [multi-tenant, payment, compliance] }
  extracts_from: _extracted-codebase.md § Auth + § "Cross-cutting concerns"
  sections: [overview, principles_for_this_app, deny_by_default_examples, secret_handling, audit_trail]
  fallback: _examples/zero-trust.md

- name: tenant-isolation
  kind: pattern
  triggers: { signal_confirmed: multi-tenant }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" § multi-tenant + tenant resolution + query scoping
  sections: [invariant, isolation_layers, review_methodology, detectors]
  mirror_existing: true
  fallback: _examples/tenant-isolation.md

- name: security-principles
  kind: rule
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Auth + § "Cross-cutting concerns" + dynamic/feedback-learned.md
  sections: [project_specific_first, secret_management, input_validation_rule, auth_decorators_required, signal_specific_rules, never_log_secrets]
  mirror_existing: true
  fallback: _examples/security-principles.md

- name: security-audit
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-codebase.md (full)
  sections: [understand, organize, retrieve, generate, update, validate]
  fallback: _examples/security-audit.md

- name: secret-scan
  kind: skill
  triggers: { always: true }
  fallback: _examples/secret-scan.md

- name: ssrf-scan
  kind: skill
  triggers: { grep_evidence: "fetch\\(|axios|httpx|requests\\.get|http\\.Get|open-uri|url|webhook|preview|import.*url|avatar|res\\.redirect|sendRedirect|returnUrl|redirect_uri" }
  extracts_from: _extracted-codebase.md § "API surface" (outbound fetch sinks + user-URL inputs)
  fallback: _examples/ssrf-scan.md

- name: deps-audit
  kind: skill
  triggers: { package_manager_detected: true }
  fallback: _examples/deps-audit.md

- name: threat-model
  kind: skill
  triggers: { always: true }
  fallback: _examples/threat-model.md

- name: dependency-vuln-check
  kind: command
  triggers: { always: true }
  sections: [premise, closure_verbs, mechanical_halt, phases, report_format, hard_rules]
  fallback: commands/dependency-vuln-check.md   # the source IS the fallback (per phase-4.2-apply.md step 2): the prior `stub-from-sections` had no `sections:` list, so a no-signal project received an empty skeleton instead of a command

- name: injection-scan
  kind: skill
  triggers: { always: true }   # every app has an interpreter sink; a repo without one reports each class N/A
  fallback: skills/injection-scan/SKILL.md

- name: file-access-scan
  kind: skill
  triggers: { always: true }   # read sinks (sendFile / open / static mounts) exist even where no upload does
  fallback: skills/file-access-scan/SKILL.md

- name: xss-scan
  kind: skill
  triggers: { always: true }   # covers server-rendered HTML and cookie/CSRF config, not only a frontend
  fallback: skills/xss-scan/SKILL.md

- name: data-exposure-scan
  kind: skill
  triggers: { always: true }
  fallback: skills/data-exposure-scan/SKILL.md

- name: logic-race-scan
  kind: skill
  triggers: { always: true }
  fallback: skills/logic-race-scan/SKILL.md

- name: sast-scan
  kind: skill
  triggers: { always: true }
  fallback: skills/sast-scan/SKILL.md

- name: iac-scan
  kind: skill
  triggers: { always: true }   # a repo with no infra files reports every iac class N/A
  fallback: skills/iac-scan/SKILL.md

- name: ci-security-scan
  kind: skill
  triggers: { ci_config_detected: true }   # /security-audit also dispatches it on any whole-repo run holding a CI file
  fallback: skills/ci-security-scan/SKILL.md

- name: mobile-security-scan
  kind: skill
  triggers: { mobile_framework_detected: true }   # /security-audit also runs it on every whole-repo run; no mobile root → one N/A line
  fallback: skills/mobile-security-scan/SKILL.md

- name: security-fix
  kind: command
  triggers: { always: true }
  fallback: commands/security-fix.md   # the source IS the fallback, as for dependency-vuln-check

- name: security-live-scan
  kind: command
  triggers: { always: true }
  fallback: commands/security-live-scan.md
```
