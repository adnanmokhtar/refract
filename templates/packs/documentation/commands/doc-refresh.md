---
description: Comprehensive post-work documentation refresh. Prepends Recent Changes entry, updates modules / stack / conventions if they changed, runs drift detection, writes ADRs / patterns / runbooks as discovered, and flags stale docs.
kind: command
pack: documentation
---

# /doc-refresh

Run after EVERY significant change. Keeps `ai/` honest with reality. This command IS Phase 5 (Update) elevated to a standalone routine — it's the heavyweight version other commands invoke implicitly.

## The Premise (read this first, internalize, do not deviate)

**Existing docs are the truth, but code is the supreme truth.** Refresh = **re-derive from code; never invent**. If `ai/architecture.md` says the auth module lives at `<modules-root>/auth/session/` and the code says `<modules-root>/auth/jwt/`, **docs lose**. The repair is to update docs to match code, not to lament the rename or to ADR-justify the doc state. Docs that drift from code stop being read; the way back is honest re-derivation.

**The agent's job is exactly this:**
1. Walk `git log <base>..HEAD --stat` to find what changed.
2. For each `ai/` file, **re-derive its content from current code/state** — modules from filesystem, env vars from `.env.example`, scripts from `package.json`, schema from migrations, endpoints from controllers.
3. Where docs and code disagree, **edit docs**. Code wins. Always.
4. Drift findings are reported, not silently fixed if the user might need to know (e.g., a path rename that was undocumented might indicate an unfinished refactor).

**The agent does NOT:**
- Invent a section, pattern, ADR, or runbook with no code basis. Speculative docs are noise.
- Edit `ai/architecture.md` to justify a doc/code mismatch with a "the system is being migrated" narrative. Update docs to match code, full stop.
- Delete prior `Recent Changes` entries. Always prepend.
- Leave placeholders (`<TODO>`, `<name>`, `{{}}`) in any updated doc. The validator rejects.
- Skip the cross-repo sweep. Path references in `ai/` that no longer exist are silent rot.

**Mechanical halt — hand-wave grep + cite-or-halt (mandatory before Phase 6 write):**

Before bumping `Updated:` and committing the refresh, the agent MUST grep its own doc edits and reject any new line that:
- Asserts a module / file / table / endpoint / env var that does not exist (filesystem / `.env.example` / migration / route table).
- Contains `<TODO>`, `<name>`, `{{}}`, `XXX`, `TBD` — placeholders ship as bugs.
- Adds a pattern to `ai/patterns/` without 2+ code instances proving the pattern is real and reusable.
- Adds an ADR alternative that is a straw-man (no real pros listed).
- Re-states a doc claim that the code-derivation step contradicts.

Any line that fails the grep is **dropped or rewritten from code**, not softened. Drift findings (path references that no longer exist, env vars in `ai/stack.md` not in `.env.example`, scripts in `CLAUDE.md` not in `package.json`) are reported in `ai/dynamic/drift-log.md` with severity. Code-vs-docs conflicts always resolve in code's favor; docs are edited.

## The production bar — regenerate → diff → cite (declare PRODUCTION-GRADE or INCOMPLETE, never "a file got written")

**A doc file existing, free of placeholders, with tables that render is the FLOOR, not the finish.** Those checks (Phase 6 "Verify generated docs") prove the doc is *well-formed* — they say nothing about whether it is *true*. A beautifully-rendered `ai/stack.md` that names an env var deleted three commits ago is a well-formed lie. The production bar for a doc set is higher and it is comparative: a refresh is PRODUCTION-GRADE only when the docs have been **re-derived from the current source and diffed against what's committed, with the diff clean or the deltas applied**, its runnable examples **actually ran**, and its cross-references **resolve** — each proven by a cited probe, not asserted. This is the same "does it BEAT the baseline, verified not asserted" bar `@api-documenter` already enforces on the OpenAPI spec + SDK (regenerate the spec from annotations, `oasdiff` against the committed baseline, halt on drift); this command holds the `ai/` knowledge base to it.

**The three gates that separate FUNCTIONAL from PRODUCTION-GRADE (all wired, all cited):**

