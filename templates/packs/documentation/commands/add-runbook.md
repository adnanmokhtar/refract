---
description: "Author an operational runbook (incident response, deploy, rollback, on-call playbook). Detects existing runbooks for shape consistency. Captures: trigger, prerequisites, steps with verify-after-each, rollback procedure, on-call assignment, related ADRs. Lands at ai/runbooks/<name>.md. Read-write but conservative."
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
> **Last drill**: <iso-date | not-yet-run> (drill = the last time someone executed this for real / in staging; `not-yet-run` if never drilled)
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
- **Linked ADRs / features resolve to real files.** For every `<NNN>` in the `## Related` ADRs line and every `--related-feature` / ledger-row link, check the path actually exists — `ls ai/decisions/<NNN>-*.md` (or grep `ai/_decision-index.md` for the row) resolves to a file, and the feature id is present in the migration ledger. A link that resolves to nothing is a dangling reference: halt and flag it (remove the link or fix the id) — do not ship a runbook that points at an ADR that isn't there.
- **Drill status is marked, not assumed.** If the procedure was actually executed (in staging or for real) at creation, set `Last drill: <today>`. If it was NOT drilled, the front-matter MUST read `Last drill: not-yet-run` (and the runbook is flagged for first-execution review) — an undrilled runbook is honestly labelled `not-yet-run`, never silently accepted as done.

### Command-resolution gate — regenerate → diff → cite, runbook flavour

A runbook step is a *claim* that a command exists and does the stated thing; an unresolvable command is the runbook equivalent of a doc naming a dead symbol, and it fails at 2am when nobody can debug it. Before verdict, re-derive every step command from the repo and cite the miss (mirrors how `doc-refresh` runs `doc-drift-scan` and how `@api-documenter` regenerates the spec):

- **Script/target refs** — for each `npm|pnpm|bun run <x>` / `make <t>` / `just <t>` / `<repo-script>.sh` in a step, confirm it resolves (`jq -e '.scripts["<x>"]' package.json`, the `Makefile`/`Justfile` target list, or `test -e` the script). An unresolved one is `BROKEN` — cite `<step:line>` + the negative check and halt; a step nobody can run is not a runbook.
- **Path/role/dashboard refs** — paths named in steps or Prerequisites that should exist in-repo (`test -e`), and named roles/dashboards resolve to a real identifier, not a placeholder.
- Bare operational commands against live infra (`kubectl`, cloud CLIs) are **not** resolvable from the repo — mark them `UNVERIFIED (live-infra)`, the runbook flavour of a documented prerequisite, never a fabricated pass.

### Terminal verdict — DRILLED-PRODUCTION-GRADE vs AUTHORED-UNPROVEN

A runbook that reads correctly but was never executed is the *floor*, not the finish — the whole failure mode of runbooks is the step that looked right and didn't run. Emit exactly one, reading off the front-matter `Last drill` field (the artifact of record a reviewer can check) plus the command-resolution counts:

- `Status: PRODUCTION-GRADE` — **only** when `Last drill: <date>` (steps were executed → each "Verify after" observable actually observed), command-resolution `BROKEN` = 0, and all `## Related` links resolve. The drill is this domain's regenerate→run→observe evidence; without it the runbook is unproven.
- `Status: AUTHORED-UNPROVEN` — the honest default for a `Last drill: not-yet-run` runbook (or any with an open `BROKEN` command / dangling link). It ships (an undrilled runbook still beats none) but is **flagged for first-drill before first real incident use**, and names what is unproven. This is a labelled-incomplete success, never dressed as done.

## Phase 7 — Improve

- If the project has > 5 runbooks of the same `--type=`, surface "consider a runbook template" — reduces duplication.
- Schedule a quarterly drill for incident-type runbooks; queue ADR if drilled-rate < 1/year.
- If a runbook is invoked > 3× per quarter, flag for automation — recurring manual work is a tooling gap.

## Hard rules

- **Verify-after-each-step is mandatory.** No silent "do this and trust it worked."
- **Rollback procedure is mandatory.** Every runbook MUST have a rollback section. If rollback is impossible (e.g., schema migration that's already applied), document the forward-fix as the rollback.
- **Concrete prerequisites only.** "Have access" → "Have role X in IAM" or "have key file at ~/.config/y/key.json".
- **Drill before declaring done.** Either drill in staging at creation OR mark "never drilled — drill before first incident use."
- **`PRODUCTION-GRADE` requires a real `Last drill: <date>` + 0 `BROKEN` command refs.** An undrilled or unresolved-command runbook is `AUTHORED-UNPROVEN`, never `COMPLETE`/`PRODUCTION-GRADE` — the verdict is read off the front-matter drill field, not asserted.

## Failure modes

- **Name collides with existing runbook** → halt; ask user (rename or update existing).
- **No siblings exist** (first runbook in project) → seed from this command's template, surface "first runbook in project" note.
- **Description suggests not-a-runbook** (e.g., "explain how X works" — that's documentation, not a runbook) → halt; route to `/doc-refresh` or ADR.

## Related

- `/add-adr` — for architectural decisions (different artifact).
- `/doc-refresh` — for general documentation refresh.
- `/migration-rollback` — runs migration-specific rollback (different concept, but related).
