# Mobile pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: mobile-architect
  kind: agent
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-codebase.md § Stack (mobile framework) + § Modules
  sections: [persona, framework_in_use, navigation_strategy, state_strategy, native_module_strategy, offline_strategy, output_format]
  fallback: _examples/mobile-architect.md
  cite_evidence: strict

- name: mobile-principles
  kind: rule
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-codebase.md § Conventions
  sections: [project_specific_first, platform_parity, accessibility_required, performance_budgets, secret_handling_in_mobile, store_compliance]
  mirror_existing: true
  fallback: _examples/mobile-principles.md

- name: app-store-reviewer
  kind: agent
  triggers: { mobile_framework_detected: true }
  sections: [pre_flight, invariants, audit_dimensions, output_format, hard_rules]
  fallback: agents/app-store-reviewer.md

- name: add-screen
  kind: command
  triggers: { mobile_framework_detected: true }
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  fallback: commands/add-screen.md

- name: add-feature
  kind: command
  triggers: { mobile_framework_detected: true }
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  fallback: commands/add-feature.md

- name: optimize-bundle
  kind: command
  triggers: { mobile_framework_detected: true }
  sections: [understand, organize, retrieve, generate, validate, output_format, hard_rules]
  fallback: commands/optimize-bundle.md

- name: bundle-analyze
  kind: skill
  triggers: { mobile_framework_detected: true }
  sections: [when_to_use, procedure, inputs, outputs, failure_modes]
  fallback: skills/bundle-analyze.md

- name: native-bridge-audit
  kind: skill
  triggers: { mobile_framework_detected: true, native_bridge_present: true }
  sections: [when_to_use, procedure, inputs, outputs, hard_rules]
  fallback: skills/native-bridge-audit.md

- name: offline-sync
  kind: ai-pattern
  triggers: { mobile_framework_detected: true }
  sections: [problem, decision_tree, components, anti_patterns, testing]
  fallback: ai-patterns/offline-sync.md

- name: native-storage
  kind: ai-pattern
  triggers: { mobile_framework_detected: true }
  sections: [decision_matrix, hard_rules, anti_patterns, encryption_decision_tree, testing]
  fallback: ai-patterns/native-storage.md

- name: deep-linking
  kind: ai-pattern
  triggers: { mobile_framework_detected: true }
  sections: [why, three_layers, routing_pattern, defensive_patterns, testing, anti_patterns]
  fallback: ai-patterns/deep-linking.md
```