1. **Drift gate (regenerate → diff → cite).** Dispatch `doc-drift-scan` ([`skills/doc-drift-scan/SKILL.md`](../skills/doc-drift-scan/SKILL.md)). It re-derives every doc claim from the source of truth (filesystem, `package.json`, `.env.example`, migrations, route table) and diffs it against the committed doc — emitting `BROKEN` (a path/script/env/table/signature the code no longer backs) and `STALE` findings with paired `<doc:line>` + `<src:line>` citations. **`BROKEN` count > 0 ⇒ the doc set is STALE, not production-grade.** A `BROKEN` finding the refresh created is fixed from code before verdict; a pre-existing `BROKEN` finding in another doc is reported and **blocks the PRODUCTION-GRADE verdict** — the honest terminal state is `INCOMPLETE`, never `COMPLETE`-with-open-drift. "The docs look current" without the scan's cited output is not a pass; if `doc-drift-scan` is not installed, run the Phase 6 fallback bash and record the axis as `UNVERIFIED (skill absent)` — never a silent green.
2. **Runnable-example gate.** Any doc the refresh touched that carries an executable path — a getting-started / setup block, a quickstart, a copy-pasteable command sequence — is proven by dispatching `quickstart-verify` ([`skills/quickstart-verify/SKILL.md`](../skills/quickstart-verify/SKILL.md)) in a clean env: every step runs, or the doc's example is stale. A doc with no runnable surface records this gate `N/A`; a doc with one that could not be executed (no clean env available) records `SKIPPED (no clean env)` — a labelled skip, never a faked pass.
3. **Link-resolution gate.** Every `see ADR-NNNN`, `ai/runbooks/<name>.md`, pattern cross-ref, and relative path the refresh wrote or touched resolves to a real file (`doc-drift-scan` step 5 covers ADR cross-refs; `ls`/`test -e` the rest). One dangling reference ⇒ the doc set is not production-grade.

**Terminal verdict (the closure discipline of this command).** After Phase 6 the run emits exactly one:
- `Status: PRODUCTION-GRADE` — **only** when drift `BROKEN` = 0, every runnable-example gate is `PASS`/`N/A`/`SKIPPED (no clean env)`, and every link resolves. The verdict line MUST carry the cited evidence counts (see the required artifact below) so a reader can re-check it.
- `Status: INCOMPLETE` — the honest default whenever any gate fails or is `UNVERIFIED`. It **names every unmet item** (`2 BROKEN drift findings: <doc:line> → <src:line>`; `quickstart step 4 FAILED`; `dangling ADR-0031`) and states what would close each. Reporting `INCOMPLETE` with the list is a *success* of this command; reporting `COMPLETE` while a `BROKEN` finding is open is the failure this gate exists to prevent.

**Required output artifact (this is what makes the gate mechanical, not vibes).** The verdict is not trusted on the agent's word — it reads off a produced, checkable artifact: the `ai/dynamic/drift-log.md` entry this run appends, which MUST record the dated line `refresh <scope> — drift BROKEN=<n> STALE=<n> · examples <PASS|N/A|SKIPPED|FAIL> · links <resolved>/<total> · verdict <PRODUCTION-GRADE|INCOMPLETE>` plus the cited findings. `PRODUCTION-GRADE` with `BROKEN` ≠ 0 in its own log line is a self-contradiction any reviewer catches. If that artifact is absent or its verdict disagrees with its counts, the refresh did not close.

BAD (functional, declared done): "✅ Doc refresh complete — updated status.md, modules.md, stack.md. Markdown renders, no placeholders. Status: COMPLETE." (Nothing was regenerated-and-diffed; a renamed path in `architecture.md` still resolves to nothing — the doc set is a well-formed lie certified green.)
GOOD (production bar, verified): "Status: INCOMPLETE — drift BROKEN=1 (`ai/architecture.md:47` says `<modules-root>/auth/session/`; `git log --diff-filter=R` shows it renamed to `auth/jwt/` in `def456a`), examples N/A, links 6/6. To reach PRODUCTION-GRADE: update that reference from code. Logged to `ai/dynamic/drift-log.md`."

## Phases applied

1, 3, 5, 6, 7. Phase 2 (Organize) is light (template-driven). Phase 4 (Generate) = N/A as code; Phase 5 IS the work — generate docs.

## When to use / NOT to use

