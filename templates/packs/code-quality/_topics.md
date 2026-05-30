# Code-quality pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: code-reviewer
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Conventions + § "Anti-patterns" + _extracted-idioms.md (all base classes)
  sections: [persona, review_methodology, project_conventions_to_enforce, anti_patterns_to_flag, output_format]
  fallback: _examples/code-reviewer.md
  cite_evidence: strict

- name: refactorer
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Conventions + _extracted-idioms.md
  sections: [persona, safe_refactor_recipes, mirror_existing_pattern_rule, test_first_rule, output_format]
  fallback: _examples/refactorer.md

- name: dead-code-finder
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Modules + recent activity (deletions)
  sections: [persona, methodology, signals_for_dead_code, output_format]
  fallback: _examples/dead-code-finder.md

- name: dependency-auditor
  kind: agent
  triggers: { package_manager_detected: true }
  extracts_from: _extracted-codebase.md § Stack (deps) + lockfile age
  sections: [persona, methodology, security_advisories_check, unused_deps_check, output_format]
  fallback: _examples/dependency-auditor.md

- name: error-detective
  kind: agent
  triggers: { logger_lib_detected: true }
  extracts_from: _extracted-codebase.md § Observability + sample error logs if accessible
  sections: [persona, log_search_strategy, error_grouping, root_cause_methodology, output_format]
  fallback: _examples/error-detective.md

- name: legacy-modernizer
  kind: agent
  triggers: { codebase_age_above_2y: true }
  extracts_from: _extracted-codebase.md § Conventions + § "Anti-patterns"
  sections: [persona, modernization_priority_order, safe_migration_recipes, output_format]
  fallback: _examples/legacy-modernizer.md

- name: monorepo-architect
  kind: agent
  triggers: { repo_shape: monorepo }
  extracts_from: _extracted-codebase.md § "Repository shape" (apps + libs)
  sections: [persona, current_layout, extraction_decisions, dependency_rules, output_format]
  fallback: _examples/monorepo-architect.md

- name: quality-principles
  kind: rule
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Conventions + § "Anti-patterns" + dynamic/feedback-learned.md
  sections: [project_specific_first, naming_rules, file_size_guidance, function_complexity, comment_discipline, todo_handling]
  mirror_existing: true
  fallback: _examples/quality-principles.md

- name: engineering-principles
  kind: rule
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Conventions + ai/architecture.md
  sections: [project_specific_first, solid, clean_code, separation_of_concerns, dependency_direction]
  mirror_existing: true
  fallback: rules/engineering-principles.md
  note: "Ships as a peer governance rule alongside quality-principles (both always-on). Phase 4.6 apply-pack-adaptation has a dedicated special case for it."

- name: review-changes
  kind: command
  triggers: { vcs_detected: true }
  fallback: _examples/review-changes.md

- name: pre-commit
  kind: command
  triggers: { vcs_detected: true }
  fallback: _examples/pre-commit.md

- name: check-health
  kind: command
  triggers: { always: true }
  fallback: _examples/check-health.md

- name: simplify
  kind: command
  triggers: { always: true }
  fallback: _examples/simplify.md

- name: find-module
  kind: command
  triggers: { module_per_feature_layout: true }
  fallback: _examples/find-module.md

- name: dead-branch-scan
  kind: skill
  triggers: { vcs_detected: true }
  fallback: _examples/dead-branch-scan.md

- name: architectural-diagnosis
  kind: skill
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § "Repository shape" + _extracted-idioms.md § Layers + § Modules + ai/architecture.md
  sections: [purpose, when_to_use, inputs, outputs, detectors, procedure, hard_rules, failure_modes]
  fallback: skills/architectural-diagnosis.md
  cite_evidence: strict

- name: refactoring-sweep
  kind: skill
  triggers: { always: true }
  extracts_from: _extracted-idioms.md (project's refactoring conventions)
  sections: [purpose, when_to_use, the_10_closure_verbs, procedure, hard_rules, failure_modes]
  fallback: skills/refactoring-sweep.md
  cite_evidence: strict

# Universal safety skills (COPY-mode — verbatim, not authored-from-extraction). Wired as the
# pre-sweep coverage gate + post-sweep boot-check in /optimize + /audit (#9/#11).
- name: test-shield
  kind: skill
  triggers: { always: true }
  sections: [purpose, when_to_use, procedure, verify, anti_patterns]

- name: smoke-verify
  kind: skill
  triggers: { always: true }
  sections: [purpose, when_to_use, procedure, verify, anti_patterns]
```
