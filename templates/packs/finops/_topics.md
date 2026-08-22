# FinOps pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: cost-architect
  kind: agent
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  extracts_from: _extracted-codebase.md § Infrastructure (provider, managed services, regions/zones) + § Modules (component topology)
  sections: [persona, halt_conditions, pricing_dimensions_in_this_stack, driver_tree, option_comparison, budget_and_guardrail, output_format]
  mirror_existing: true
  fallback: _examples/cost-architect.md
  cite_evidence: strict

- name: cost-reviewer
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Infrastructure + § Modules (hot paths) + § Cross-cutting concerns (logging, retention, retries)
  sections: [persona, halt_conditions, mechanism_checklist, magnitude_rules, findings_ledger, output_format]
  mirror_existing: true
  fallback: _examples/cost-reviewer.md
  cite_evidence: strict

- name: finops-analyst
  kind: agent
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  extracts_from: _extracted-codebase.md § Infrastructure (account/project structure, tagging) + ai/finops/unit-economics.md if present
  sections: [persona, halt_conditions, normalisation, grouping_axes, unit_costs, delta_classification, output_format]
  mirror_existing: true
  fallback: _examples/finops-analyst.md

- name: unit-economics
  kind: pattern
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Infrastructure (billed components) + ai/business-domain.md (the business unit)
  sections: [overview, driver_tree, denominator, the_three_labels, error_bar, reconciliation, contribution_margin, change_decomposition, detectors]
  mirror_existing: true
  fallback: _examples/unit-economics.md
  cite_evidence: strict

- name: spend-allocation
  kind: pattern
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  extracts_from: _extracted-codebase.md § Infrastructure (tagging/labelling in the IaC modules, account structure)
  sections: [overview, coverage_by_dollar, four_categories, enforcement_at_creation, taxonomy, shared_cost, showback, detectors]
  mirror_existing: true
  fallback: ai-patterns/spend-allocation.md

- name: commitment-strategy
  kind: pattern
  triggers: { terraform_detected: true }
  extracts_from: _extracted-codebase.md § Infrastructure (long-lived compute/capacity shapes)
  sections: [overview, coverage_vs_utilisation, sustained_floor, break_even, flexibility, term_and_payment, expiry_as_decision, detectors]
  mirror_existing: true
  fallback: ai-patterns/commitment-strategy.md

- name: cost-anomaly-detection
  kind: pattern
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  extracts_from: _extracted-codebase.md § Observability (alert routing conventions) + § Infrastructure (groupings with material spend)
  sections: [overview, per_dimension, level_and_rate_of_change, seasonality, threshold_derivation, recipient_and_action, suppression, prove_it_fires, detectors]
  mirror_existing: true
  fallback: ai-patterns/cost-anomaly-detection.md

- name: finops-principles
  kind: rule
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Infrastructure + § Anti-patterns + dynamic/feedback-learned.md
  sections: [project_specific_first, sourced_numbers, retention_defaults, allocation_tags, bounded_retries, threshold_derivation, enforcement]
  mirror_existing: true
  fallback: _examples/finops-principles.md

- name: cost-model
  kind: command
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  extracts_from: _extracted-codebase.md § Infrastructure (billed components) + ai/business-domain.md (unit + denominator)
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  dispatches: finops-analyst
  fallback: commands/cost-model.md

- name: cost-review
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Modules (hot paths) + § Infrastructure (IaC layout)
  sections: [understand, organize, retrieve, validate]
  dispatches: cost-reviewer
  fallback: commands/cost-review.md

- name: audit-cost-attribution
  kind: command
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  extracts_from: _extracted-codebase.md § Infrastructure (tagging in IaC modules, account structure)
  sections: [understand, organize, retrieve, update, validate]
  dispatches: finops-analyst
  fallback: commands/audit-cost-attribution.md

- name: cost-guardrails
  kind: command
  triggers: { ci_config_detected: true }
  extracts_from: _extracted-codebase.md § Infrastructure + § Observability (existing alert routing to reuse)
  sections: [understand, organize, retrieve, generate, update, validate]
  fallback: commands/cost-guardrails.md

- name: unit-cost-probe
  kind: skill
  triggers: { always: true }
  fallback: skills/unit-cost-probe/SKILL.md

- name: commitment-coverage
  kind: skill
  triggers: { terraform_detected: true }
  fallback: skills/commitment-coverage/SKILL.md

- name: egress-trace
  kind: skill
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  fallback: skills/egress-trace/SKILL.md

- name: spend-anomaly-triage
  kind: skill
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  fallback: skills/spend-anomaly-triage/SKILL.md
```
