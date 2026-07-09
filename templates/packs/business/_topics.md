# Business pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: business-analyst
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-business.md § Mission + § "Target users" + ai/business-domain.md if exists
  sections: [persona, project_business_context, requirement_template, user_story_template, output_format]
  fallback: _examples/business-analyst.md
  cite_evidence: lenient

- name: business-auditor
  kind: agent
  triggers: { always: true }
  extracts_from: _extracted-business.md § Mission + § Anti-goals + ai/business-flows.md if exists + _extracted-codebase.md § "API surface"
  sections: [persona, audit_methodology, broken_flow_signals, missing_cycle_signals, gap_findings_format]
  fallback: _examples/business-auditor.md

- name: workflow-integrity
  kind: agent
  triggers:
    grep_evidence: "status\\s*(:|=|==).*'|enum .*(pending|paid|shipped|active|cancelled|closed)|xstate|aasm|state_machine|CHECK\\s*\\(.*status|status_changes|\\b(state|phase)\\b\\s*column"
    OR_codebase_section: "an entity carries a status / state / phase column, a state-machine library config, or scattered `if status ==` checks (a lifecycle exists whether drawn or not)"
  extracts_from: _extracted-business.md § "Business cycles" + ai/business-flows.md if exists (declared lifecycle) + _extracted-codebase.md § "API surface" (status-writing routes / service methods / raw UPDATEs)
  sections: [persona, premise, state_graph_reconstruction, transition_checklist, illegal_edge_findings, state_matrix_output, hard_rules]
  mirror_existing: true
  fallback: _examples/workflow-integrity.md   # business 5/5 — the abridged snapshot faithfully mirrors the live agent's premise + checklist + matrix + hard-rules; keep it in sync on edits
  cite_evidence: strict

- name: analyze-task
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-business.md (full)
  sections: [understand, organize, retrieve, generate]
  fallback: _examples/analyze-task.md

- name: audit-business
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-business.md + _extracted-codebase.md § Modules
  sections: [understand, retrieve, generate]
  fallback: _examples/audit-business.md

- name: expand-task
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-business.md
  sections: [understand, generate]
  fallback: _examples/expand-task.md

- name: business-completeness
  kind: rule
  triggers: { always: true }
  sections: [must, must_not, should, review_checklist, failure_history_examples]
  fallback: rules/business-completeness.md

- name: audit-funnel-completion
  kind: skill
  triggers: { always: true }
  sections: [when_to_use, procedure, inputs, outputs, failure_modes]
  fallback: skills/audit-funnel-completion.md

- name: check-business-coverage
  kind: skill
  triggers: { always: true }
  sections: [when_to_use, procedure, inputs, outputs, failure_modes]
  fallback: skills/check-business-coverage.md

- name: missing-counterparts
  kind: ai-pattern
  triggers: { always: true }
  sections: [why, forward_inverse_table, completion_table, recovery_table, anti_patterns, detection]
  fallback: ai-patterns/missing-counterparts.md
```
