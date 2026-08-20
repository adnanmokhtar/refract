# Align pack — topic specs (AUTHOR mode)

This file is the **nucleus** for the align track. When `/setup-project` Phase 4.2 runs in AUTHOR mode (extraction signal exists from Phase 2 — `_extracted-idioms.md` is populated; PROJECT_KIND is identified), generators read these topic specs + the project's extraction to author content in the project's own voice.

When extraction has no idiom inventory (greenfield CREATE without prior structure OR ENHANCE without `/setup-project --refine`), the align pack should NOT auto-load — alignment requires an oracle. The user must run `/setup-project --refine` first.

> **Class names + paths in this file are roles, not literals.** Triggers and `extracts_from:` pointers refer to roles like `<idioms-root>`, `<conventions-root>`, `<test-runner>`. Phase 4.2-AUTHOR substitutes each role with the actual path/value found in `.claude/_extracted-codebase.md` and `.claude/_extracted-idioms.md`.

---

## Topics

```yaml
# ============ PATTERNS (ai/patterns/<name>.md) ============

- name: align-ledger
  kind: pattern
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (PROJECT_KIND + module layout) + _extracted-idioms.md (gold-standard inventory)
  sections:
    - project_specific_first       # path to ledger (default ai/align/ledger.md), update cadence, ownership
    - overview
    - state_machine                # detected → planned → in-progress → fixed → verified → archived (+ side states halted, parked, archived-pre-existing)
    - per_finding_record_shape     # YAML schema (id, class, subclass, severity, scope, evidence, closure_verb, idiom_cited, tier, status, ...)
    - automation_hooks             # how /align-scan + /align-phase + /align-gate + /align-status read/write
    - reporting_views              # by-class, by-tier, by-phase, blocked, security-only, perf-only
    - drift_detection              # ledger says fixed but git history says no commit → halt
  mirror_existing: true
  fallback: ai-patterns/align-ledger.md
  cite_evidence: strict

# ============ RULES (.claude/rules/<name>.md) ============

- name: align-discipline-references
  kind: reference-pair
  files: [references/align-discipline-procedures.md, references/align-discipline-catalogue.md]
  triggers: { always: true }            # copied to .claude/references/ alongside the rule — loaded ON DEMAND by commands/skills, never auto-loaded
  note: the rule core + these two files are ONE discipline (split 2026-06-07, 40k always-on limit); never install the rule without them

- name: align-discipline
  kind: rule
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "Gold standards" + _extracted-idioms.md (full) + _extracted-codebase.md § "Tests" (test runner + commands)
  sections:
    - project_specific_first       # codebase root, gold-standard inventory path, test runner, lint+typecheck commands, PROJECT_KIND
    - scope                        # what align covers: structural + functional + stack-specific
    - relationship_to_migration    # align is migration turned inward
    - tiered_floor                 # trivial / standard / heavy with promoter rules
    - anti_bloat_rules             # closure-verb vocabulary; net-lines rule split by class group; idiom citation
    - finding_categories           # 6 universal classes (structural) + 5 (functional) + per-stack
    - per_stack_extensions         # frontend UI/UX detectors (mandatory for frontend-*); backend; data; mobile
    - per_finding_audit_halts      # 11 halts
    - tool_agnostic_procedure      # scan + find-and-align + gate (inlined for rule-only tools)
    - must / must_not / should     # the rule body
    - examples                     # parity / scope / security / perf / clean-code (with idiom citations)
    - review_checklist
    - enforcement                  # validator script + commands + status reporting
    - anti_patterns                # named anti-patterns with detection
    - references                   # cross-pack pointers
  mirror_existing: true
  fallback: rules/align-discipline.md
  cite_evidence: strict

# ============ COMMANDS (.claude/commands/<name>.md) ============

- name: align-scan
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md + _extracted-idioms.md (full)
  sections: [premise, when_to_use, anchors, phases_1_to_7, output, halts, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-scan.md

- name: align-plan
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (architecture boundaries; domain partitioning)
  sections: [premise, prereqs, phases_1_to_7, phasing_template_per_stack, output, halts, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-plan.md

- name: align-phase
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-idioms.md + _extracted-codebase.md § "Tests"
  sections: [premise, the_loop_5_steps, closure_verb_procedures, project_anchors, preflight, optional_flags, mechanical_halt, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-phase.md

- name: align-gate
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "Tests" + _extracted-idioms.md
  sections: [premise, when_to_use, fourteen_check_matrix, preflight, phases_1_to_7, output, mechanical_halt, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-gate.md

- name: align-fast
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md + _extracted-idioms.md
  sections: [premise, modes, when_to_use_vs_not, what_happens_per_row, parallel_dispatch_strategy, project_anchors, optional_flags, preflight, phases_1_to_7, mechanical_halt, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-fast.md

- name: align-status
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (project_kind for class breakdown)
  sections: [premise, when_to_use, prereqs, phases_1_to_7, output, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-status.md

- name: align-final
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md
  sections: [premise, when_to_use, prereqs, phases_1_to_7, output, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-final.md

- name: align-rollback
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (test_runner)
  sections: [premise, when_to_use, prereqs, phases_1_to_7, output, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-rollback.md

- name: align-park
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md
  sections: [premise, when_to_use, prereqs, phases_1_to_7, output, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-park.md

- name: align-unpark
  kind: command
  triggers:
    always: true
  sections: [premise, when_to_use, prereqs, what_happens, output, related]
  mirror_existing: true
  fallback: commands/align-unpark.md

- name: align-replan
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md
  sections: [premise, when_to_use, prereqs, phases_1_to_7, output, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-replan.md

- name: align-recheck
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (codebase-profile + module names + UI surface inventory) + _extracted-idioms.md
  sections: [premise, when_to_use, input_forms, resolution_semantic, phases_1_to_7, examples_description_and_path, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-recheck.md

- name: align-promote-tier
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (PROJECT_KIND for tier floors) + _extracted-idioms.md (critical-idiom inventory — promote-only rows)
  sections: [premise, args, forbidden_demotions, prerequisites, procedure, output, forbidden_demotion_example, hard_rules, related]
  mirror_existing: true
  fallback: commands/align-promote-tier.md   # align ships no _examples/ dir — fall back to the live source

- name: detect-drift
  kind: skill
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (PROJECT_KIND, dead-code tool, complexity tool, security scanner) + _extracted-idioms.md (full)
  sections: [purpose, when_to_use, inputs, outputs, procedure_step_by_step, halts, notes, related]
  mirror_existing: true
  fallback: skills/detect-drift/SKILL.md

- name: find-and-align
  kind: skill
  triggers:
    always: true
  extracts_from: _extracted-idioms.md + _extracted-codebase.md § "Tests"
  sections: [purpose, when_to_use, inputs, outputs, the_5_step_loop, halt_conditions, hard_rules, notes, related]
  mirror_existing: true
  fallback: skills/find-and-align/SKILL.md
```