- USE: after every significant code change.
- USE: before opening a PR with substantial scope (feature, migration, new module).
- USE: when `ai/status.md` `Updated:` is >30 days stale.
- NOT: for trivial edits (lint fix, typo) — overhead exceeds value.
- NOT: as a substitute for ADRs on truly architectural decisions — those belong in `ai/decisions/`.

## Phase 1 — Understand (the diff scope)

```bash
git status
git log <base>..HEAD --stat   # full diff scope
```

- Identify the base branch (`main` or `master` per repo convention).
- Identify the user's intent: refresh after a feature? After a migration? Quarterly drift sweep?
- Confirm scope: this WILL mutate `ai/status.md` and possibly add ADRs / pattern files.

## Phase 2 — Organize (classify + plan)

From the diff, classify what changed:
- New modules?
- Deleted modules?
- New patterns emerged (same shape appeared 3+ times)?
- Architectural decisions made?
- New dependencies / tool versions / env vars?
- New / removed endpoints?
- New / changed DB schema?
- New / removed rules or guardrails?

Plan which `ai/` files will be touched based on classification.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md). (Include `ai/status.md` as style + format reference.)

DOC-SPECIFIC:
- `git log <base>..HEAD --stat` — full diff scope.
- All `.claude/rules/` — know doc obligations.
- `ai/modules.md`, `ai/stack.md`, `ai/conventions.md`, `ai/architecture.md` — current state to compare against.
- `ai/decisions/` index — what ADRs already exist (avoid duplication).

## Phase 4 — N/A

No application code generated. (Doc generation is Phase 5.)

## Phase 5 — Update (dispatch doc-writer + write all docs)

Dispatch `doc-writer` agent with:
- The diff summary.
- The recent commits.
- The discovered categories from Phase 2.

Doc-writer is responsible for:

### Recent Changes entry (mandatory)

Prepend to `ai/status.md` under `## Recent Changes (YYYY-MM-DD)`:

```markdown
### <Short title>
- What changed: <concrete, names modules/files/tables>
- Why: <business driver, incident, tech need — 1 sentence>
- How: <3-5 bullets of KEY choices>
- Follow-ups: <leftover tickets>
```

NEVER delete prior entries.

### Module inventory (`ai/modules.md`)

If modules added/removed/renamed — update the table.

### Stack (`ai/stack.md`)

If dependency versions / env vars / scripts changed — sync.

### Conventions (`ai/conventions.md`)

If a new convention was formalized — document.

### Architecture (`ai/architecture.md`)

If the system diagram / layer rules / schema changed at an architectural level — update.

### Patterns (`ai/patterns/<new>.md`)

If a new reusable pattern emerged:
- The pattern must have appeared in >1 place OR be intentionally reusable.
- Full pattern shape: when / when-NOT / code / edge cases / forbidden.

### ADRs (`ai/decisions/NNNN-*.md`)

If an architectural decision was made:
- Context / Decision / Consequences / Alternatives.
- Supersede existing ADR if this reverses it.

### Runbooks (`ai/runbooks/<name>.md`)

If a new operational procedure is needed:
- Deploy / rollback / incident / onboarding / periodic maintenance.

### Bump `Updated:` line in `ai/status.md` to today.

### Append to `ai/dynamic/changelog.md`: "doc-refresh after <feature>".

## Phase 6 — Validate (drift detection + correctness)

### Verify generated docs

- No placeholder text (`<TODO>`, `<name>`, `{{}}`).
- `ai/status.md` has `Updated:` line + `## Recent Changes` section (SessionStart hook dependency).
- New patterns have "When NOT" + "Forbidden" sections.
- New ADRs have Alternatives section.
- Markdown renders correctly (tables aligned, code blocks closed).

### Drift detection (dispatch `doc-drift-scan` — primary path)

**Dispatch the purpose-built `doc-drift-scan` skill** ([`templates/packs/documentation/skills/doc-drift-scan/SKILL.md`](../skills/doc-drift-scan/SKILL.md)) — it owns the full cross-check (file refs, package scripts, env vars, schema tables, ADR cross-refs, `Updated:` age, module-row drift) with rename-aware halts and glob-stripping the inline bash below does not have. Consume its `BROKEN` / `STALE` findings directly into the drift report.

The inline bash below is a **fallback only** — run it when the skill is not installed in this project (never skip the drift axis: a silent-clean drift sweep reads as "docs are honest" when they were never checked):

