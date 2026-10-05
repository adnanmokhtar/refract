# Delivery pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`. Every topic here is source-as-fallback:
the orchestrator and its agents are a contract between files, not prose to re-author from a
project's extraction, so each `fallback:` names the shipped source and it is delivered in full.

```yaml
- name: add-feature
  kind: command
  triggers: { always: true }
  extracts_from: none — the run contract is project-independent (templates/snippets/run-ledger.md)
  sections: [premise, contract, roles, p0, p1, p2, p3, p4, p5, p6, p7, p8_p11, p12, loop_control, output, hard_rules]
  dispatches: product-analyst, requirements-reviewer, architect, architecture-reviewer, test-engineer, plan-critic, implementer, verifier
  fallback: commands/add-feature.md

- name: product-analyst
  kind: agent
  triggers: { always: true }
  extracts_from: ai/business-domain.md + ai/users-and-personas.md (vocabulary the requirements must use)
  sections: [premise, contract, method, output, hard_rules]
  fallback: agents/product-analyst.md

- name: requirements-reviewer
  kind: agent
  triggers: { always: true }
  extracts_from: ai/business-domain.md (vocabulary) + _extracted-codebase.md § Modules (surfaces requirements land on)
  sections: [premise, contract, preflight, review_dimensions, severity, output, hard_rules]
  fallback: agents/requirements-reviewer.md

- name: architect
  kind: agent
  triggers: { always: true }
  extracts_from: ai/architecture.md + ai/modules.md + ai/_decision-index.md
  sections: [premise, contract, method, output, hard_rules]
  fallback: agents/architect.md

- name: architecture-reviewer
  kind: agent
  triggers: { always: true }
  extracts_from: ai/architecture.md + ai/modules.md
  sections: [premise, contract, mode_design, mode_conformance, output, hard_rules]
  fallback: agents/architecture-reviewer.md

- name: test-engineer
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Tests (runner, layout, helpers)
  sections: [premise, contract, run_mode, standalone_mode, output, hard_rules]
  fallback: agents/test-engineer.md

- name: plan-critic
  kind: agent
  triggers: { always: true }
  extracts_from: ai/project-goals.md (the scope rubric)
  sections: [premise, contract, checks, output, hard_rules]
  fallback: agents/plan-critic.md

- name: implementer
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-idioms.md (sibling shapes the lane skills mirror)
  sections: [premise, contract, method, hard_rules]
  fallback: agents/implementer.md

- name: lane-backend
  kind: skill
  triggers: { primary_framework_detected: true }
  extracts_from: _extracted-idioms.md § backend (controller / service / repository shapes)
  sections: [premise, prior_art, sibling_shape_halt, new_dependency, floors, standards, signals, constraints, retrieve, generate, update, validate, improve]
  fallback: skills/lane-backend/SKILL.md

- name: lane-frontend
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-idioms.md § frontend (page / component / wrapper shapes)
  sections: [premise, invariants, understand, design_slice, retrieve, generate, update, validate, improve]
  fallback: skills/lane-frontend/SKILL.md

- name: lane-mobile
  kind: skill
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-idioms.md § mobile (screen / navigation / offline shapes)
  sections: [premise, invariants, understand, design_slice, retrieve, generate, update, validate, improve]
  fallback: skills/lane-mobile/SKILL.md
```
