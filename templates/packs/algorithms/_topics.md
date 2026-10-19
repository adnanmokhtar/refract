# Algorithms pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

This pack is stack-agnostic — algorithms + complexity are language-independent, so every topic triggers `always`. Extraction supplies the *project's* concrete details (its language's standard containers and their costs, its test framework for property/adversarial tests, its hot paths); the reasoning discipline is fixed. Most topics have no `_examples/` stub, so those fallbacks point at the live sources; the signal-gated patterns ship an abridged `_examples/` snapshot.

```yaml
- name: algorithm-designer
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Stack (language → standard containers + their documented complexities) + § Conventions (scale / hot-path signals)
  sections: [persona, contract, premise, halt_conditions, three_modes, boundary, deriving_complexity, design_method, judge_mode, vocabulary, output, hard_rules]
  fallback: agents/algorithm-designer.md
  cite_evidence: strict

- name: design-algorithm
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Stack (language + standard libs) + § Conventions (test framework, property library or own fuzzer — the oracle harness)
  sections: [premise, comparison_table, when_to_use, when_not_to_use, prerequisites, args, design_mode, from_audit_lane, closure_table, output, hard_rules, failure_modes, related, stack_scope]
  fallback: commands/design-algorithm.md
  cite_evidence: strict

- name: analyze-complexity
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Modules (production roots, entry points, collection-scale data) + § Stack (analyzer pins, property harness)
  sections: [coverage_ledger, premise, hand_wave_halt, when_to_use, phases, intent_gate, static_lane, tool_lane, runtime_lane, routed_classes, context_map, verification, severity, class_ledger, production_bar, verdict, report, output, what_to_do_next, failure_modes, related]
  fallback: commands/analyze-complexity.md
  cite_evidence: strict

- name: complexity-derivation
  kind: skill
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Stack (the language's container/op complexity guarantees)
  sections: [premise, when_to_run, inputs, procedure, outputs, halt_conditions, related]
  fallback: skills/complexity-derivation/SKILL.md
  cite_evidence: strict

- name: complexity-scan
  kind: skill
  triggers: { always: true }   # every repo loops over data; a repo with no data-sized loop reports each class with its counts
  extracts_from: _extracted-codebase.md § Stack (languages, analyzer pins) + § Modules (request, job and consumer roots)
  fallback: skills/complexity-scan/SKILL.md   # source-as-fallback; ships scripts/algo-sites.py

- name: algorithm-contract-scan
  kind: skill
  triggers: { always: true }   # sorts, indexes and draws exist everywhere; GE classes print N/A from grep 0b when no geo code exists
  extracts_from: _extracted-codebase.md § Stack (languages, geo and property-test libraries) + § Data layer (unique constraints)
  fallback: skills/algorithm-contract-scan/SKILL.md   # source-as-fallback

- name: numeric-stability-scan
  kind: skill
  triggers:
    grep_evidence: "^\\s*(?:import|from)\\s+(?:numpy|scipy|pandas|polars|statsmodels|sklearn|torch|jax|numba|mpmath|statistics)\\b|[\"'](?:mathjs|simple-statistics|ml-matrix|@tensorflow/tfjs[\\w-]*)[\"']|gonum\\.org/v1/gonum|\\bBF\\.RESERVE\\b|\\bBloomFilter\\b|\\bHyperLogLog\\b|\\bPFADD\\b|\\bCountMinSketch\\b|-ffast-math|fastmath\\s*=\\s*True"
    OR_codebase_section: "the project computes statistics, scores, simulations or linear algebra, or uses a probabilistic structure (signal-gated: grep G prints the gate)"
  extracts_from: _extracted-codebase.md § Stack (numeric libraries, build flags) + § Modules (analytics, scoring, ML)
  fallback: skills/numeric-stability-scan/SKILL.md   # source-as-fallback

- name: sublinear-structures
  kind: pattern
  triggers: { grep_evidence: "\\bBF\\.(?:RESERVE|ADD|EXISTS)\\b|\\bBloomFilter\\b|\\bbloom-filters\\b|\\bpybloom|\\bpyprobables\\b|\\bHyperLogLog\\b|\\bPF(?:ADD|COUNT)\\b|\\bpf(?:add|count)\\(|\\bCountMinSketch\\b|\\bCMS\\.\\w+|\\bTDigest\\b|\\bCuckooFilter\\b" }   # library- and command-anchored; the old word list (`count.?min`, `sketch`, `streaming`) matched UI and counters
  extracts_from: _extracted-codebase.md § Stack (streaming / large-scale / cardinality signals) + the library's probabilistic-structure options
  sections: [when_to_use, structures_table, sizing, detectors, routed, closure_verbs]
  mirror_existing: true
  fallback: ai-patterns/sublinear-structures.md

- name: numerical-methods
  kind: pattern
  triggers: { grep_evidence: "^\\s*(?:import|from)\\s+(?:numpy|scipy|pandas|polars|statsmodels|sklearn|torch|jax|numba|mpmath|statistics)\\b|[\"'](?:mathjs|simple-statistics|ml-matrix|@tensorflow/tfjs[\\w-]*)[\"']|gonum\\.org/v1/gonum|org\\.apache\\.commons\\.math3?|MathNet\\.Numerics|\\buse\\s+(?:ndarray|nalgebra|statrs)\\b|\\bnp\\.linalg\\b|\\b(?:pvariance|pstdev|logsumexp|log_softmax|lstsq)\\s*\\(" }   # numeric libraries and anchored calls (numeric-stability-scan grep G); the old word gate matched 30 % of a CRUD repo
  extracts_from: _extracted-codebase.md § Stack (numeric / scientific libs + float precision) + § Modules (hot numeric paths)
  sections: [gate, regimes, detectors, routed, closure_verbs]
  mirror_existing: true
  fallback: _examples/numerical-methods.md

- name: algorithm-principles
  kind: rule
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Stack (standard containers + their complexities) + § Conventions
  sections: [must, must_not, should, enforcement]
  fallback: rules/algorithm-principles.md
  mirror_existing: true
```
