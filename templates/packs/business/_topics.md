# Business pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: business-analyst
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-business.md § Mission + § "Target users" + ai/business-domain.md if exists
  sections: [persona, project_business_context, requirement_template, user_story_template, output_format]
  fallback: _examples/business-analyst.md
  cite_evidence: lenient

- name: business-auditor
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-business.md § Mission + § Anti-goals + ai/business-flows.md if exists + _extracted-codebase.md § "API surface"
  sections: [persona, audit_methodology, broken_flow_signals, missing_cycle_signals, gap_findings_format]
  fallback: _examples/business-auditor.md

- name: workflow-integrity
  kind: agent
  triggers:
    grep_evidence: "status\\s*(:|=|==).*'|enum .*(pending|paid|shipped|active|cancelled|closed)|xstate|aasm|state_machine|CHECK\\s*\\(.*status|status_changes|\\b(state|phase)\\b\\s*column"
    OR_codebase_section: "an entity carries a status / state / phase column, a state-machine library config, or scattered `if status ==` checks (a lifecycle exists whether drawn or not)"
  extracts_from: _extracted-business.md § "Business cycles" + ai/business-flows.md if exists (declared lifecycle) + _extracted-codebase.md § "API surface" (status-writing routes / service methods / raw UPDATEs)
  sections: [persona, premise, state_graph_reconstruction, transition_checklist, illegal_edge_findings, state_matrix_output, hard_rules]
  mirror_existing: true
  fallback: _examples/workflow-integrity.md   # business 5/5 — the abridged snapshot faithfully mirrors the live agent's premise + checklist + matrix + hard-rules; keep it in sync on edits
  cite_evidence: strict

- name: domain-model-auditor
  kind: agent
  triggers:
    grep_evidence: "class .*(Model|Entity|Aggregate)|schema\\.(prisma|rb)|@Entity|models\\.Model|ActiveRecord::Base|CheckConstraint|BigDecimal|@Embeddable|value.?object"
    OR_codebase_section: "a domain layer exists — ORM model classes, a schema (schema.prisma / schema.rb), migrations with CHECK / UNIQUE constraints, or entities carrying money / inventory / balance invariants (an aggregate + its invariants exist whether modelled explicitly or not)"
  extracts_from: _extracted-business.md § Mission + .claude/_refine-extract.md § "Domain entities" (extract-domain-entities-deeply per-invariant enforcement+citation blocks) if exists + _extracted-codebase.md § Modules (ORM models / migrations)
  sections: [persona, premise, aggregate_reconstruction, invariant_enforcement_register, boundary_checklist, findings_format, hard_rules]
  fallback: _examples/domain-model-auditor.md
  cite_evidence: strict

- name: analyze-task
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-business.md (full)
  sections: [understand, organize, retrieve, generate]
  fallback: _examples/analyze-task.md

- name: audit-business
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-business.md + _extracted-codebase.md § Modules
  sections: [understand, retrieve, generate]
  fallback: _examples/audit-business.md

- name: expand-task
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-business.md
  sections: [understand, generate]
  fallback: _examples/expand-task.md

- name: suggest-metrics
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-business.md + ai/business-domain.md + ai/users-and-personas.md + the analytics surface
  sections: [understand, retrieve, generate]
  fallback: stub-from-sections

- name: business-completeness
  kind: rule
  triggers: { always: true }
  sections: [must, must_not, should, review_checklist, failure_history_examples]
  fallback: rules/business-completeness.md

- name: audit-funnel-completion
  kind: skill
  triggers: { always: true }
  sections: [when_to_use, procedure, inputs, outputs, failure_modes]
  fallback: skills/audit-funnel-completion.md

- name: check-business-coverage
  kind: skill
  triggers: { always: true }
  sections: [when_to_use, procedure, inputs, outputs, failure_modes]
  fallback: skills/check-business-coverage.md

- name: pricing-tax-audit
  kind: skill
  triggers:
    grep_evidence: "price|amount|invoice|billing|subscription|tax|vat|gst|proration|checkout|stripe|chargebee|Money|currency"
    OR_codebase_section: "the project handles money — pricing, checkout, billing, invoicing, subscriptions, metering, tax, or multi-currency amounts (signal-gated: no billing surface → skip)"
  sections: [premise, when_to_use, money_stack_adapt, detectors, output_format, gotchas, halt]
  fallback: _examples/pricing-tax-audit.md

- name: missing-counterparts
  kind: ai-pattern
  triggers: { always: true }
  sections: [why, forward_inverse_table, completion_table, recovery_table, anti_patterns, detection]
  fallback: ai-patterns/missing-counterparts.md
```
