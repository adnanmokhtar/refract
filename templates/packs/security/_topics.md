# Security pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: security-auditor
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" + § Auth + § "Anti-patterns" + ai/failures/_index.md if exists
  sections: [persona, owasp_checklist_for_this_stack, auth_review_for_this_app, signal_specific_checks, output_format]
  fallback: _examples/security-auditor.md
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
  sections: [persona, isolation_contract, places_to_audit, escape_hatch_audit, output_format]
  fallback: _examples/tenant-isolation-reviewer.md

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

- name: deps-audit
  kind: skill
  triggers: { package_manager_detected: true }
  fallback: _examples/deps-audit.md

- name: threat-model
  kind: skill
  triggers: { always: true }
  fallback: _examples/threat-model.md
```
