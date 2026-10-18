# Align pack — topic specs (AUTHOR mode)

This file is the **nucleus** for the align track. When `/setup-project` Phase 4.2 runs in AUTHOR mode (extraction signal exists from Phase 2 — `_extracted-idioms.md` is populated; PROJECT_KIND is identified), generators read these topic specs + the project's extraction to author content in the project's own voice.

Align enforces conventions the project already **declares** (a lint rule at `error`, a human-written line in `ai/conventions.md`, an ADR, the glossary, the token set, a named wrapper). When a project declares none of these, the pack still installs, but every align class prints `N/A (no declared convention)`; the inventory falls back `_extracted-idioms.md` → `codebase-profile.md` → `ai/conventions.md`, and a missing file is a reduction, never a halt. `/setup-project --refine` is how a team writes the declarations down.

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
    - state_machine                # 14 states: detected → planned → in-progress → fixed → verified (pending-review for heavy),
                                   # + side states halted, routed, pending-approval, pending-ratification, parked, refuted,
                                   #   archived-pre-existing (aged out only), archived-deprecated
    - per_finding_record_shape     # YAML schema (id, al_class, oracle + oracle_tier, owner, scope, evidence, closure_verb,
                                   # proof_class, approval, detector_cmd, routed, tier, status, ...); legacy class names mapped
    - automation_hooks             # how /align-scan + /align-phase + /align-gate + /align-status read/write
    - reporting_views              # by AL class, by owner, by tier, by phase, by proof class, blocked, routed
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
  extracts_from: oracle-map.py output (the AL-01 quote check) + _extracted-idioms.md (named inventory — resolves shared_equivalent + idiom_cited) + _extracted-codebase.md § "Tests" (detector tooling)
  sections: [premise, preflight, checks, out_of_domain_routing, output_format, hard_rules, failure_modes, related]
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
  extracts_from: _extracted-codebase.md § "Tests" (lint / typecheck / test / coverage commands) + _extracted-idioms.md (check 4 + check 16 lookups)
  sections: [premise, preflight, seventeen_check_matrix, verdict_composition, output_format, hard_rules, failure_modes, related]
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
    - scope                        # declared-convention enforcement: the oracle and its tiers; what align owns,
                                   # closes for an owner (EQ rows), and routes
    - relationship_to_migration    # align is migration turned inward (no second codebase → no parity test)
    - tiered_floor                 # trivial / standard / heavy with promoter rules
    - anti_bloat_rules             # merge gates; pointer to catalogue for full definitions
    - realism_guards               # the 8 guards BY NAME; definitions live in ai-patterns/align-guardrails.md
    - proof_classes                # EQ (zero diff) / VC (named approval) / FN (behaviour test)
    - finding_classes              # AL-01…AL-34 by name + the legacy map; the class ledger (detector, owner,
                                   # closer) lives in align-detect, NOT restated here
    - per_finding_audit_halts      # 11 halts — the enforceable core, with validator names
    - per_stack_and_tool_agnostic  # stack routing + the rule-only-tool procedure pointer
    - must / must_not / should     # the rule body
    - enforcement                  # the 17-check gate: validator + align-sweep-gate.py checks; the agent-side ones named as such
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
  extracts_from: _extracted-codebase.md + _extracted-idioms.md (full) + oracle-map.py output
  sections: [premise, when_to_use, phases_1_to_7, class_coverage_ledger, verdict, output, what_to_do_next, failure_modes, related]
                                   # read-only audit; writes ai/audits/<date>-align.md, ai/align/scan-report.md and
                                   # ai/align/ledger.md rows at `detected` — nothing else
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
  sections: [premise, when_to_use, seventeen_check_matrix, preflight, phases_1_to_7, output, mechanical_halt, hard_rules, failure_modes, related]
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

