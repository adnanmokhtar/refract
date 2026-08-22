---
description: Author an operational runbook (incident response, deploy, rollback, on-call playbook). Detects existing runbooks for shape consistency. Captures: trigger, prerequisites, steps with verify-after-each, rollback procedure, on-call assignment, related ADRs. Lands at ai/runbooks/<name>.md. Read-write but conservative.
kind: command
pack: documentation
---

# /add-runbook <name> [<description>]

Authors an operational runbook with the structure proven across many projects: trigger, prerequisites, steps with verify-after-each, rollback, on-call owner, related ADRs. A good runbook lets the next on-call person resolve an issue without paging the original author.

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

- `<name>` — kebab-case runbook name (e.g., `restart-tenant-db`, `release-production`).
- `<description>` — optional one-liner; if missing, agent asks during Phase 1.

## Optional flags

- `--type=<incident|deploy|rollback|migration|cutover|on-call>` — drives section template.
- `--related-adr=<NNN>` — link to an ADR that motivated this runbook.
- `--related-feature=<id>` — link to a migration ledger row.

## Phase 1 — Understand

Ask (consolidated): **Trigger** (what event causes someone to use this?), **Prerequisites** (access / credentials / time window / peer review), **Owner** (team / on-call rotation), **Frequency**.

## Phase 2 — Organize

Map the work onto the house phases — this command does NOT renumber them. (An earlier version
listed its own `1. UNDERSTAND … 5. WRITE` pipeline, which read as a competing phase scheme and made
"step 4" ambiguous between this command's step and the framework's Phase 4.)

| House phase | What it does here |
|---|---|
| Phase 1 Understand | gather trigger / prerequisites / owner / frequency (above) |
| **Phase 2 Organize** | read 1-2 existing runbooks in `ai/runbooks/` and lock their shape — section list, ordering, front-matter fields. A new runbook is a sibling, not a new template. Decide the `--type=` and therefore which sections apply. |
| Phase 3 Retrieve | siblings, related ADRs, `ai/_decision-index.md` |
| Phase 4 Generate | author the runbook from the template below |
| Phase 5 Update | land `ai/runbooks/<name>.md`; append the ADR link to the index |
| Phase 6 Validate | verify-after-each present, rollback present, prerequisites concrete, links resolve, commands resolve, drill status marked |
| Phase 7 Improve | template/automation/drill-cadence signals |

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
- "Last drill" date is honest — if the procedure was actually executed, set `Last drill: <today>`; if not, the front-matter MUST read `Last drill: not-yet-run` and the runbook is flagged for first-execution review.

### Command-resolution gate — regenerate → diff → cite

A runbook step is a *claim* that a command exists and does the stated thing. Before verdict, re-derive every step command from the repo and cite the miss:

- **Script/target refs** — each `npm|pnpm|bun run <x>` / `make <t>` / `just <t>` / `<repo-script>.sh` must resolve. An unresolved one is `BROKEN` — cite `<step:line>` + the negative check and halt.
- **Path/role/dashboard refs** — paths named in steps or Prerequisites exist in-repo; named roles/dashboards resolve to a real identifier, not a placeholder.
- Bare operational commands against live infra (`kubectl`, cloud CLIs) are **not** resolvable from the repo — mark them `UNVERIFIED (live-infra)`, never a fabricated pass.

### Terminal verdict — DRILLED-PRODUCTION-GRADE vs AUTHORED-UNPROVEN

- `Status: PRODUCTION-GRADE` — **only** when `Last drill: <date>`, command-resolution `BROKEN` = 0, and all `## Related` links resolve.
- `Status: AUTHORED-UNPROVEN` — the honest default for a `Last drill: not-yet-run` runbook (or any with an open `BROKEN` command / dangling link). It ships, flagged for first-drill before first real incident use, naming what is unproven.

## Phase 7 — Improve

- If the project has > 5 runbooks of the same `--type=`, surface "consider a runbook template" — reduces duplication.
- Schedule a quarterly drill for incident-type runbooks; queue ADR if drilled-rate < 1/year.
- If a runbook is invoked > 3× per quarter, flag for automation — recurring manual work is a tooling gap.

## Hard rules

- **Verify-after-each-step is mandatory.**
- **Rollback procedure is mandatory.** If rollback is impossible, document the forward-fix as the rollback.
- **Concrete prerequisites only.** "Have access" → "Have role X in IAM".
- **Drill before declaring done** OR mark "never drilled — drill before first incident use."

## Failure modes

- **Name collides with existing runbook** → halt; ask user.
- **No siblings exist** → seed from this template, surface "first runbook in project" note.
- **Description suggests not-a-runbook** → halt; route to `/doc-refresh` or ADR.
