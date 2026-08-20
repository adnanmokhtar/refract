# Algorithms pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

This pack is stack-agnostic — algorithms + complexity are language-independent, so every topic triggers `always`. Extraction supplies the *project's* concrete details (its language's standard containers and their costs, its test framework for property/adversarial tests, its hot paths); the reasoning discipline is fixed. Most topics have no `_examples/` stub, so those fallbacks point at the live sources; the signal-gated patterns ship an abridged `_examples/` snapshot.

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
  sections: [premise, when_to_run, inputs, procedure, outputs, halt_conditions, related]
  fallback: skills/complexity-derivation/SKILL.md
  cite_evidence: strict

- name: sublinear-structures
  kind: pattern
  triggers: { grep_evidence: "bloom|hyperloglog|hll|count.?min|reservoir|sketch|cardinalit|distinct count|probabilistic|streaming" }
  extracts_from: _extracted-codebase.md § Stack (streaming / large-scale / cardinality signals) + the library's probabilistic-structure options
  sections: [when_to_use, structures_table, sizing, detectors, closure_verbs]
  mirror_existing: true
  fallback: ai-patterns/sublinear-structures.md

- name: numerical-methods
  kind: pattern
  triggers: { grep_evidence: "numpy|scipy|blas|lapack|matrix|linalg|\\bfloat\\b|float64|float32|double|Decimal|BigDecimal|mean|variance|stddev|covariance|dot.?product|norm|eigen|solve|integrate|simulation|Monte.?Carlo" }
  extracts_from: _extracted-codebase.md § Stack (numeric / scientific libs + float precision) + § Modules (hot numeric paths)
  sections: [gate, regimes, detectors, closure_verbs]
  mirror_existing: true
  fallback: _examples/numerical-methods.md

- name: algorithm-principles
  kind: rule
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Stack (standard containers + their complexities) + § Conventions
  sections: [must, must_not, should, review_checklist, enforcement, related]
  fallback: rules/algorithm-principles.md
  mirror_existing: true
```