- name: align-detect
  kind: skill
  triggers:
    always: true
  extracts_from: oracle-map.py output + the inventory in fallback order (_extracted-idioms.md → codebase-profile.md → ai/conventions.md) + _extracted-codebase.md (PROJECT_KIND)
  sections: [premise, class_ledger, legacy_class_map, inputs, dispatch, preflight, bulk_triage, output, reductions, halts, hard_rules, notes, related]
  mirror_existing: true
  fallback: skills/align-detect/SKILL.md

- name: find-and-align
  kind: skill
  triggers:
    always: true
  extracts_from: _extracted-idioms.md + _extracted-codebase.md § "Tests" + oracle-map.py output + ui-ux token-map.py (when installed)
  sections: [premise, when_to_use, inputs, route, detect, decide_proof_class, fix_rule_first, verify_ladder, record, halt_conditions, hard_rules, failure_modes, output, related]
  mirror_existing: true
  fallback: skills/find-and-align/SKILL.md
  dispatches: [align-idiom-auditor]

- name: wrapper-adoption-scan
  kind: skill
  triggers:
    always: true                   # every align-detect run dispatches it; a class with no declared wrapper, helper, prop or ban prints N/A
  extracts_from: oracle-map.py output (wrappers.tsv, rules.tsv, exports.tsv, docs.tsv) + _extracted-idioms.md § Wrappers (user-confirmed entries only)
  sections: [premise, rule, boundaries, lanes, preflight_greps, bulk_triage, scans_for, proof, output, precedents, when_to_run, halts, related]
  mirror_existing: true
  fallback: skills/wrapper-adoption-scan/SKILL.md

- name: convention-oracle
  kind: skill
  triggers:
    always: true                   # § 0 builds the oracle map every align detector reads; § 1 filters every candidate row
  extracts_from: the project's lint / stylelint / ls-lint / depcruise / Ruff configs, CI workflows, lockfiles, ai/*.md, ADRs, CONTRIBUTING, ai/glossary.md, and the refine-enriched / [CONTESTED: / ## Unsettled conventions markers (read by scripts/oracle-map.py)
  sections: [premise, rule, boundaries, lanes, preflight, bulk_triage, scans_for, proof, output, precedents, when_to_run, halts, related]
  mirror_existing: true
  fallback: skills/convention-oracle/SKILL.md

- name: naming-layout-scan
  kind: skill
  triggers:
    always: true                   # every align-detect run dispatches it; a class with no declared naming rule, glossary or module catalog prints N/A
  extracts_from: oracle-map.py output (rules.tsv, docs.tsv, gates.tsv) + .ls-lint.yml + ai/glossary.md + ai/modules.md (both catalog path forms)
  sections: [premise, rule, boundaries, lanes, preflight, bulk_triage, scans_for, proof, output, precedents, when_to_run, halts, related]
  mirror_existing: true
  fallback: skills/naming-layout-scan/SKILL.md

- name: convention-ratchet-scan
  kind: skill
  triggers:
    always: true                   # every align-detect run dispatches it; no directive, baseline, package config or migration ADR prints N/A, no base prints blocked
  extracts_from: oracle-map.py output (exceptions.tsv, rules.tsv, gates.tsv, docs.tsv, ages.tsv) + baseline files (eslint-suppressions.json, known-violations, package_todo.yml, …) + git history to the merge-base
  sections: [premise, rule, boundaries, lanes, preflight, bulk_triage, scans_for, proof, output, precedents, when_to_run, halts, related]
  mirror_existing: true
  fallback: skills/convention-ratchet-scan/SKILL.md
