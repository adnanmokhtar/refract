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

- name: creative-director
  kind: agent
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-business.md (differentiating promise + goals) + ai/users-and-personas.md (personas) + _extracted-codebase.md § Stack (UI lib + design-token source) + _extracted-idioms.md § Tokens / Surfaces / Voice + sample surfaces
  sections: [persona, premise, halt_conditions, invariants, diagnosis_vocabulary, direction_rubric, diverge_method, invention_vocabulary, converge_method, modes, usability_floor, output_brief, hard_rules, failure_modes]
  fallback: agents/creative-director.md
  cite_evidence: strict

- name: axis-catalog
  kind: pattern
  triggers: { primary_frontend_framework_detected: true }
  fallback: ai-patterns/axis-catalog.md   # source IS the fallback: the closed 16-axis / 19-verb
                                          # vocabulary is cited verbatim by ui-design-sweep,
                                          # creative-director, /art-direct and four mobile
                                          # artifacts — an abridgement that dropped a row would
                                          # silently break the counts they cite.

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
  fallback: rules/ui-principles.md
  # self-fallback, matching mobile/rules/{mobile-principles,render-discipline}. The `_examples/`
  # abridgement was deleted at 1.25.1: at 97% of the source (62 vs 65 lines) it was never the
  # "rewritten in its own voice" artifact this directory is for, and its 3% delta was subtractive —
  # it dropped `severity: must` + `applies-to:`, so a greenfield install (the ONLY path that reads a
  # fallback) got the pack's one rule with nothing marking it as one, plus five imperatives demoted
  # to noun phrases ("Use 3 baseline breakpoints" -> "3 baseline breakpoints"). Check 8b sees
  # neither: it exempts `severity:` on rule fallbacks as a whole-class convention.

- name: design-review
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  fallback: _examples/design-review.md

- name: redesign
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-idioms.md § Wrappers (shared component library) + _extracted-codebase.md § Stack (design-token source + i18n/RTL setup) + _extracted-business.md (personas — affects UX direction)
  sections: [premise, comparison_table, when_to_use, when_not_to_use, prerequisites, args, agent_job, design_principles_rubric, phases, diagnose_design_critique, approval_gate, design_quality_scorecard, output, hard_rules, failure_modes, cross_references, stack_scope]
  fallback: commands/redesign.md
  cite_evidence: strict

- name: art-direct
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-business.md (differentiating promise + goals) + ai/users-and-personas.md (personas) + _extracted-idioms.md § Tokens / Wrappers / Surfaces / Voice / Breakpoints (existing visual world) + _extracted-codebase.md § Stack (design-token source + i18n/RTL setup)
  sections: [premise, comparison_table, modes, when_to_use, when_not_to_use, prerequisites, args, agent_job, phases, approval_gate, yes_flag, diagnose_redline, diverge_directions, encodability_table, build_chain, output, hard_rules, failure_modes, cross_references, stack_scope]
  fallback: commands/art-direct.md
  cite_evidence: strict

- name: add-theme-variant
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-idioms.md § Tokens / Wrappers / Surfaces (the default theme's token system + full component set) + _extracted-codebase.md § Stack (theme-resolution mechanism + SSR discipline + i18n/RTL setup + the perf rule the new theme must satisfy)
  sections: [premise, comparison_table, when_to_use, when_not_to_use, prerequisites, args, four_pillars, phases, gates, output, hard_rules, failure_modes, cross_references, stack_scope]
  fallback: commands/add-theme-variant.md
  cite_evidence: strict

- name: clone-design
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: none — Stage 1 is project-optional (clones an EXTERNAL reference into a folder; needs no in-repo idioms). Only --adopt reads the project (delegates to /add-theme-variant + /redesign, which carry their own extracts_from).
  sections: [premise, two_stage_split, comparison_table, when_to_use, when_not_to_use, args, four_pillars, flow, gates, output, hard_rules, failure_modes, cross_references, stack_scope]
  fallback: commands/clone-design.md
  cite_evidence: strict

- name: grab-site
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: none — project-optional + stack-agnostic (mirrors an EXTERNAL live site into a folder; needs only python3, no in-repo idioms).
  sections: [premise, comparison_table, when_to_use, when_not_to_use, args, mechanism_bundled_script, gates, output, hard_rules, failure_modes, cross_references, stack_scope]
  fallback: commands/grab-site.md
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
  extracts_from: _extracted-idioms.md § Wrappers (FormField / CrudActions / TableActions / BaseModal / sanitize helper / translation builder) + align/rules/align-discipline.md § Per-finding audit
  sections: [premise, when_to_use, auto_fixable_classes, not_auto_fixed, phases, flags, hard_rules, output, cross_references, stack_scope]
  fallback: commands/ui-crawl-fix.md
  cite_evidence: strict

- name: enhance-ui
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-idioms.md § Wrappers / Tokens (scope-tier detection inputs) + _extracted-codebase.md § Stack (design-token source + i18n/RTL setup)
  sections: [premise, plan_flag, composes, when_to_use, when_not_to_use, examples, scope_tier_detection, phases, hard_rules, cross_references, stack_scope]
  fallback: commands/enhance-ui.md
  cite_evidence: strict

- name: ui-sweep
  kind: command
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-idioms.md § Tokens / Wrappers / Surfaces / Voice / Breakpoints + _extracted-codebase.md § Stack (route manifest + test runner for screenshots)
  sections: [premise, what_it_does_that_align_does_not, when_to_use, detectors, metrics_with_targets, phases_by_user_flow, ui_ux_verbs, output_visual_report, hard_rules, cross_references, stack_scope]
  fallback: commands/ui-sweep.md
  cite_evidence: strict

- name: design-token-audit
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  sections: [when_to_use, procedure, inputs, outputs, failure_modes]
  fallback: skills/design-token-audit/SKILL.md

- name: motion-audit
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  sections: [when_to_use, procedure, inputs, outputs, failure_modes]
  fallback: skills/motion-audit/SKILL.md

- name: a11y-quick-check
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  sections: [when_to_use, procedure, inputs, outputs, failure_modes]
  fallback: skills/a11y-quick-check/SKILL.md

- name: design-iterate
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  sections: [when_to_use, modes, procedure, inputs, outputs, failure_modes]
  fallback: skills/design-iterate/SKILL.md

- name: ui-design-sweep
  kind: skill
  triggers: { primary_frontend_framework_detected: true }
  extracts_from: _extracted-idioms.md § Tokens / Wrappers / Surfaces / Voice / Breakpoints + ai-patterns/axis-catalog.md (the per-axis heuristics; ui-principles.md § Axis catalog holds the closed names)
  sections: [purpose, when_to_use, inputs, outputs, the_19_closure_verbs, procedure, hard_rules, failure_modes]
  fallback: skills/ui-design-sweep/SKILL.md
  cite_evidence: strict
```