## Triggers per topic — key decisions

- **align-discipline** is `always: true` because the rule is the contract; without it, the commands lose discipline.
- **align-fast** is `always: true` because `/migration-fast` set the precedent — fast is the routine path; manual is the exception.
- **detect-drift** is `always: true` because it's the universal detector; per-stack packs ADD detectors, but the universal 12 always run.
- **find-and-align** is `always: true` because every fix uses the per-finding loop.

## Per-stack additions

- For `PROJECT_KIND in frontend-*`: also load `frontend/agents/{accessibility-auditor, i18n-auditor, data-flow-auditor}` and `ui-ux/skills/{design-token-audit, motion-audit}`. These are referenced by `align-discipline.md § Per-stack extensions` AND dispatched by `detect-drift` for the UI/UX sub-classes.
- For `PROJECT_KIND in backend-*`: also load `security/agents/security-auditor` (universal, but heavily used in backend) and any `backend/rules/*.md` that defines fingerprints.
- For `PROJECT_KIND in data-*`: load `database/skills/migration-rehearsal/SKILL.md` for the `add-index` verb's `EXPLAIN ANALYZE` step.
- For `PROJECT_KIND in mobile-*`: load `mobile/skills/native-bridge-audit/SKILL.md`.

## Composition with /setup-project

When `/setup-project --include=align` is invoked:
1. Phase 2 confirms `_extracted-idioms.md` is populated. If not, halt and route the user to `/setup-project --refine` first.
2. Phase 4.2 AUTHOR mode reads this `_topics.md` + the project's extraction; generates project-specific commands / rules / skills / patterns.
3. Phase 5 records the install in `ai/index.md` + `ai/dynamic/changelog.md`.
4. Phase 7 surfaces a one-time recommendation to run `/align-scan` on a clean working tree.
