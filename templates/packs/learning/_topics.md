# Learning pack — topic specs (AUTHOR mode)

The learning pack is the **meta-pack**: it contains the engine that AUTHOR mode itself depends on (the extractors + the curator agents + the refresh commands). Most topics here are CORE — applied to every project regardless of stack — so triggers are mostly `always: true`.

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: knowledge-curator
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md (full) — to know which patterns/decisions exist + dynamic/ files
  sections: [persona, methodology, promotion_rules, project_specific_dynamic_files, output_format]
  fallback: agents/knowledge-curator.md
  cite_evidence: lenient

- name: convention-drift-detector
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § Conventions + § "Anti-patterns" + ai/conventions.md if exists
  sections: [persona, drift_detection_methodology, project_conventions_to_watch, output_format]
  fallback: agents/convention-drift-detector.md

- name: pattern-emergence-watcher
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § "Recent activity" + § Modules + dynamic/learned-patterns.md if exists
  sections: [persona, recurrence_threshold, project_pattern_promotion_signals, output_format]
  fallback: agents/pattern-emergence-watcher.md

- name: extract-project-context
  kind: skill
  triggers: { always: true }
  fallback: skills/extract-project-context/SKILL.md

- name: extract-codebase-overview
  kind: skill
  triggers: { always: true }
  # The orchestrator skill itself — no fallback because if this is missing, AUTHOR mode is broken everywhere.
  fallback: skills/extract-codebase-overview/SKILL.md

- name: extract-business-context
  kind: skill
  triggers: { always: true }
  fallback: skills/extract-business-context/SKILL.md

- name: extract-base-class-idiom
  kind: skill
  # Covers ALL FIVE Phase-2.5 idiom patterns via its `unit_kind` input (base-class /
  # composable / wrapper / service / type-primitive), so the trigger is "has any
  # load-bearing unit", not "has base classes". A composition-style frontend has no base
  # classes and still needs this skill — that gap is what left `_extracted-idioms.md`
  # § Composables / § Wrappers empty for every functional project.
  triggers: { codebase_has_load_bearing_units: true }
  fallback: skills/extract-base-class-idiom/SKILL.md

# REFINE-mode skills (round-two deep extraction). All gate on the --refine flag.
# Each consumes round-one extraction PLUS authors a section of .claude/_refine-extract.md.

- name: extract-domain-entities-deeply
  kind: skill
  triggers: { refine_mode: true, business_domain_detected: true }
  extracts_from: _extracted-codebase.md § Identifiers / § Modules + ORM model files + migrations
  fallback: _examples/extract-domain-entities-deeply.md

- name: extract-architecture-deeply
  kind: skill
  triggers: { refine_mode: true }
  extracts_from: _extracted-codebase.md § Modules / § Architecture + import graph
  fallback: _examples/extract-architecture-deeply.md

- name: extract-flows-deeply
  kind: skill
  triggers: { refine_mode: true }
  extracts_from: _extracted-codebase.md § Routes / § Handlers + lifecycle events from extract-domain-entities-deeply
  fallback: _examples/extract-flows-deeply.md

- name: extract-conventions-emerging
  kind: skill
  triggers: { refine_mode: true }
  extracts_from: _extracted-codebase.md (full) — sweep for recurring patterns
  fallback: _examples/extract-conventions-emerging.md

- name: extract-hotpaths
  kind: skill
  triggers: { refine_mode: true, backend_track: true }
  extracts_from: _extracted-codebase.md § Routes / § Queries + monitoring config if accessible
  fallback: _examples/extract-hotpaths.md

- name: extract-failures-from-history
  kind: skill
  triggers: { refine_mode: true, git_log_accessible: true, min_commits: 30 }
  extracts_from: git log + (opt-in) docs/postmortems/ if --include-incidents=<path>
  fallback: _examples/extract-failures-from-history.md

- name: compute-anchor-density
  kind: skill
  triggers: { refine_mode: true }   # also invoked by --health (out-of-band)
  extracts_from: every Phase-4-generated artifact + _extracted-codebase.md + _refine-extract.md
  fallback: _examples/compute-anchor-density.md

- name: setup-quality-scoring
  kind: ai-pattern
  triggers: { refine_mode: true }   # ships alongside compute-anchor-density as the rubric documentation
  fallback: _examples/setup-quality-scoring.md

- name: refresh-knowledge
  kind: command
  triggers: { always: true }
  fallback: commands/refresh-knowledge.md

- name: detect-drift
  kind: command
  triggers: { always: true }
  fallback: commands/detect-drift.md

- name: promote-pattern
  kind: command
  triggers: { always: true }
  fallback: commands/promote-pattern.md

- name: promote-decision
  kind: command
  triggers: { always: true }
  mirror_existing: true
  fallback: commands/promote-decision.md

- name: audit-knowledge
  kind: command
  triggers: { always: true }
  mirror_existing: true
  fallback: commands/audit-knowledge.md

- name: learn-from-task
  kind: command
  triggers: { always: true }
  fallback: commands/learn-from-task.md

- name: recall
  kind: command
  triggers: { always: true }
  # Ships static. The per-project part is the ai/ corpus itself, which /learn-from-task
  # writes — there is nothing to author per project, and nothing new to store.
  fallback: commands/recall.md

- name: eval
  kind: command
  triggers: { always: true }
  # Ships static (like learn-from-task) — not project-customized. Its cases ARE the per-project
  # part, and those live in ai/evals/cases/ (baseline scaffold), authored via /eval --seed.
  fallback: commands/eval.md
```

## Note on AUTHOR mode for the learning pack

Most topics here have lenient extraction needs — the agents/skills are project-aware via the `extracted-*` files but don't deeply customize per project. The `convention-drift-detector` and `pattern-emergence-watcher` ARE project-aware (they read project conventions to know what counts as drift / what counts as a recurring shape).

The extractors themselves (`extract-codebase-overview`, `extract-business-context`, `extract-base-class-idiom`) are stable — they ship as-is. They're the engine, not engine output. `extract-base-class-idiom` is parameterised by `unit_kind` and covers all five Phase-2.5 idiom patterns; there are no separate composable / wrapper / service extractors, and a spec that names one is naming a skill this pack does not contain. Since pack v1.2.0 the engine enforces provenance discipline: every claim written to `_extracted-*` files carries `[found: <path:line>]` / `[inferred: <basis>]` / `[unconfirmed]` (business facets use the equivalent `[CONFIDENT]/[INFERRED]/[UNKNOWN]`), and the oracle files carry an `approved_by:`/`approved_hash:` human sign-off stamp checked by `/setup-project-health` check 9. Spec: `templates/phases/phase-2-profile.md § Provenance discipline` + `§ Oracle approval`.
