# Algorithms pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

This pack is stack-agnostic — algorithms + complexity are language-independent, so every topic triggers `always`. Extraction supplies the *project's* concrete details (its language's standard containers and their costs, its test framework for property/adversarial tests, its hot paths); the reasoning discipline is fixed. No `_examples/` stubs exist, so fallbacks point at the live sources.

```yaml
- name: algorithm-designer
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Stack (language → standard containers + their documented complexities) + § Conventions (scale / hot-path signals)
  sections: [persona, premise, halt_conditions, two_modes, boundary, deriving_complexity, design_method, detection_vocabulary, output, hard_rules]
  fallback: agents/algorithm-designer.md
  cite_evidence: strict

- name: design-algorithm
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Stack (language + standard libs) + § Conventions (test framework — for the property/adversarial suite)
  sections: [premise, comparison_table, when_to_use, when_not_to_use, prerequisites, args, phases, output, hard_rules, failure_modes, cross_references, stack_scope]
  fallback: commands/design-algorithm.md
  cite_evidence: strict

- name: analyze-complexity
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Stack (language → container costs) + § Modules (hot paths / collection-scale data)
  sections: [premise, when_to_use, when_not_to_use, prerequisites, args, phases, output, hard_rules, failure_modes, cross_references, stack_scope]
  fallback: commands/analyze-complexity.md
  cite_evidence: strict

- name: complexity-derivation
  kind: skill
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Stack (the language's container/op complexity guarantees)
  sections: [purpose, when_to_use, inputs, procedure, outputs, failure_modes]
  fallback: skills/complexity-derivation.md
  cite_evidence: strict

- name: algorithm-principles
  kind: rule
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Stack (standard containers + their complexities) + § Conventions
  sections: [must, must_not]
  fallback: rules/algorithm-principles.md
  mirror_existing: true
```