```

## Triggers per topic — key decisions

- **align-discipline** is `always: true` because the rule is the contract; without it, the commands lose discipline.
- **align-fast** is `always: true` because `/migration-fast` set the precedent — fast is the routine path; manual is the exception.
- **align-detect** is `always: true` because it is the AL-01…AL-34 ledger and dispatcher: it runs the four align detectors and every installed owner detector, and a missing input is a reduction, never a halt.
- **find-and-align** is `always: true` because every fix uses the per-finding loop.
- **The four auditor agents** are `always: true` for the same reason as the rule: they are the *verdict* surface. The skills detect and fix; the commands orchestrate; nothing else in the pack was authorised to say `REJECT` / `HALT` / `REFUSE` with evidence attached. Their triggers are unconditional because every sweep, on every stack, passes through all four windows.

## Agent dispatch — the four audit windows

Align owned no agents until 1.9.0. The commands dispatched *other packs'* detectors (`dead-code-finder`, `refactorer`, `security-auditor`, `accessibility-auditor`, …) and then performed every audit inline, which is why the discipline's own halts had no owner. The four agents split that inline work by **when in the row's life it happens**, so each has one input, one authority, and one anti-trigger:

| Window | Agent | Input | Authority | Anti-trigger |
|---|---|---|---|---|
| Pre-fix (scan output) | `align-evidence-auditor` | `ai/align/scan-report.md` + the new `detected` rows | audit halts #1–#4, #11 + the AL-01 quote check | not after fixes land |
| Per-fix (one diff) | `align-idiom-auditor` | the row's diff + the oracle | audit halts #6, #9, #10 + the boundary table | not scan triage, not the phase verdict |
| Post-phase (one phase) | `align-gate-auditor` | the phase's commit range | the 17-check matrix; PASS / REFUSE | never mid-phase, never on a dirty tree |
| Cross-phase (all state) | `align-ledger-auditor` | ledger ↔ git ↔ halts ↔ plan | state reconciliation + SLA | never reads source, never judges a fix |

`align-idiom-auditor` is the one that carries the pack's identity: it is the only artifact in the repo whose whole job is deciding whether a change **enforced an existing convention** (align) or **introduced a new one** (`/polish`), **discovered** one (`/optimize`), or **changed a contract** (`/refactor`). It enforces `templates/tool-adapters/_orchestration-sync.md § Command boundary table` per-diff, which is where that split is actually decidable.

## Per-stack additions

Stack lanes (each language's linter, file-name checker and import-boundary tool, with version gates) live in the four detector skills, so the pack itself adds nothing per stack. What changes per `PROJECT_KIND` is which **owner** detectors `align-detect` can dispatch:

- `frontend-*`: ui-ux `design-token-audit` (AL-05–10, AL-12) and frontend `i18n-scan` / `a11y-code-scan` (AL-26–28), when those packs are installed. `motion-audit` and `ui-state-scan` are not align classes; a site that bypasses a **declared** state or fetch wrapper is AL-11.
- `backend-*`: backend `edge-error-scan` §6–§7 and `api-consistency-audit` (AL-23–25), when the backend pack is installed. Security classes are the security pack's (always installed) and are routed, never graded here.
- `data-*`: perf and data classes are the database / performance packs'; align applies a declared idiom only under the measured-baseline carve-out when those packs are absent.
- `mobile-*`: no owner detector is dispatched; the align classes run on the declared conventions as for any stack.

## Composition with /setup-project

When `/setup-project --include=align` is invoked:
1. The install does not wait on `_extracted-idioms.md`. Align's commands read the inventory in fallback order (`_extracted-idioms.md` → `codebase-profile.md` → `ai/conventions.md`) at run time; with none present and no lint rule at `error`, the first `/align-scan` prints every align class `N/A (no declared convention)` and recommends `/setup-project --refine`. An `[EXTRACTION-WEAK]` flag from Phase 2 is worth a manual review of `_extracted-idioms.md` before the first scan.
2. Phase 4.2 AUTHOR mode reads this `_topics.md` + the project's extraction; generates project-specific commands / rules / skills / patterns.
3. Phase 5 records the install in `ai/index.md` + `ai/dynamic/changelog.md`.
4. Phase 7 surfaces a one-time recommendation to run `/align-scan` on a clean working tree.
