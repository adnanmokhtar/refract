---
description: Author an operational runbook (incident response, deploy, rollback, on-call playbook). Detects existing runbooks for shape consistency. Captures: trigger, prerequisites, steps with verify-after-each, rollback procedure, on-call assignment, related ADRs. Lands at ai/runbooks/<name>.md. Read-write but conservative.
kind: command
pack: documentation
---

# /add-runbook <name> [<description>]

Authors an operational runbook with the structure proven across many projects: trigger, prerequisites, steps with verify-after-each, rollback, on-call owner, related ADRs. A good runbook lets the next on-call person resolve an issue without paging the original author.

## When to use

- New deploy / release process needs documenting.
- Recurring incident type needs a response playbook.
- Migration / rollback procedure needs codifying.
- A "bus factor 1" procedure needs to be made knowledge-shared.

## When NOT to use

- For a one-off task → use a ticket / commit message.
- For architectural decisions → use `/add-adr`.
- For the discipline rules of how a feature works → use `ai/conventions.md` or pack rules.

## Args

- `<name>` — kebab-case runbook name (e.g., `restart-tenant-db`, `release-production`).
- `<description>` — optional one-liner; if missing, agent asks during Phase 1.

## Optional flags

- `--type=<incident|deploy|rollback|migration|cutover|on-call>` — drives section template.
- `--related-adr=<NNN>` — link to an ADR that motivated this runbook.
- `--related-feature=<id>` — link to a migration ledger row.

## Phase 1 — Understand

Ask (consolidated): **Trigger** (what event causes someone to use this?), **Prerequisites** (access / credentials / time window / peer review), **Owner** (team / on-call rotation), **Frequency**.

## Phase 2 — Organize

```
1. UNDERSTAND     — gather inputs above
2. READ-SIBLINGS  — read 1-2 existing runbooks for shape consistency
3. DRAFT          — author the runbook with the standard sections
4. VERIFY         — link to ADR / feature, confirm prerequisites are real
5. WRITE          — land at ai/runbooks/<name>.md
```

## Phase 3 — Retrieve

- `ai/runbooks/` — read existing runbooks for shape consistency.
- `ai/decisions/<NNN>-*.md` — link relevant ADRs.
- `ai/_decision-index.md` — quick-find for related decisions.

## Phase 4 — Generate (template)

```markdown
# Runbook: <name>

> **Trigger**: <event that causes someone to use this>
> **Owner**: <team / on-call>
> **Last drill**: <iso-date>
> **Severity / urgency**: <P0|P1|P2|P3>
> **Estimated time**: <min-max>

## When to use this runbook
- <concrete signal 1>
- <concrete signal 2>

## When NOT to use this runbook
- <when a different runbook applies>

## Prerequisites
- [ ] <access / tool / credential / time-window / peer requirement>

## Steps

### Step 1 — <action>
```bash
<exact command or click-path>
```
**Verify after**: <observable that proves step worked>
If verify fails: <link to failure subsection OR "abort and rollback">

(... continue numbered steps until the trigger condition is resolved)

## Rollback procedure
1. <rollback action 1>
2. <rollback action 2>
3. <verify the original state is restored>
**Rollback verify**: <observable that proves rollback worked>

## Common failure modes
| Symptom | Cause | Fix |
|---|---|---|
| <observed thing> | <usually because> | <do this> |

## Post-runbook actions
- [ ] Update incident log: `ai/runtime/incidents.md`
- [ ] Notify stakeholders / schedule post-mortem if severity ≥ P1
- [ ] Update this runbook with anything that surprised you

## Related
- ADRs: <NNN>, <MMM>
- Other runbooks / Feature / Monitoring dashboard / Pager rotation
```

## Phase 5 — Update

- `ai/runbooks/<name>.md` — the runbook file (the `ai/runbooks/` directory is the runbook catalog; there is no separate `ai/index.md` in the baseline, so do not write one).
- `ai/_decision-index.md` — append entry if linked to ADR.

## Phase 6 — Validate

- Every step has a "Verify after:" line — no step is just an action without a check.
- Rollback procedure exists (mandatory; no runbook ships without one).
- Prerequisites are concrete (name the actual role / credential).
- Linked ADRs / features resolve.
- "Last drill" date is honest ("never drilled" is a valid honest answer that flags first execution).

## Hard rules

- **Verify-after-each-step is mandatory.**
- **Rollback procedure is mandatory.** If rollback is impossible, document the forward-fix as the rollback.
- **Concrete prerequisites only.** "Have access" → "Have role X in IAM".
- **Drill before declaring done** OR mark "never drilled — drill before first incident use."

## Failure modes

- **Name collides with existing runbook** → halt; ask user.
- **No siblings exist** → seed from this template, surface "first runbook in project" note.
- **Description suggests not-a-runbook** → halt; route to `/doc-refresh` or ADR.
