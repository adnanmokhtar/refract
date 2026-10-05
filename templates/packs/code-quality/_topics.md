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
  # Age is not a trigger: in 2026 `codebase_age_above_2y` fires on nearly every repo, which is how
  # an agent ends up installed everywhere and dispatched nowhere. The trigger is migration INTENT
  # or a shape the codebase cannot leave in one commit.
  triggers: { framework_major_version_lag: true, OR: { migration_intent_detected: true, monorepo_extraction_planned: true } }
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

# On-demand depth. These exist because engineering-principles.md was carrying ~770 tokens of
# placement/AI-change reasoning in EVERY session's context — material a reader needs when they are
# placing code or landing a model-authored change, not on every prompt. The rule keeps the
# invariants; these carry the judgement. The source IS the fallback: both files are
# stack-agnostic prose with nothing to abridge and no extraction signal to wait for.
- name: module-boundaries
  kind: pattern
  triggers: { module_per_feature_layout: true, OR: { layered_backend_detected: true } }
  extracts_from: _extracted-codebase.md § Modules + _extracted-idioms.md § Layers + ai/architecture.md
  sections: [context, where_a_feature_lives, the_shared_test, layer_direction, enforcement, common_mistakes]
  mirror_existing: true
  fallback: ai-patterns/module-boundaries.md

- name: ai-assisted-change
  kind: pattern
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Conventions + ai/conventions.md (what the agent keeps drifting from)
  sections: [context, control_system_framing, comprehension_gate, conventions_problem, verifying_agent_reports, capturing_corrections]
  fallback: ai-patterns/ai-assisted-change.md

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

- name: refactor
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-idioms.md (shared helpers + exported surface) + _extracted-codebase.md § Modules
  sections: [premise, dispatch, when_this_pack_leads, boundary]
  fallback: commands/refactor.md   # a pack OVERLAY on the canonical commands/refactor.md — the source IS the fallback. `_examples/refactor.md` was deleted at 1.8.0: a 20-line usage anecdote with no frontmatter, disowned by this entry yet still on disk, so any glob-based resolution installed it over the overlay. Now nothing ships that can drift from this.
  overlay_of: commands/refactor.md

- name: find-module
  kind: command
  triggers: { module_per_feature_layout: true }
  fallback: _examples/find-module.md

- name: dead-code-scan
  kind: skill
  triggers: { always: true }   # every codebase accrues code nothing reaches; a stack with no reachability tool reports NO LANE
  fallback: skills/dead-code-scan/SKILL.md

- name: debt-ledger
  kind: skill
  triggers: { vcs_detected: true }
  fallback: _examples/debt-ledger.md

- name: architectural-diagnosis
  kind: skill
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § "Repository shape" + _extracted-idioms.md § Layers + § Modules + ai/architecture.md
  sections: [purpose, when_to_use, inputs, outputs, detectors, procedure, hard_rules, failure_modes]
  fallback: skills/architectural-diagnosis/SKILL.md   # rewritten at 2.0.0: import-graph lanes per stack, relative cut-offs (THR-ARCH-RELATIVE), § 9 churn × complexity hotspots, a nine-class coverage block; the Phase-0 evidence blocks validate-optimize-artifacts.sh reads are kept
  cite_evidence: strict

- name: refactoring-sweep
  kind: skill
  triggers: { always: true }
  extracts_from: _extracted-idioms.md (project's refactoring conventions)
  sections: [purpose, when_to_use, the_10_closure_verbs, procedure, hard_rules, failure_modes]
  fallback: skills/refactoring-sweep/SKILL.md
  cite_evidence: strict

# Universal safety skills (COPY-mode — verbatim, not authored-from-extraction). Wired as the
# pre-sweep coverage gate + post-sweep boot-check in /optimize + /audit (#9/#11).
- name: test-shield
  kind: skill
  triggers: { always: true }
  fallback: skills/test-shield/SKILL.md   # no _examples/ stub ships — the source IS the fallback
  sections: [purpose, when_to_use, procedure, verify, anti_patterns]

- name: smoke-verify
  kind: skill
  triggers: { always: true }
  fallback: skills/smoke-verify/SKILL.md   # no _examples/ stub ships — the source IS the fallback
  sections: [purpose, when_to_use, procedure, verify, anti_patterns]

# Comprehension gate (COPY-mode — verbatim). Dispatched by /pre-commit (generate + validate)
# and /review-changes (validate). Mechanizes engineering-principles § AI-assisted development:
# "if you can't explain the code, it isn't yours."
- name: change-brief
  kind: skill
  triggers: { always: true }
  fallback: skills/change-brief/SKILL.md   # no _examples/ stub ships — the source IS the fallback
  sections: [purpose, when_to_use, the_brief_contract, procedure, verify, anti_patterns]

# Correctness detectors (COPY-mode — verbatim; the source IS the fallback, as the security and database
# detectors do, so a regenerated stub can never drift from the detector it mirrors).
- name: error-handling-scan
  kind: skill
  triggers: { always: true }   # every codebase has an unhappy path; a stack with no lane reports its classes N/A
  fallback: skills/error-handling-scan/SKILL.md

- name: type-safety-scan
  kind: skill
  triggers: { always: true }   # every codebase has a boundary; an untyped stack reports the cast classes by grep only
  fallback: skills/type-safety-scan/SKILL.md

- name: correctness-smell-scan
  kind: skill
  triggers: { always: true }   # every codebase compares, rounds, switches and reads a clock; a stack with no lane runs the greps and reports partial
  fallback: skills/correctness-smell-scan/SKILL.md

- name: suppression-scan
  kind: skill
  triggers: { always: true }   # a repo with no analyzer and no directive prints its three classes N/A with that reason
  fallback: skills/suppression-scan/SKILL.md

- name: duplication-scan
  kind: skill
  triggers: { vcs_detected: true }   # the divergence and new-clone lanes read git history; without it §1b and §3 are N/A and the rest runs
  fallback: skills/duplication-scan/SKILL.md

- name: quality-audit
  kind: command
  triggers: { always: true }   # every codebase has handlers, boundaries and logic; a stack with no analyzer lane runs the greps and reports partial
  extracts_from: _extracted-codebase.md § Stack (language, runtime AND analyzer versions from the lockfile — verdicts change with the major) + the lint and typecheck steps CI runs + the risk surfaces (auth, tenant, money, webhook modules)
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: commands/quality-audit.md   # the source IS the fallback, as for test-audit and db-audit; the fixed class ledger and the dispatch table are the contract

- name: quality-fix
  kind: command
  triggers: { always: true }
  fallback: commands/quality-fix.md   # the source IS the fallback, as for test-fix and db-fix; a skeleton would drop the two-lane split and the Step-6 self-check
```
