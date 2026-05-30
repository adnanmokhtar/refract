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
  fallback: skills/extract-project-context.md

- name: extract-codebase-overview
  kind: skill
  triggers: { always: true }
  # The orchestrator skill itself — no fallback because if this is missing, AUTHOR mode is broken everywhere.
  fallback: skills/extract-codebase-overview.md

- name: extract-business-context
  kind: skill
  triggers: { always: true }
  fallback: skills/extract-business-context.md

- name: extract-base-class-idiom
  kind: skill
  triggers: { codebase_has_base_classes: true }
  fallback: skills/extract-base-class-idiom.md

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
```

## Note on AUTHOR mode for the learning pack

Most topics here have lenient extraction needs — the agents/skills are project-aware via the `extracted-*` files but don't deeply customize per project. The `convention-drift-detector` and `pattern-emergence-watcher` ARE project-aware (they read project conventions to know what counts as drift / what counts as a recurring shape).

The extractors themselves (`extract-codebase-overview`, `extract-business-context`, `extract-base-class-idiom`) are stable — they ship as-is. They're the engine, not engine output.
