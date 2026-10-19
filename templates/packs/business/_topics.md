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
  extracts_from: _extracted-business.md § Mission + § Anti-goals + ai/business-flows.md if exists + ai/users-and-personas.md if exists + _extracted-codebase.md § "API surface"
  sections: [persona, contract, premise, halt_conditions, dispatch, routed, cycle_register, output, hard_rules]
  fallback: _examples/business-auditor.md   # literal copy (generated-from) of the cycle judge; re-copy on every edit

- name: workflow-integrity
  kind: agent
  triggers:
    grep_evidence: "status\\s*(:|=|==).*'|enum .*(pending|paid|shipped|active|cancelled|closed)|xstate|aasm|state_machine|CHECK\\s*\\(.*status|status_changes|\\b(state|phase)\\b\\s*column"
    OR_codebase_section: "an entity carries a status / state / phase column, a state-machine library config, or scattered `if status ==` checks (a lifecycle exists whether drawn or not)"
  extracts_from: _extracted-business.md § "Business cycles" + ai/business-flows.md if exists (declared lifecycle) + lifecycle-scan's graph (status-graph.py) when run
  sections: [persona, contract, premise, halt_conditions, dispatch, routed, transition_matrix, conserve_register, output, hard_rules]
  mirror_existing: true
  fallback: _examples/workflow-integrity.md   # literal copy (generated-from) of the lifecycle judge; re-copy on every edit
  cite_evidence: strict

- name: domain-model-auditor
  kind: agent
  triggers:
    grep_evidence: "class .*(Model|Entity|Aggregate)|schema\\.(prisma|rb)|@Entity|models\\.Model|ActiveRecord::Base|CheckConstraint|BigDecimal|@Embeddable|value.?object"
    OR_codebase_section: "a domain layer exists — ORM model classes, a schema (schema.prisma / schema.rb), migrations with CHECK / UNIQUE constraints, or entities carrying money / inventory / balance invariants"
  extracts_from: _extracted-business.md § Mission + .claude/_refine-extract.md § "Domain entities" if exists + _extracted-codebase.md § Modules (ORM models / migrations) + the money, tax, ledger and report detectors' registers when run
  sections: [persona, contract, premise, halt_conditions, dispatch, routed, edge_battery, output, grading, hard_rules]
  fallback: _examples/domain-model-auditor.md   # literal copy (generated-from) of the business judge; re-copy on every edit
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
  sections: [understand, organize, retrieve, generate, update, validate]
  fallback: _examples/audit-business.md   # literal copy (generated-from); the whole-repo audit over the six detectors, feature mode kept

- name: business-fix
  kind: command
  triggers: { always: true }
  sections: [understand, organize, retrieve, generate, update, validate]
  fallback: commands/business-fix.md   # source-as-fallback: the failing-first loop and its STOP list are the command

- name: expand-task
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-business.md
  sections: [understand, generate]
  fallback: _examples/expand-task.md

- name: suggest-metrics
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-business.md + ai/business-domain.md + ai/users-and-personas.md + the analytics surface
  sections: [understand, retrieve, generate]
  fallback: commands/suggest-metrics.md   # source-as-fallback (phase-4.2-apply.md step 2). A `stub-from-sections` stub here materialised as three empty headings on greenfield, losing all three recommendation gates and the closure verbs that ARE the command.

- name: suggest-features
  kind: command
  triggers: { always: true }
  extracts_from: _extracted-business.md + ai/business-domain.md + business-domains/<domain>/feature-checklist.md + the codebase capability inventory
  sections: [understand, retrieve, generate]
  fallback: commands/suggest-features.md   # source-as-fallback (phase-4.2-apply.md step 2). Same defect as suggest-metrics: the stub dropped the Domain-warranted / Missing / Analyze-task-ready gates, the reverse `defer-capability` gate and the → Spec it pipeline.

- name: business-completeness
  kind: rule
  triggers: { always: true }
  sections: [must, must_not, should, review_checklist, enforcement]
  fallback: rules/business-completeness.md

