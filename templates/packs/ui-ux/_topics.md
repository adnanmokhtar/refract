# UI/UX pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: design-system-architect
  kind: agent
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md § Stack (UI lib + design tokens dir if any) + sample components
  sections: [persona, current_state, token_strategy, component_taxonomy, contribution_workflow, output_format]
  fallback: _examples/design-system-architect.md
  cite_evidence: strict

- name: design-system-guardian
  kind: agent
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md (component dir + design tokens)
  sections: [persona, drift_detection, ad_hoc_style_flagging, output_format]
  fallback: _examples/design-system-guardian.md

- name: theme-specialist
  kind: agent
  triggers: { multi_theme_signal_detected: true }
  extracts_from: _extracted-codebase.md (theme dir / variants) + ai/patterns/theme.md if exists
  sections: [persona, theme_architecture, parity_rules, output_format]
  fallback: _examples/theme-specialist.md

- name: ux-reviewer
  kind: agent
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-business.md § "Target users" + _extracted-codebase.md § "API surface"
  sections: [persona, persona_aware_review, micro_copy_audit, error_state_audit, output_format]
  fallback: _examples/ux-reviewer.md

- name: design-systems
  kind: pattern
  triggers: { primary_frontend_framework_detected: true }
  fallback: _examples/design-systems.md

- name: theming
  kind: pattern
  triggers: { multi_theme_signal_detected: true }
  fallback: _examples/theming.md

- name: dark-mode
  kind: pattern
  triggers: { dark_mode_capability_detected: true }
  fallback: _examples/dark-mode.md

- name: motion
  kind: pattern
  triggers: { animation_lib_detected_OR_motion_components_present: true }
  fallback: _examples/motion.md

- name: rtl
  kind: pattern
  triggers: { rtl_locale_detected: true }
  extracts_from: _extracted-business.md (constraints — RTL required?) + sample components
  sections: [overview, rtl_strategy, logical_properties_required, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/rtl.md

- name: ui-principles
  kind: rule
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-codebase.md § Conventions (frontend) + _extracted-business.md (personas — affects micro-copy tone)
  sections: [project_specific_first, design_token_use, component_composition, accessibility_required, micro_copy_voice]
  mirror_existing: true
  fallback: _examples/ui-principles.md

- name: design-review
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  fallback: _examples/design-review.md

- name: redesign
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-idioms.md § Wrappers (shared component library) + _extracted-codebase.md § Stack (design-token source + i18n/RTL setup) + _extracted-business.md (personas — affects UX direction)
  sections: [premise, comparison_table, when_to_use, when_not_to_use, prerequisites, args, agent_job, phases, approval_gate, output, hard_rules, failure_modes, cross_references, stack_scope]
  fallback: commands/redesign.md
  cite_evidence: strict

- name: ui-crawl
  kind: command
  triggers: { primary_frontend_framework_detected: true, e2e_browser_runner_supported: true }
  extracts_from: _extracted-codebase.md § Stack (test root + package runner) + _extracted-idioms.md § Wrappers (sidebar config + route manifest path) + _extracted-business.md § Auth (test-account selectors)
  sections: [premise, when_to_use, prerequisites, what_it_produces, phases, flags, severity_scoring, hard_rules, output, cross_references, implementation_notes]
  fallback: commands/ui-crawl.md
  cite_evidence: strict

- name: ui-crawl-fix
  kind: command
  triggers: { primary_frontend_framework_detected: true, e2e_browser_runner_supported: true }
  extracts_from: _extracted-idioms.md § Wrappers (FormField / CrudActions / TableActions / BaseModal / sanitize helper / translation builder) + align/rules/align-discipline.md § closure verbs
  sections: [premise, when_to_use, auto_fixable_classes, not_auto_fixed, phases, flags, hard_rules, output, cross_references, stack_scope]
  fallback: commands/ui-crawl-fix.md
  cite_evidence: strict

- name: design-token-audit
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  sections: [when_to_use, procedure, inputs, outputs, failure_modes]
  fallback: skills/design-token-audit.md

- name: motion-audit
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  sections: [when_to_use, procedure, inputs, outputs, failure_modes]
  fallback: skills/motion-audit.md

- name: a11y-quick-check
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  sections: [when_to_use, procedure, inputs, outputs, failure_modes]
  fallback: skills/a11y-quick-check.md

- name: ui-design-sweep
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-idioms.md § Tokens / Wrappers / Surfaces / Voice / Breakpoints + ui-principles.md § Axis catalog
  sections: [purpose, when_to_use, inputs, outputs, the_18_closure_verbs, procedure, hard_rules, failure_modes]
  fallback: skills/ui-design-sweep.md
  cite_evidence: strict
```
