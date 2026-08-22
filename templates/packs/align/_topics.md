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
    - state_machine                # 10 states: detected → planned → in-progress → fixed → verified,
                                   # + side states halted, parked, pending-review, archived-pre-existing, archived-deprecated
    - per_finding_record_shape     # YAML schema (id, class, subclass, severity, scope, evidence, closure_verb, idiom_cited, tier, status, ...)
    - automation_hooks             # how /align-scan + /align-phase + /align-gate + /align-status read/write
    - reporting_views              # by-class, by-tier, by-phase, blocked, security-only, perf-only
    - drift_detection              # ledger says fixed but git history says no commit → halt
  mirror_existing: true
  fallback: ai-patterns/align-ledger.md
  cite_evidence: strict

- name: align-guardrails
  kind: pattern
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (test runner, skip/ignore files, file-size profile) + ai/conventions.md (threshold overrides)
  sections:
    - project_specific_first       # threshold overrides, skip list, test runner + flake retry
    - overview
    - realism_guards               # the 8 execution-time guards: trigger, default threshold, required output line
    - named_anti_patterns          # the catalogue audits cite by name: fingerprint + catching check
    - automation_hooks             # which command applies which guard
  mirror_existing: true
  fallback: ai-patterns/align-guardrails.md
  cite_evidence: strict

# ============ AGENTS (.claude/agents/<name>.md) ============

