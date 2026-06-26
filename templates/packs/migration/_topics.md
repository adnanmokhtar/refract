# Migration pack — topic specs (AUTHOR mode)

This file is the **nucleus** for the migration track. When `/setup-project` Phase 4.2 runs in AUTHOR mode (extraction signal exists from Phase 2 — concretely, the V1/V2 layout was detected and `_extracted-codebase.md § Migration` is populated), generators read these topic specs + the project's extraction to author content in the project's own voice.

When extraction has no migration signal (greenfield CREATE OR ENHANCE without V1+V2 evidence), generator falls back to copying the corresponding template in `_examples/` (literal copy + path injection).

> **Class names + paths in this file are roles, not literals.** Triggers and `extracts_from:` pointers refer to roles like `<v1-root>`, `<v2-root>`, `<feature-module-suffix>`. Phase 4.2-AUTHOR substitutes each role with the actual path/suffix found in `.claude/_extracted-codebase.md § Migration`.

---

## Topics

```yaml
# ============ PATTERNS (ai/patterns/<name>.md) ============

- name: feature-port
  kind: pattern
  triggers:
    always: true                   # always shipped when this pack is loaded
  extracts_from: _extracted-codebase.md § Migration (V1 root + V2 root + feature inventory) + _extracted-idioms.md (V1 service / repo / controller idioms — useful for "what shape does V1 use" anchor)
  sections:
    - project_specific_first       # V1 root, V2 root, naming convention, feature inventory file path, ledger path
    - overview
    - per_feature_lifecycle        # the 6 phases + entry/exit gates
    - decision_strangler_vs_big_bang
    - vertical_vs_horizontal_slicing
    - cutover_modes                # shadow / canary / dual-write / cutover-at-once
    - rollback_protocol
    - examples_from_codebase
    - pitfalls
  mirror_existing: true
  fallback: _examples/feature-port.md
  cite_evidence: strict

- name: parity-testing
  kind: pattern
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § Tests (test framework + colocation + factories) + _extracted-codebase.md § "Migration"
  sections:
    - project_specific_first       # test framework, factory pattern, snapshot dir, fixtures location
    - overview
    - golden_master_recipe
    - record_replay_recipe
    - property_based_recipe
    - shadow_traffic_recipe
    - dual_write_audit_recipe
    - tolerance_taxonomy           # exact match | structural match | numeric tolerance | ordering-insensitive | timestamp-insensitive
    - what_to_pin_explicitly       # outputs, side-effects, observable state changes, error shapes
    - what_NOT_to_pin              # internals that legitimately change (private helpers, log lines, internal IDs)
    - pitfalls
  mirror_existing: true
  fallback: _examples/parity-testing.md
  cite_evidence: strict

- name: migration-ledger
  kind: pattern
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § Migration (existing ledger if any, OR the feature inventory derived from V1 module list)
  sections:
    - project_specific_first       # path to ledger, ownership, update cadence
    - overview
    - state_machine                # V1-only → In-progress → V2-shadow → V2-canary → V2-only → V1-deleted
    - per_feature_record_shape     # YAML frontmatter contract
    - automation_hooks             # how /port-feature + /migration-status update it; what manual edits are allowed
    - reporting_views              # by-state / by-owner / by-perf-uplift / blocked / next-up
    - drift_detection              # ledger says V2-only but V1 path still exists in code → halt
  mirror_existing: true
  fallback: _examples/migration-ledger.md
  cite_evidence: strict

# ============ AGENTS (.claude/agents/<name>.md) ============

- name: migration-architect
  kind: agent
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (full) + _extracted-idioms.md (full) + _extracted-business.md (constraints + maturity stage)
  sections: [persona, when_to_invoke, preflight_reading, methodology, perf_uplift_decision_table, output_format, pitfalls]
  mirror_existing: true
  fallback: _examples/migration-architect.md

- name: parity-auditor
  kind: agent
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "API surface" + § Tests + § "Migration"
  sections: [persona, when_to_invoke, preflight_reading, audit_protocol, tolerance_decisions, output_format, pitfalls]
  mirror_existing: true
  fallback: _examples/parity-auditor.md

# ============ RULES (.claude/rules/<name>.md) ============

- name: migration-discipline-references
  kind: reference-pair
  files: [references/migration-discipline-procedures.md, references/migration-discipline-catalogue.md]
  triggers: { always: true }            # copied to .claude/references/ alongside the rule — loaded ON DEMAND by commands/skills, never auto-loaded
  note: the rule core + these two files are ONE discipline (split 2026-06-07, 40k always-on limit); never install the rule without them

- name: migration-discipline
  kind: rule
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "Migration" + _extracted-idioms.md § Concurrency (so the rule cites the project's actual primitives) + ai/decisions/ (any prior migration ADRs)
  sections: [project_specific_first, must, must_not, should, examples_per_concern, review_checklist, named_anti_patterns]
  mirror_existing: true
  fallback: _examples/migration-discipline.md
  cite_evidence: strict

# ============ SKILLS (.claude/skills/<name>.md) ============

- name: extract-v1-contract
  kind: skill
  triggers:
    always: true                   # the skill body is procedural and stack-agnostic; project-specific anchors come from the patterns it references
  extracts_from: _extracted-codebase.md § Modules (V1 module shape) + § "API surface" (V1 endpoints if any)
  sections: [purpose, when_to_use, prerequisites, procedure, output_format, failure_modes, related]
  fallback: _examples/extract-v1-contract.md

- name: parity-test-generate
  kind: skill
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § Tests + § "API surface"
  sections: [purpose, when_to_use, prerequisites, procedure, output_format, failure_modes, related]
  fallback: _examples/parity-test-generate.md

- name: perf-uplift-survey
  kind: skill
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "Performance hot paths" + _extracted-idioms.md § Concurrency + § "Data access" + DB pool config
  sections: [purpose, when_to_use, prerequisites, procedure, output_format, failure_modes, related]
  fallback: _examples/perf-uplift-survey.md

# ============ COMMANDS (.claude/commands/<name>.md) ============

# --- Suite A: phased flow (M10) ---

- name: migrate
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "Migration" (V1 root, V2 root, feature inventory) + V1 codebase scan + V2 codebase scan
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false   # simple-surface one-command entry; relocated from core commands/ to the migration pack 2026-06-26
  fallback: commands/migrate.md

- name: migration-scan
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "Migration" (V1 root, V2 root, feature inventory) + V1 codebase scan + V2 codebase scan
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false   # new in M10; no project equivalent expected
  fallback: commands/migration-scan.md

- name: migration-plan
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/scan-report.md + ai/migration/ledger.md + ai/architecture.md + ai/decisions/
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false
  fallback: commands/migration-plan.md

- name: migration-phase
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/plan.md + ai/migration/ledger.md + ai/conventions.md + ai/patterns/
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false
  fallback: commands/migration-phase.md

- name: migration-fast
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/plan.md + ai/migration/ledger.md + ai/conventions.md + ai/patterns/
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false
  fallback: commands/migration-fast.md

- name: migration-gate
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/plan.md + ai/migration/ledger.md + ai/migration/audits/
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false
  fallback: commands/migration-gate.md

- name: migration-final
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/ledger.md + ai/migration/_history.md + ai/migration/audits/ + ADRs
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false
  fallback: commands/migration-final.md

# --- Suite C: lifecycle commands (M12) ---

- name: migration-rollback
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/plan.md + ai/migration/_history.md + .claude/backups/migration-phase-<N>-<ts>/
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false
  fallback: commands/migration-rollback.md

- name: migration-replan
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/ledger.md + ai/migration/plan.md + ai/migration/_history.md + ai/failures/
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false
  fallback: commands/migration-replan.md

- name: migration-park
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/ledger.md
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false
  fallback: commands/migration-park.md

- name: migration-recheck
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (codebase-profile + UI surface inventory + module names) + ai/migration/ledger.md + ai/migration/plan.md (only when --phase=<N> is passed)
  sections: [premise, when_to_use, input_forms_description_path_or_phase, resolution_semantic, phase_mode_loop, phases_1_to_7, examples, hard_rules, failure_modes, related]
  mirror_existing: false
  fallback: commands/migration-recheck.md

- name: cross-repo-task
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/ledger.md + sibling-repo identifiers from _extracted-codebase.md
  sections: [premise, subcommands, when_to_use, prereqs, phases_1_to_7, output, hard_rules, failure_modes, related]
  mirror_existing: false
  fallback: commands/cross-repo-task.md

- name: migration-unpark
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/ledger.md + ai/migration/parked/
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false
  fallback: commands/migration-unpark.md

- name: migration-deprecate
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/ledger.md + ai/decisions/
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false
  fallback: commands/migration-deprecate.md

- name: compare-v1
  kind: command
  triggers:
    always: true
  extracts_from: V1 root + V2 root from `.claude/_extracted-codebase.md § Migration`
  sections: [understand, organize, retrieve, generate, output_format, hard_rules]
  mirror_existing: true
  fallback: commands/compare-v1.md

- name: migration-promote-tier
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/ledger.md
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false
  fallback: commands/migration-promote-tier.md

- name: draft-phase-adrs
  kind: command
  triggers:
    always: true
  extracts_from: ai/migration/audits/ + ai/migration/phase-<N>.md
  sections: [understand, organize, retrieve, generate, update, validate, output_format, hard_rules]
  mirror_existing: false
  fallback: commands/draft-phase-adrs.md

- name: find-and-fix
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md + _extracted-idioms.md + ai/migration/ledger.md
  sections: [premise, the_loop_5_steps, closure_verb_procedures, project_anchors, preflight, optional_flags, mechanical_halt, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/find-and-fix.md

# --- Suite B: per-feature (legacy) ---

- name: port-feature
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (full) + _extracted-idioms.md (full) + _extracted-business.md
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, failure_modes]
  mirror_existing: true
  fallback: _examples/port-feature.md

- name: migration-status
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "Migration" (ledger path) + (optionally) git log
  sections: [understand, organize, retrieve, generate]
  mirror_existing: true
  fallback: _examples/migration-status.md
```

