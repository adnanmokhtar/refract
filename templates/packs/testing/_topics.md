# Testing pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: test-engineer
  kind: agent
  triggers: { test_framework_detected: true }
  extracts_from: _extracted-codebase.md § Tests + § Modules + _extracted-idioms.md (base classes — to know what's mockable)
  sections: [persona, framework_in_use, test_layout, mock_strategy, factory_strategy, project_examples, output_format]
  fallback: _examples/test-engineer.md
  cite_evidence: strict

- name: test-reviewer
  kind: agent
  triggers: { test_framework_detected: true }
  extracts_from: _extracted-codebase.md § Tests + sample tests
  sections: [persona, review_checklist, project_specific_anti_patterns, output_format]
  fallback: _examples/test-reviewer.md

- name: tdd-orchestrator
  kind: agent
  triggers: { test_framework_detected: true }
  extracts_from: _extracted-codebase.md § Tests
  sections: [persona, red_green_refactor, project_test_runner, output_format]
  fallback: _examples/tdd-orchestrator.md

- name: test-strategy
  kind: pattern
  triggers: { test_framework_detected: true }
  extracts_from: _extracted-codebase.md § Tests + § Modules
  sections: [overview, unit_vs_integration_vs_e2e, project_split, what_to_test_at_which_layer, examples_from_codebase, pitfalls]
  mirror_existing: true
  fallback: _examples/test-strategy.md

- name: test-doubles
  kind: pattern
  triggers: { test_framework_detected: true }
  extracts_from: _extracted-codebase.md § Tests (mock lib detected) + sample tests
  sections: [overview, mock_vs_stub_vs_fake, project_mock_lib, when_to_use_each, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/test-doubles.md

- name: testing-principles
  kind: rule
  triggers: { test_framework_detected: true }
  extracts_from: _extracted-codebase.md § Tests + dynamic/feedback-learned.md
  sections: [project_specific_first, test_colocation_rule, mock_rules, db_in_tests_rule, isolation_rule, no_console_in_tests]
  mirror_existing: true
  fallback: _examples/testing-principles.md

- name: add-test
  kind: command
  triggers: { test_framework_detected: true }
  extracts_from: _extracted-codebase.md § Tests
  sections: [understand, organize, retrieve, generate, validate]
  fallback: _examples/add-test.md

- name: flaky-test-hunt
  kind: command
  triggers: { test_framework_detected: true }
  extracts_from: _extracted-codebase.md (CI logs path if known)
  sections: [understand, retrieve, generate]
  fallback: _examples/flaky-test-hunt.md

- name: tdd
  kind: command
  triggers: { test_framework_detected: true }
  extracts_from: _extracted-codebase.md § Tests (runner + assertion style)
  sections: [understand, dispatch, surface]
  dispatches: tdd-orchestrator
  fallback: commands/tdd.md   # source IS the fallback: commands/tdd.md is a 98-line thin
                              # dispatcher ("the discipline lives in the agent") with nothing
                              # project-specific to lose, and its Phase 2 carries the
                              # RED-UNOBSERVABLE substitute-proof rule (:38) that a
                              # 3-heading [understand, dispatch, surface] skeleton discarded.

- name: run-tests
  kind: command
  triggers: { test_framework_detected: true }
  extracts_from: _extracted-codebase.md § Tests (runner + per-scope test commands)
  sections: [understand, retrieve, generate]
  fallback: commands/run-tests.md   # no _examples/ stub — fall back to the live source

- name: coverage-gap
  kind: skill
  triggers: { test_framework_detected: true }
  fallback: _examples/coverage-gap.md

- name: contract-test
  kind: skill
  triggers: { api_surface_detected: true, AND: { test_framework_detected: true } }
  fallback: _examples/contract-test.md

- name: mutation-probe
  kind: skill
  triggers: { test_framework_detected: true }
  fallback: _examples/mutation-probe.md

- name: property-invariants
  kind: skill
  triggers: { test_framework_detected: true }
  fallback: _examples/property-invariants.md

- name: test-factories
  kind: skill
  triggers: { test_framework_detected: true }
  fallback: _examples/test-factories.md

- name: assertion-strength-scan
  kind: skill
  triggers: { test_framework_detected: true }   # a repo with no test files reports every class N/A
  fallback: skills/assertion-strength-scan/SKILL.md

- name: suite-execution-scan
  kind: skill
  triggers: { test_framework_detected: true }   # CI and coverage config are read even when one runner is absent
  fallback: skills/suite-execution-scan/SKILL.md

- name: flake-source-scan
  kind: skill
  triggers: { test_framework_detected: true }   # the static half; /flaky-test-hunt is the runtime harness
  fallback: skills/flake-source-scan/SKILL.md

- name: test-double-scan
  kind: skill
  triggers: { test_framework_detected: true }   # §5-§6 read shipped code too; a repo with no doubles reports N/A
  fallback: skills/test-double-scan/SKILL.md

- name: test-audit
  kind: command
  triggers: { test_framework_detected: true }
  extracts_from: _extracted-codebase.md § Tests (runners AND VERSIONS from the lockfile — four verdicts change with the major) + the CI files that invoke them + the risk surfaces (auth, tenant, money, webhook modules)
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: commands/test-audit.md   # the source IS the fallback, as for db-audit; the fixed class ledger and the dispatch table are the contract

- name: test-fix
  kind: command
  triggers: { test_framework_detected: true }
  fallback: commands/test-fix.md   # the source IS the fallback, as for db-fix; a skeleton would drop the read-only-tests rule and the Step-5 self-check
```
