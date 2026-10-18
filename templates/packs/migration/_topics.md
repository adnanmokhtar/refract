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
  fallback: ai-patterns/feature-port.md   # source-as-fallback. ai-patterns/ copies unconditionally (phase-4.2-apply.md:207), so an abridged _examples/ twin could only ever overwrite the fresh source with a staler one
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
  fallback: ai-patterns/parity-testing.md   # source-as-fallback, same reason as feature-port
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
  fallback: ai-patterns/migration-ledger.md   # source-as-fallback, same reason as feature-port
  cite_evidence: strict

- name: migration-guardrails
  kind: pattern
  triggers:
    always: true                   # the rule's enforceable depth lives here; installing the rule without it leaves 10 halt definitions undefined
  extracts_from: _extracted-codebase.md § Migration (V1/V2 roots, cutover mechanism) + ai/migration/_v2-anchors.md (v1_status, parity-test root) + _extracted-idioms.md (error handler, shared wrappers the anti-patterns name)
  sections:
    - project_specific_first       # V1/V2 roots, parity-test root, cutover mechanism, v1_status
    - tier_artifact_specs          # heavy / standard / trivial floors the gate validates against
    - dead_v1_six_axis_check       # halt 11's definition + edge cases + the --include-dead override
    - halts_12_13_full             # UI state enumeration + the two-layer navigation inventory
    - v1_status_modes              # which halts each mode skips
    - anti_bloat_merge_gates       # the merge gates, not suggestions
    - supporting_mechanisms        # reviewer approval, mid-port tier promotion, idiom-drift propagation
    - review_checklist             # per port PR
    - named_anti_patterns          # the 20 names audits cite, each with a fingerprint
    - enforcement                  # anti-pattern → validate-migration-artifacts.sh check function
  mirror_existing: true
  fallback: ai-patterns/migration-guardrails.md   # source-as-fallback
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
  files: [references/migration-discipline-catalogue.md]
  triggers: { always: false }           # NOT INSTALLED. phase-4.2-apply.md:210-213 copies references/<name>.md only when <name> equals a DETECTED FRAMEWORK NAME, and no framework is called migration-discipline-catalogue; the `2>/dev/null || true` swallows the miss. No tool adapter ships it either (phase-4.8-deep.md:35).
  note: pack-side worked examples, tier rationale and long-form Should guidance only. Everything enforceable — tier floor, halt definitions, merge gates, thresholds, review checklist, named anti-patterns, anti-pattern→check matrix — lives in ai-patterns/migration-guardrails.md, which DOES install (phase-4.2-apply.md:207). migration-discipline-procedures.md was merged into the catalogue and deleted 2026-08-23.