---

## How generators consume this file

For each topic where `triggers` evaluate true against `.claude/_extracted-codebase.md`:

1. If `mirror_existing: true` AND target file exists → read it; capture section order + voice; author inside that skeleton.
2. Read the `extracts_from` source (`_extracted-codebase.md § Migration` is the load-bearing one for this pack — it carries V1 root, V2 root, feature inventory, ledger path).
3. For each section in `sections`, author content using extracted facts. Cite `<path>:<line>` for every claim if `cite_evidence: strict`.
4. If extraction yields no `Migration` section at all (project has no V1/V2 layout yet) → fall back to `_examples/<topic>.md` literal copy. The "project-specific first" block becomes a TODO surfaced in Phase 5.
5. After write: lint output for forbidden patterns (generic prose without project context, missing citations in strict mode, contradictions with `_extracted-codebase.md`).

## Pack-author maintenance contract

When adding a new topic to this pack:
- Choose `triggers` so the topic activates ONLY when relevant. For migration, `always: true` is acceptable on most topics — once the pack is loaded, all artifacts are needed; the gate is the pack-load itself (handled by the `migration_layout_detected` trigger in `_registry.md`).
- Place a `_examples/<name>.md` template — must be ≥100 lines (depth floor enforced by Phase 4.0 preflight).
- Document in this file's commit message: which extraction signal feeds this topic.
