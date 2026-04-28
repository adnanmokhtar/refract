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
```