- name: check-business-coverage
  kind: skill
  triggers: { always: true }
  extracts_from: _extracted-codebase.md § "API surface" (routes) + ai/business-flows.md if exists (declared cycles)
  fallback: skills/check-business-coverage/SKILL.md   # source-as-fallback; CY §1–§6 from the route inventory, the walk only with --live

- name: pricing-rule-scan
  kind: skill
  triggers:
    grep_evidence: "\\b(price|pricing|discount|coupon|promo\\w*|refund|currency|exchange_?rate|fx_?rate|prorat\\w*|subscription|billing|renewal|minor_?units?|amount_?cents)"
    OR_codebase_section: "the project prices, discounts, refunds, converts currencies or bills by period (signal-gated: no money surface → skip)"
  extracts_from: _extracted-codebase.md § Modules (money module, pricing, promotions, refunds, billing) + ai/business-domain.md if exists (the money policy)
  fallback: skills/pricing-rule-scan/SKILL.md   # source-as-fallback; renamed from pricing-tax-audit (tax moved to tax-invoice-scan)

- name: tax-invoice-scan
  kind: skill
  triggers:
    grep_evidence: "\\b(tax|vat|gst|invoices?|receipts?|credit_?notes?|e_?invoic\\w*|ubl|xrechnung|zugferd|peppol|zatca|fatoora|ksef)"
    OR_codebase_section: "the project computes tax, issues invoices, receipts or credit notes, or builds e-invoices for an authority (signal-gated)"
  extracts_from: _extracted-codebase.md § Modules (tax computation, document models, e-invoice builders, CI validation steps)
  fallback: skills/tax-invoice-scan/SKILL.md   # source-as-fallback

- name: ledger-scan
  kind: skill
  triggers:
    grep_evidence: "\\b(ledger|journal|postings?|wallet_?transactions?|balance_?transactions?|reconcil\\w*|payouts?|retention|purge|anonymi[sz]\\w*)"
    OR_codebase_section: "the project keeps a ledger, wallet or balance table, reconciles with a provider, or deletes / purges records of fact (signal-gated)"
  extracts_from: _extracted-codebase.md § Modules (ledger tables and posting functions, deletion flows, purge jobs) + the migrations (constraints, triggers)
  fallback: skills/ledger-scan/SKILL.md   # source-as-fallback

- name: report-scan
  kind: skill
  triggers:
    grep_evidence: "(?i)\\b(select\\b[^;]{0,200}\\b(sum|count|avg)\\s*\\(|date_trunc|at\\s+time\\s+zone|revenue|gmv|dashboard|report\\w*|business_?days?|holidays?)"
    OR_codebase_section: "the project aggregates money or counts for a dashboard, an export, a payout or a report, or computes business days and cutoffs (signal-gated)"
  extracts_from: _extracted-codebase.md § Modules (report queries, metric helpers, exports) + ai/business-domain.md if exists (metric definitions, the business zone)
  fallback: skills/report-scan/SKILL.md   # source-as-fallback

- name: lifecycle-scan
  kind: skill
  triggers:
    grep_evidence: "(?i)\\b(enum\\s+\\w*(status|state)|\\w*_STATUSES\\b|status\\s*[:=]\\s*['\"]|createMachine|aasm|@transition|TRANSITIONS|check\\s*\\(\\s*status)"
    OR_codebase_section: "an entity carries a status / state / phase column, a transition table or an FSM library config (signal-gated)"
  extracts_from: _extracted-codebase.md § Modules (entities, status enums, transition tables, webhook handlers) + ai/business-flows.md if exists (the declared lifecycle)
  fallback: skills/lifecycle-scan/SKILL.md   # source-as-fallback; ships scripts/status-graph.py

- name: missing-counterparts
  kind: ai-pattern
  triggers: { always: true }
  sections: [cost_of_half_cycles, forward_inverse_table, completion_table, recovery_table, anti_patterns, detection]
  fallback: ai-patterns/missing-counterparts.md
```
