---
description: Author an operational runbook (incident response, deploy, rollback, on-call playbook). Detects existing runbooks for shape consistency. Captures: trigger, prerequisites, steps with verify-after-each, rollback procedure, on-call assignment, related ADRs. Lands at ai/runbooks/<name>.md. Read-write but conservative.
kind: command
pack: documentation
---

# /add-runbook <name> [<description>]

## The Premise (read this first)

**Runbooks are the difference between "manageable incident" and "all-hands fire drill at 2am".** A good runbook lets the next on-call person resolve an issue without paging the original author. This command authors a runbook with the structure proven across many projects.

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

- `<name>` — kebab-case runbook name (e.g., `restart-tenant-db`, `release-production`, `cutover-feature-flag`).
- `<description>` — optional one-liner; if missing, agent asks during Phase 1.

## Optional flags

- `--type=<incident|deploy|rollback|migration|cutover|on-call>` — runbook type (drives section template).
- `--related-adr=<NNN>` — link to an ADR that motivated this runbook.
- `--related-feature=<id>` — link to a migration ledger row.

## Phase 1 — Understand

Ask (consolidated):
- **Trigger** — what event causes someone to use this runbook? ("Deploy fails" / "Latency p95 > 500ms" / "Tenant cutover scheduled" / "Database restart needed".)
- **Pre-requisites** — what must be true / available before running steps? (Access, credentials, time window, peer review.)
- **Owner** — who's the primary owner? (Team / on-call rotation.)
- **Frequency** — how often is this expected to be invoked?

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
> **Last drill**: <iso-date> (drill = the last time someone executed this for real / in staging)
> **Severity / urgency**: <P0|P1|P2|P3>
> **Estimated time**: <min-max>

## When to use this runbook

Concrete signals (so the on-call knows THIS runbook applies, not a sibling):
- <signal 1, e.g., "alert: database CPU > 90% for 5+ min">
- <signal 2, e.g., "user reports order-placement failures">

## When NOT to use this runbook

- <when a different runbook applies>

## Prerequisites

Before starting:
- [ ] <access requirement, e.g., "AWS console access to prod-db role">
- [ ] <tool requirement, e.g., "kubectl configured for staging-eks">
- [ ] <credential requirement>
- [ ] <time/window requirement, e.g., "off-peak hours preferred">
- [ ] <peer requirement, e.g., "2nd reviewer named in PR">

## Steps

### Step 1 — <action>

```bash
<exact command or click-path>
```

**Verify after**: <observable that proves step worked, e.g., "Output shows 3 pods Running" / "Curl /health returns 200">

If verify fails: <link to "Step 1 failure" subsection below OR "abort and rollback">

### Step 2 — <action>

```bash
<command>
```

**Verify after**: <observable>

(... continue numbered steps until the trigger condition is resolved)

## Rollback procedure

If steps fail mid-way OR the change makes things worse:

1. <rollback action 1, e.g., "scale deployment back to previous replica count">
2. <rollback action 2>
3. <verify the original state is restored>

**Rollback verify**: <observable that proves rollback worked>

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| <observed thing> | <usually because> | <do this> |
| ... | ... | ... |

## Post-runbook actions

- [ ] Update incident log: `ai/runtime/incidents.md`
- [ ] Notify stakeholders: <channel / DL>
- [ ] Schedule post-mortem if severity ≥ P1
- [ ] Update this runbook with anything that surprised you (drift = stale runbook)

## Related

- ADRs: <NNN>, <MMM>
- Other runbooks: <related-runbook-1>, <related-runbook-2>
- Feature: <ledger-row-id> (if applicable)
- Monitoring dashboard: <url>
- Pager rotation: <link>
```

## Phase 5 — Update

- `ai/runbooks/<name>.md` — the runbook file (the `ai/runbooks/` directory is the runbook catalog; there is no separate `ai/index.md` in the baseline, so do not write one).
- `ai/_decision-index.md` — append entry if linked to ADR.

## Phase 6 — Validate

- Every step has a "Verify after:" line — no step is just an action without a check.
- Rollback procedure exists (mandatory; no runbook ships without one).
- Prerequisites are concrete (no "appropriate access" — name the actual role / credential).
- Linked ADRs / features resolve.
- "Last drill" date is honest (use today's date if drilling on creation; "never drilled" is a valid honest answer that flags the runbook for first execution).

## Phase 7 — Improve

- If the project has > 5 runbooks of the same `--type=`, surface "consider a runbook template" — reduces duplication.
- Schedule a quarterly drill for incident-type runbooks; queue ADR if drilled-rate < 1/year.
- If a runbook is invoked > 3× per quarter, flag for automation — recurring manual work is a tooling gap.

## Hard rules

- **Verify-after-each-step is mandatory.** No silent "do this and trust it worked."
- **Rollback procedure is mandatory.** Every runbook MUST have a rollback section. If rollback is impossible (e.g., schema migration that's already applied), document the forward-fix as the rollback.
- **Concrete prerequisites only.** "Have access" → "Have role X in IAM" or "have key file at ~/.config/y/key.json".
- **Drill before declaring done.** Either drill in staging at creation OR mark "never drilled — drill before first incident use."

## Failure modes

- **Name collides with existing runbook** → halt; ask user (rename or update existing).
- **No siblings exist** (first runbook in project) → seed from this command's template, surface "first runbook in project" note.
- **Description suggests not-a-runbook** (e.g., "explain how X works" — that's documentation, not a runbook) → halt; route to `/doc-refresh` or ADR.

## Related

- `/add-adr` — for architectural decisions (different artifact).
- `/doc-refresh` — for general documentation refresh.
- `/migration-rollback` — runs migration-specific rollback (different concept, but related).