```bash
# File paths in ai/ that no longer exist
rg "src/[a-z/-]+" ai/ -o | sort -u | while read path; do
  [ -e "$path" ] || echo "missing: $path (referenced in ai/)"
done

# Env vars in ai/stack.md not in .env.example
grep -oE '[A-Z_][A-Z0-9_]+' ai/stack.md | sort -u > /tmp/stack_vars
grep -oE '^[A-Z_][A-Z0-9_]+' .env.example | sort -u > /tmp/env_vars
comm -23 /tmp/stack_vars /tmp/env_vars  # in stack.md but not .env.example

# Commands in CLAUDE.md not in package.json scripts
# (framework-specific — extract script names + verify)

# ai/status.md age (portable: GNU date first, BSD/macOS date as fallback)
updated=$(head -1 ai/status.md | sed 's/Updated: //')
updated_epoch=$(date -d "$updated" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$updated" +%s 2>/dev/null)
age_days=$(( ($(date +%s) - updated_epoch) / 86400 ))
[ "$age_days" -gt 30 ] && echo "ai/status.md is $age_days days old"
```

Flag drift separately from the current change. Drift findings reported, not silently fixed (user may need to know).

### Runnable-example + link gates (the other two production-bar axes)

- For every doc the refresh touched that has an executable setup/quickstart/command block, dispatch `quickstart-verify` in a clean env (gate 2 above). Record `PASS` / `FAIL (step N)` / `N/A` / `SKIPPED (no clean env)` — never omit the axis.
- Resolve every cross-reference the refresh wrote (gate 3). Record `links <resolved>/<total>`.

### Terminal gate — compute the verdict from the cited counts, then write the artifact

Do not free-narrate "complete". Take the three axes' recorded results and apply the rule from *The production bar* above:

- `BROKEN` = 0 **and** every example gate ∈ {`PASS`,`N/A`,`SKIPPED (no clean env)`} **and** links fully resolve ⇒ `Status: PRODUCTION-GRADE`.
- otherwise ⇒ `Status: INCOMPLETE`, naming each unmet item + what closes it.

Append the machine-checkable line to `ai/dynamic/drift-log.md` (the required artifact): `refresh <scope> — drift BROKEN=<n> STALE=<n> · examples <…> · links <r>/<t> · verdict <…>`. A verdict that contradicts its own counts (`PRODUCTION-GRADE` with `BROKEN`>0) means the refresh did not close — fix the drift from code or downgrade to `INCOMPLETE`.

## Phase 7 — Improve (feed the learning loop)

- If drift was found: append to `ai/dynamic/drift-log.md` with severity.
- If new pattern was promoted to formal `ai/patterns/`: also update `ai/dynamic/learned-patterns.md` (mark as PROMOTED).
- If ADR conflict surfaced: queue to `ai/dynamic/decisions-pending.md`.
- Run `/learn-from-task` if the refresh covered a substantial body of work.

## Example run

### Triggered by: PR "add subscription tier management"

```
git diff main..HEAD:
  + <modules-root>/subscriptions/ (new module — 14 files)
  + <migrations-root>/012-create-subscriptions-table.sql
  + <modules-root>/subscriptions/application/use-cases/*
  + <locales-root>/en.json: +8 keys (subscriptions.*)
  + <locales-root>/ar.json: +8 keys
  ~ <source-root>/app.module.<ext>: SubscriptionsModule added
  ~ <project-manifest>: +<payment-provider-sdk>
  ~ .env.example: +PAYMENT_PROVIDER_SECRET_KEY, PAYMENT_PROVIDER_WEBHOOK_SECRET
```

### Documents updated

1. **ai/status.md** — prepended Recent Changes entry:
```
### Subscription tier management (P2 start)
- What changed: added /subscriptions module (CRUD + payment-provider sync), `subscriptions` table, 3-tier plan (trial/starter/pro).
- Why: kicks off Phase 2 monetization per ai/runbooks/phase-2-plan.md.
- How:
  - Schema: `subscriptions(tenant_id, plan, started_at, expires_at, provider_subscription_id)` with CHECK on plan enum.
  - Service: `SubscriptionService` wraps the payment provider's customer + subscription APIs.
  - Webhook: `customer.subscription.updated` (provider event) → state sync.
  - ADR 0007 records plan-change migration strategy.
- Follow-ups:
  - Usage meter (ticket BILLING-42).
  - Plan-based hard limits (BILLING-19).
  - Admin UI for plan management (P3).
```