- name: migration-discipline
  kind: rule
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "Migration" + _extracted-idioms.md § Concurrency (so the rule cites the project's actual primitives) + ai/decisions/ (any prior migration ADRs)
  sections:
    - project_specific_first       # V1/V2 roots, parity-test location, cutover mechanism, caching + DB primitives
    - core_philosophy              # the port is re-derived from a contract, never transposed
    - tiered_floor                 # trivial / standard / heavy artifact floor + tier classification
    - anti_bloat_rules             # merge gates before a new artifact is authored
    - contract_9_sections          # the 9 sections a feature contract must carry
    - per_feature_audit_halts      # 13 halts — the enforceable core, with validator check names
    - per_stack_and_tool_agnostic  # frontend/backend axis extensions + the rule-only-tool procedure pointer
    - must / must_not / should     # the rule body
    - named_anti_patterns          # names only; fingerprints + fixes live in the catalogue reference
    - load_on_demand               # skills, agents, commands, patterns, the reference pair
  mirror_existing: true
  fallback: rules/migration-discipline.md   # source-as-fallback. The abridged _examples/ twin drifted six sections behind the rule and shipped as the project's always-loaded rule on greenfield
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

# Detector skills (the security-2.0 shape): no _examples/ stub ships — fall back to the live source, so a
# regenerated stub can never drift from the detector it mirrors. A port with no V1 tree runs solo from the
# recorded v1-inventory/; a lane with neither prints `blocked`, never N/A.
- name: paired-inventory
  kind: skill
  triggers: { always: true }   # paired inventory, V1/V2 lane diff, record V1 inventory, calibration pair
  fallback: skills/paired-inventory/SKILL.md

- name: surface-parity-scan
  kind: skill
  triggers: { always: true }   # V1 route dropped, guard widened or narrowed, tenant scope lost, enum / rule / error / default drift
  fallback: skills/surface-parity-scan/SKILL.md

- name: semantics-parity-scan
  kind: skill
  triggers: { always: true }   # rounding mode or order, integer division, string look-alikes, list order, null vs missing, time zones
  fallback: skills/semantics-parity-scan/SKILL.md

- name: side-effect-parity-scan
  kind: skill
  triggers: { always: true }   # observer or trait effect lost, dual-run duplicate, hidden consumer, cron not ported, trigger or FK action lost
  fallback: skills/side-effect-parity-scan/SKILL.md

- name: data-cutover-orchestrate
  kind: skill
  triggers: { always: true }   # backfill resume / overwrite, reconcile masks, load casts, id mapping, soft delete, sequences, fenced flip, reverse path
  fallback: skills/data-cutover-orchestrate/SKILL.md   # rewritten as a detector; the _examples/ copy predates it

- name: cutover-routing-scan
  kind: skill
  triggers: { always: true }   # façade route or method on the wrong half, session or CSRF not shared, write mirrored to a shadow, V1 cold before soak
  fallback: skills/cutover-routing-scan/SKILL.md

- name: parity-proof-scan
  kind: skill
  triggers: { always: true }   # V1-pinned test skipped or golden re-recorded, corpus misses V1 branches, V1 bug unrecorded, gated suite NOT-RUN, comparator blind spot
  fallback: skills/parity-proof-scan/SKILL.md

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

- name: migration-sync
  kind: command
  triggers:
    always: true
  extracts_from: _v2-anchors.md (v1_root + v1_remote + v1_branch) + V1 git log delta + ai/migration/ledger.md + ai/migration/sync-state.md
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  mirror_existing: false   # incremental commit-delta sync; complements `migrate`'s whole-tree port
  fallback: commands/migration-sync.md

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
    always: true                   # the pack's read-only V1↔V2 parity AUDIT: "is the port safe to cut over", "does V2 still do what V1 did"
  extracts_from: V1 root + V2 root from `.claude/_extracted-codebase.md § Migration` + ai/migration/ledger.md (v1_commit_pinned) + ai/migration/_v2-anchors.md (roots:) + ai/migration/pair-map.tsv + ai/migration/v1-inventory/ (solo mode)
  sections: [premise, intent_gate, standard_inputs, engine_and_six_detectors, cross_pack_owners, wiring_map, verify_candidates, class_coverage_ledger, production_bar, verdict, update, validate, output_format, next_steps, failure_modes, related]
  mirror_existing: true
  fallback: commands/compare-v1.md
  note: the audit, not a diff viewer. Paired (`--v1 --v2`, V1 read from a `git archive` of the pin), paired live (`--live-v1`), solo (`--v1-inventory`, never GO) or one feature. Runs paired-inventory plus the six parity detectors, refutes every row through @parity-auditor, prints the 48-row class ledger and a NO-GO / GO-UNVERIFIED / GO verdict, writes only the report, and ends with `/find-and-fix --from-audit=<report>`. Flags `--mig` (where ai/migration lives in a side-by-side layout) and `--runs` (recorded oracle runs, cited as `recorded`) are the project's to fill from extraction.

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
  sections: [premise, the_loop_5_steps, closure_verb_procedures, project_anchors, preflight, optional_flags, from_audit, mechanical_halt, hard_rules, failure_modes, related]
  mirror_existing: true
  fallback: commands/find-and-fix.md
  note: "`--from-audit=<report> [finding-id …]` closes a /compare-v1 report instead of detecting from scratch: each finding gets a failing-first test against V1 as oracle (its V-number, paired; solo only for guarantee classes), the fix, then the owning detector § re-run as RE-DETECT. Triggers: \"fix what the audit found\", a compare-v1 report path or a finding id. Rows another pack owns (MG-AZ-1/3, MG-MN-3, MG-I18N-1, MG-TX-1, PP-5) go to that pack's fix command, never closed here."

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