- name: align-evidence-auditor
  kind: agent
  triggers:
    always: true
  extracts_from: _extracted-idioms.md (named inventory — resolves shared_equivalent + idiom_cited) + _extracted-codebase.md § "Tests" (detector tooling)
  sections: [premise, preflight, five_checks, out_of_domain_routing, output_format, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: agents/align-evidence-auditor.md   # align ships no _examples/ dir — fall back to the live source
  cite_evidence: strict

- name: align-idiom-auditor
  kind: agent
  triggers:
    always: true
  extracts_from: _extracted-idioms.md (full — the oracle this agent looks up against) + _extracted-codebase.md § "Gold standards"
  sections: [premise, preflight, four_checks, boundary_table, output_format, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: agents/align-idiom-auditor.md   # align ships no _examples/ dir — fall back to the live source
  cite_evidence: strict

- name: align-gate-auditor
  kind: agent
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "Tests" (lint / typecheck / test / coverage commands) + _extracted-idioms.md (check 4 + check 11 lookups)
  sections: [premise, preflight, fourteen_check_matrix, verdict_composition, output_format, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: agents/align-gate-auditor.md   # align ships no _examples/ dir — fall back to the live source
  cite_evidence: strict

- name: align-ledger-auditor
  kind: agent
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (PROJECT_KIND for class breakdown) + ai/patterns/align-ledger.md (row schema + state machine)
  sections: [premise, preflight, six_reconciliations, output_format, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: agents/align-ledger-auditor.md   # align ships no _examples/ dir — fall back to the live source
  cite_evidence: strict

# ============ RULES (.claude/rules/<name>.md) ============

- name: align-discipline-references
  kind: reference-pair
  files: [references/align-discipline-procedures.md, references/align-discipline-catalogue.md]
  triggers: { always: false }           # NOT INSTALLED. phase-4.2-apply.md:210-213 copies references/<name>.md only when <name> equals a DETECTED FRAMEWORK NAME, and no framework is called align-discipline-procedures; the `2>/dev/null || true` swallows the miss. No tool adapter ships them either (phase-4.8-deep.md:35).
  note: pack-side worked procedures, worked examples and long-form guidance only. Everything enforceable — the eight guards, the six supporting mechanisms and their thresholds, the anti-bloat merge gates, the 21-verb vocabulary, the enforcement matrix and the named anti-patterns — lives in ai-patterns/align-guardrails.md, which DOES install (phase-4.2-apply.md:207).

- name: align-discipline
  kind: rule
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "Gold standards" + _extracted-idioms.md (full) + _extracted-codebase.md § "Tests" (test runner + commands)
  sections:
    - project_specific_first       # codebase root, gold-standard inventory path, test runner, lint+typecheck commands, PROJECT_KIND
    - scope                        # what align covers + what it routes elsewhere
    - relationship_to_migration    # align is migration turned inward (no second codebase → no parity test)
    - tiered_floor                 # trivial / standard / heavy with promoter rules
    - anti_bloat_rules             # merge gates; pointer to catalogue for full definitions
    - realism_guards               # the 8 guards BY NAME; definitions live in ai-patterns/align-guardrails.md
    - finding_categories           # 11 universal classes (6 structural + 5 functional) + stack-specific;
                                   # detector signal / verb / tier live in detect-drift, NOT restated here
    - per_finding_audit_halts      # 11 halts — the enforceable core, with validator names
    - per_stack_and_tool_agnostic  # stack routing + the rule-only-tool procedure pointer
    - must / must_not / should     # the rule body
    - enforcement                  # 11 script-enforced of 14; the 3 agent-side named as such
    - anti_patterns                # names only; catalogue lives in ai-patterns/align-guardrails.md
    - load_on_demand               # agents, installed patterns, reference pair
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
  dispatches: [align-evidence-auditor]

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
  dispatches: [align-idiom-auditor]

- name: align-gate
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "Tests" + _extracted-idioms.md
  sections: [premise, when_to_use, fourteen_check_matrix, preflight, phases_1_to_7, output, mechanical_halt, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-gate.md
  dispatches: [align-gate-auditor, align-idiom-auditor]

- name: align-fast
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md + _extracted-idioms.md
  sections: [premise, modes, when_to_use_vs_not, what_happens_per_row, parallel_dispatch_strategy, project_anchors, optional_flags, preflight, phases_1_to_7, mechanical_halt, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-fast.md
  dispatches: [align-idiom-auditor, align-gate-auditor]

- name: align-status
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (project_kind for class breakdown)
  sections: [premise, when_to_use, prereqs, phases_1_to_7, output, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-status.md
  dispatches: [align-ledger-auditor]

- name: align-final
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md
  sections: [premise, when_to_use, prereqs, phases_1_to_7, output, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-final.md
  dispatches: [align-gate-auditor, align-ledger-auditor]

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
  dispatches: [align-evidence-auditor, align-ledger-auditor]

- name: align-recheck
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (codebase-profile + module names + UI surface inventory) + _extracted-idioms.md
  sections: [premise, when_to_use, input_forms, resolution_semantic, phases_1_to_7, examples_description_and_path, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/align-recheck.md
  dispatches: [align-evidence-auditor]

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
  dispatches: [align-idiom-auditor]
```

## Triggers per topic — key decisions

- **align-discipline** is `always: true` because the rule is the contract; without it, the commands lose discipline.
- **align-fast** is `always: true` because `/migration-fast` set the precedent — fast is the routine path; manual is the exception.
- **detect-drift** is `always: true` because it's the universal detector; per-stack packs ADD detectors, but the universal 12 always run.
- **find-and-align** is `always: true` because every fix uses the per-finding loop.
- **The four auditor agents** are `always: true` for the same reason as the rule: they are the *verdict* surface. The skills detect and fix; the commands orchestrate; nothing else in the pack was authorised to say `REJECT` / `HALT` / `REFUSE` with evidence attached. Their triggers are unconditional because every sweep, on every stack, passes through all four windows.

## Agent dispatch — the four audit windows

Align owned no agents until 1.9.0. The commands dispatched *other packs'* detectors (`dead-code-finder`, `refactorer`, `security-auditor`, `accessibility-auditor`, …) and then performed every audit inline, which is why the discipline's own halts had no owner. The four agents split that inline work by **when in the row's life it happens**, so each has one input, one authority, and one anti-trigger:

| Window | Agent | Input | Authority | Anti-trigger |
|---|---|---|---|---|
| Pre-fix (scan output) | `align-evidence-auditor` | `findings.md` + `detected` rows | audit halts #1–#4, #11 | not after fixes land |
| Per-fix (one diff) | `align-idiom-auditor` | the row's diff + the oracle | audit halts #6, #9, #10 + the boundary table | not scan triage, not the phase verdict |
| Post-phase (one phase) | `align-gate-auditor` | the phase's commit range | the 14-check matrix; PASS / REFUSE | never mid-phase, never on a dirty tree |
| Cross-phase (all state) | `align-ledger-auditor` | ledger ↔ git ↔ halts ↔ plan | state reconciliation + SLA | never reads source, never judges a fix |

`align-idiom-auditor` is the one that carries the pack's identity: it is the only artifact in the repo whose whole job is deciding whether a change **enforced an existing convention** (align) or **introduced a new one** (`/polish`), **discovered** one (`/optimize`), or **changed a contract** (`/refactor`). It enforces `templates/tool-adapters/_orchestration-sync.md § Command boundary table` per-diff, which is where that split is actually decidable.

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
