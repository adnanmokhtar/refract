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
```
