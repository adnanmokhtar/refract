# Product pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
# requirements-reviewer — single owner: the delivery pack (templates/packs/delivery/agents/requirements-reviewer.md,
# topic in delivery/_topics.md). delivery is always-on and applied first, so its agent always claims the name;
# product dispatches @requirements-reviewer from /audit-requirements --spec and ships no copy of its own.

- name: product-strategist
  kind: agent
  triggers: { always: true }
  extracts_from: ai/project-goals.md + ai/users-and-personas.md + ai/business-model.md + _extracted-codebase.md § Modules (what exists today)
  sections: [persona, halt_conditions, problem_statement, evidence_classes, alternatives, metric_pair, kill_criteria, output_format]
  mirror_existing: true
  fallback: _examples/product-strategist.md
  cite_evidence: strict

- name: user-research-synthesizer
  kind: agent
  triggers: { business_domain_detected: true }
  extracts_from: ai/users-and-personas.md (prior claims to test against) + ai/product/research/ if present
  sections: [persona, halt_conditions, material_inventory, coding_method, evidence_classes, saturation, output_format]
  mirror_existing: true
  fallback: _examples/user-research-synthesizer.md

- name: scope-arbiter
  kind: agent
  triggers: { always: true }
  extracts_from: ai/roadmap.md + ai/status.md (the candidate scope) + ai/project-goals.md (the rubric)
  sections: [persona, halt_conditions, rubric, method, scope_ledger, output_format]
  mirror_existing: true
  fallback: _examples/scope-arbiter.md

- name: problem-framing
  kind: pattern
  triggers: { always: true }
  extracts_from: ai/project-goals.md + ai/users-and-personas.md + ai/competitive-context.md
  sections: [overview, mechanism_test, the_five_slots, evidence_classes, do_nothing_baseline, metric_pair, kill_criteria, detectors]
  mirror_existing: true
  fallback: _examples/problem-framing.md
  cite_evidence: strict

- name: acceptance-criteria
  kind: pattern
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Modules (existing surfaces + their states) + ai/conventions.md (how criteria are written here)
  sections: [overview, falsifiability_test, the_four_tests, failure_classes, numeric_bounds, coverage_grid, non_functional_bounds, detectors]
  mirror_existing: true
  fallback: _examples/acceptance-criteria.md
  cite_evidence: strict

- name: research-synthesis
  kind: pattern
  triggers: { business_domain_detected: true }
  extracts_from: ai/users-and-personas.md + ai/product/research/ if present
  sections: [overview, inventory_before_themes, observed_said_interpreted, denominators, saturation, disconfirming_material, limits, detectors]
  mirror_existing: true
  fallback: ai-patterns/research-synthesis.md

- name: opportunity-sizing
  kind: pattern
  triggers: { business_domain_detected: true }
  extracts_from: ai/business-model.md + ai/project-goals.md (the metric a sizing is denominated in)
  sections: [overview, the_shape, input_labels, confidence_is_the_weakest_link, ranges, do_nothing_row, double_counting, detectors]
  mirror_existing: true
  fallback: ai-patterns/opportunity-sizing.md

- name: product-principles
  kind: rule
  triggers: { always: true }
  extracts_from: ai/conventions.md + ai/business-domain.md + dynamic/feedback-learned.md
  sections: [project_specific_first, evidence_labelling, falsifiable_criteria, coverage_grid, metric_pair, kill_criteria, enforcement]
  mirror_existing: true
  fallback: _examples/product-principles.md

- name: frame-problem
  kind: command
  triggers: { always: true }
  extracts_from: ai/project-goals.md + ai/users-and-personas.md + ai/competitive-context.md
  sections: [understand, organize, retrieve, generate, update]
  dispatches: product-strategist
  fallback: commands/frame-problem.md

- name: audit-requirements
  kind: command
  triggers: { always: true }
  extracts_from: ai/business-domain.md (vocabulary) + ai/conventions.md (how criteria are written here) + _extracted-codebase.md § Modules (the surfaces --repo joins) + ai/product/ (success files, tracking plan)
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  dispatches: requirements-reviewer   # owned by the delivery pack (always installed); --spec lane only
  fallback: commands/audit-requirements.md   # the source IS the fallback: two lanes, the class ledger and the verdict are the contract

- name: product-fix
  kind: command
  triggers: { always: true }
  fallback: commands/product-fix.md   # the source IS the fallback, as for db-fix

- name: synthesize-research
  kind: command
  triggers: { business_domain_detected: true }
  extracts_from: ai/users-and-personas.md + ai/product/research/ if present
  sections: [understand, organize, retrieve, generate, update]
  dispatches: user-research-synthesizer
  fallback: commands/synthesize-research.md

- name: define-success
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Observability (what can be measured today) + ai/project-goals.md
  sections: [understand, organize, retrieve, generate, update, validate]
  fallback: commands/define-success.md

- name: to-questionnaire
  kind: command
  triggers: { always: true }
  extracts_from: ai/core/glossary.md (the recipient's vocabulary) + ai/product/briefs/ + ai/product/assumptions.md (the ranked unknowns worth sending) + ai/decisions/ (questions already settled)
  sections: [understand, organize, retrieve, generate, update]
  fallback: commands/to-questionnaire.md

- name: acceptance-criteria-check
  kind: skill
  triggers: { always: true }   # the shape lane needs only a spec; the trace lane prints N/A (no criterion ids) where none exist
  fallback: skills/acceptance-criteria-check/SKILL.md

- name: evidence-trace
  kind: skill
  triggers: { always: true }
  fallback: skills/evidence-trace/SKILL.md

- name: assumption-ledger
  kind: skill
  triggers: { always: true }
  fallback: skills/assumption-ledger/SKILL.md

- name: launch-readiness
  kind: skill
  triggers: { always: true }   # the repo scorecard runs on any repo; feature scope needs ai/product/success/<slug>.md
  fallback: skills/launch-readiness/SKILL.md   # ships rules.json + scripts/readiness-score.py beside it

- name: feature-surface-scan
  kind: skill
  triggers: { always: true }   # an absent surface (no client, no routes) reports each class N/A
  fallback: skills/feature-surface-scan/SKILL.md

- name: tracking-plan-scan
  kind: skill
  triggers: { always: true }   # no analytics calls → N/A; calls with no plan → one Hardening inventory row
  fallback: skills/tracking-plan-scan/SKILL.md

- name: entitlement-consistency-scan
  kind: skill
  triggers: { always: true }   # no plans or catalog → each class N/A
  fallback: skills/entitlement-consistency-scan/SKILL.md
```