2. **ai/modules.md** — new row:
```
| subscriptions | <modules-root>/subscriptions | provider-synced subscription tier management | P2 |
```

3. **ai/stack.md** — added:
```
- Payments: payment provider (the project's chosen vendor SDK)
- Env: PAYMENT_PROVIDER_SECRET_KEY, PAYMENT_PROVIDER_WEBHOOK_SECRET
```

4. **ai/decisions/0007-subscription-plan-migration-strategy.md** — new ADR.

5. **ai/patterns/** — no new pattern this PR (flag for later if multiple billing features emerge that share a shape).

### Drift found

- `ai/architecture.md` references `<modules-root>/auth/session/` which was renamed to `<modules-root>/auth/jwt/` in a prior PR. 
  → Fix: update reference. (Separate mini-PR or include.)

- `ai/status.md` `Updated:` was 42 days old before this refresh.

## Output

```
Doc refresh — PR "add subscription tier management"

Phase 1 (Understand): refresh after PR "add subscription tier management".
Phase 2 (Organize): classified — new module, new table, new dependency, new env vars.
Phase 3 (Retrieved): CLAUDE.md, all 7 universals, ai/modules.md + stack.md + architecture.md current state.
Phase 5 (Updated):
  - ai/status.md (prepended Recent Changes entry)
  - ai/modules.md (+1 row)
  - ai/stack.md (payment provider added)
  - ai/decisions/0007-*.md (new ADR)
Phase 6 (Validated):
  - Well-formed (floor): no placeholders, markdown renders, Updated: bumped. ✓
  - Drift gate (doc-drift-scan, regenerate→diff→cite): BROKEN=1, STALE=1.
  - Runnable-example gate: N/A (no doc touched this PR carries an executable block).
  - Link gate: 6/6 cross-refs resolve.
Phase 7 (Improved): drift log appended; /learn-from-task queued.

Files left untouched:
  - ai/architecture.md content (no architectural shift this PR)
  - ai/patterns/* (no new pattern)

Drift findings (cited, appended to ai/dynamic/drift-log.md):
  BROKEN 1. ai/architecture.md:47 references <modules-root>/auth/session/ —
           git log --diff-filter=R shows rename to <modules-root>/auth/jwt/ in def456a.
  STALE  1. ai/status.md Updated: was 42 days old (now bumped).

Required artifact (ai/dynamic/drift-log.md):
  refresh subscription-tiers — drift BROKEN=1 STALE=1 · examples N/A · links 6/6 · verdict INCOMPLETE

Status: INCOMPLETE
  Unmet (blocks PRODUCTION-GRADE): 1 BROKEN drift finding open (ai/architecture.md:47).
  To close: update that reference to <modules-root>/auth/jwt/ from code, re-run drift gate → 0 BROKEN.
```

(The floor-only report — "✅ complete, markdown renders" — would have certified this same doc set green with the `auth/session/` lie still live. The gate is what turns that into an honest `INCOMPLETE` naming the one thing left.)

## Rules

- `Updated:` line always bumped to today.
- `## Recent Changes` new entry PREPENDED, never appended.
- NEVER delete prior Recent Changes entries.
- Drift findings reported, not silently fixed (user may need to know).
- No speculative docs — reality only.
- Markdown validity checked (tables, code blocks, links) — but that is the FLOOR, not the verdict.
- **Never `PRODUCTION-GRADE` with an open `BROKEN` drift finding.** The verdict is computed from the drift/example/link counts, not narrated; a `BROKEN` count > 0 forces `INCOMPLETE` with the finding named.
- **The `ai/dynamic/drift-log.md` verdict line is the artifact of record.** Its `verdict` must agree with its own `BROKEN`/examples/links counts; a contradiction means the refresh did not close.

## Related

### Sibling commands in documentation pack
- `/add-adr` — sibling command in documentation pack

### Patterns
- `ai/patterns/adr-template.md`
- `ai/patterns/slo.md`
- `ai/patterns/system-design.md`

### Rules
- `.claude/rules/doc-principles.md`
