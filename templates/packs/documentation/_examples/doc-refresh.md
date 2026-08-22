---
description: Comprehensive post-work documentation refresh. Prepends Recent Changes entry, updates modules / stack / conventions if they changed, runs drift detection, writes ADRs / patterns / runbooks as discovered, and flags stale docs.
kind: command
pack: documentation
---

# /doc-refresh

Run after EVERY significant change. Keeps `ai/` honest with reality. This command IS Phase 5 (Update) elevated to a standalone routine — it's the heavyweight version other commands invoke implicitly.

## The Premise (read this first, internalize, do not deviate)

**Existing docs are the truth, but code is the supreme truth.** Refresh = **re-derive from code; never invent**. If `ai/architecture.md` says the auth module lives at one path and the code says another, **docs lose**. The repair is to update docs to match code, not to lament the rename or to ADR-justify the doc state.

**The agent's job is exactly this:** walk `git log <base>..HEAD --stat` to find what changed; for each `ai/` file, **re-derive its content from current code/state** — modules from the filesystem, env vars from `.env.example`, scripts from the manifest, schema from migrations, endpoints from controllers; where docs and code disagree, **edit docs** (code wins, always); report drift findings rather than silently fixing anything the user may need to know about.

**The agent does NOT:** invent a section, pattern, ADR, or runbook with no code basis; edit `ai/architecture.md` to justify a doc/code mismatch with a "the system is being migrated" narrative; delete prior `Recent Changes` entries (always prepend); leave placeholders (`<TODO>`, `<name>`, `{{}}`) in any updated doc; or skip the cross-repo sweep — path references in `ai/` that no longer exist are silent rot.

**Mechanical halt — hand-wave grep + cite-or-halt (mandatory before the refresh is written):** grep your own doc edits and reject any new line that asserts a module / file / table / endpoint / env var that does not exist; that contains `<TODO>`, `<name>`, `{{}}`, `XXX`, `TBD`; that adds a pattern to `ai/patterns/` without 2+ code instances proving it is real and reusable; that adds a straw-man ADR alternative; or that re-states a doc claim the code-derivation step contradicts. Any line that fails the grep is **dropped or rewritten from code**, not softened. Drift findings are reported in `ai/dynamic/drift-log.md` with severity.

## The production bar — regenerate → diff → cite (declare PRODUCTION-GRADE or INCOMPLETE, never "a file got written")

**A doc file existing, free of placeholders, with tables that render is the FLOOR, not the finish.** Those checks prove the doc is *well-formed*; they say nothing about whether it is *true*. A beautifully-rendered `ai/stack.md` naming an env var deleted three commits ago is a well-formed lie. A refresh is PRODUCTION-GRADE only when the docs were **re-derived from current source and diffed against what's committed**, their runnable examples **actually ran**, and their cross-references **resolve** — each proven by a cited probe, not asserted.

**The four gates that separate FUNCTIONAL from PRODUCTION-GRADE (all wired, all cited):**

1. **Drift gate (regenerate → diff → cite).** Dispatch `doc-drift-scan`. It re-derives every doc claim from the source of truth (filesystem, manifest, `.env.example`, migrations, route table) and diffs it against the committed doc, emitting `BROKEN` / `STALE` findings with paired `<doc:line>` + `<src:line>` citations. **`BROKEN` > 0 ⇒ the doc set is STALE, not production-grade.** A pre-existing `BROKEN` finding elsewhere is reported and still blocks the verdict. If the skill is not installed, run the Phase 6 fallback and record the axis `UNVERIFIED (skill absent)` — never a silent green.
2. **Runnable-example gate.** Any touched doc carrying an executable path (setup / quickstart / copy-pasteable command sequence) is proven by dispatching `quickstart-verify` in a clean env. No runnable surface → `N/A`; couldn't execute → `SKIPPED (no clean env)`. A labelled skip, never a faked pass.
3. **Link-resolution gate.** Every `see ADR-NNNN`, runbook path, pattern cross-ref and relative path the refresh wrote resolves to a real file. One dangling reference ⇒ not production-grade.
4. **Non-prose gate — the surfaces prose checks cannot reach.** Two doc surfaces are not text and are therefore invisible to gates 1–3:
   - **The diagram.** If the refresh touched architecture, dispatch `diagram-sync` rather than eyeballing "did the picture change architecturally" — it diffs the committed diagram against `code-quality`'s `ai/optimize/_dep-graph.json` and emits `DIAGRAM-DRIFT (stale node / missing node)` + `LEVEL-MISMATCH` with citations. A box naming a module deleted last month is a `BROKEN` finding wearing a picture. Graph artifact absent → `diagram UNVERIFIED (no _dep-graph.json)`; never eyeball it green.
   - **The public-symbol surface.** If the refresh touched exported symbols, dispatch `docstring-coverage` and record coverage + PR delta. A doc set can be perfectly drift-free about the symbols it *mentions* while newly-exported ones are documented nowhere — drift-scan cannot see an absence.

**Terminal verdict.** After Phase 6 the run emits exactly one:
- `Status: PRODUCTION-GRADE` — **only** when drift `BROKEN` = 0, every runnable-example gate is `PASS`/`N/A`/`SKIPPED (no clean env)`, every link resolves, and the non-prose gate is `PASS`/`N/A` (a `DIAGRAM-DRIFT (stale node)` is a `BROKEN` finding in picture form and blocks the verdict exactly as a dead path does). The verdict line carries the cited counts so a reader can re-check it.
- `Status: INCOMPLETE` — the honest default whenever any gate fails or is `UNVERIFIED`. It **names every unmet item** and what would close it. Reporting `INCOMPLETE` with the list is a *success* of this command; reporting `COMPLETE` with an open `BROKEN` finding is the failure this gate exists to prevent.

**Required output artifact.** The verdict reads off the `ai/dynamic/drift-log.md` entry this run appends, which MUST record `refresh <scope> — drift BROKEN=<n> STALE=<n> · examples <PASS|N/A|SKIPPED|FAIL> · links <resolved>/<total> · diagram <PASS|n drift|N/A|UNVERIFIED> · docstrings <cov% Δ|N/A|UNVERIFIED> · verdict <PRODUCTION-GRADE|INCOMPLETE>` plus the cited findings. A verdict contradicting its own counts means the refresh did not close.

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

ALWAYS (the universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes (style + format reference).

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

**Dispatch the purpose-built `doc-drift-scan` skill** — it owns the full cross-check (file refs, package scripts, env vars, schema tables, ADR cross-refs, `Updated:` age, module-row drift) with rename-aware halts and glob-stripping the inline bash below does not have. Consume its `BROKEN` / `STALE` findings directly.

The inline bash below is a **fallback only** — run it when the skill is not installed (never skip the drift axis: a silent-clean sweep reads as "docs are honest" when they were never checked):

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

### Runnable-example, link + non-prose gates (the other three production-bar axes)

- For every touched doc with an executable setup/quickstart/command block, dispatch `quickstart-verify` in a clean env. Record `PASS` / `FAIL (step N)` / `N/A` / `SKIPPED (no clean env)` — never omit the axis.
- Resolve every cross-reference the refresh wrote. Record `links <resolved>/<total>`.
- If architecture was touched, dispatch `diagram-sync` (gate 4). Record `diagram PASS` / `<n> DIAGRAM-DRIFT` / `N/A` / `UNVERIFIED (no _dep-graph.json)`.
- If exported symbols were touched, dispatch `docstring-coverage` (gate 4). Record `docstrings <raw%> (Δ<PR delta>)` / `N/A` / `UNVERIFIED (skill absent)`.

### Terminal gate — compute the verdict from the cited counts, then write the artifact

Do not free-narrate "complete". Apply the rule from *The production bar*: `BROKEN` = 0 **and** every example gate ∈ {`PASS`,`N/A`,`SKIPPED (no clean env)`} **and** links fully resolve **and** the non-prose gate has no drift ⇒ `Status: PRODUCTION-GRADE`; otherwise `Status: INCOMPLETE`, naming each unmet item + what closes it. Append the machine-checkable line to `ai/dynamic/drift-log.md` with **every** field of the contract above — the diagram and docstring axes are part of the line, not optional: `refresh <scope> — drift BROKEN=<n> STALE=<n> · examples <…> · links <r>/<t> · diagram <…> · docstrings <…> · verdict <…>`.

## Phase 7 — Improve (feed the learning loop)

- If drift was found: append to `ai/dynamic/drift-log.md` with severity.
- If new pattern was promoted to formal `ai/patterns/`: also update `ai/dynamic/learned-patterns.md` (mark as PROMOTED).
- If ADR conflict surfaced: queue to `ai/dynamic/decisions-pending.md`.
- Run `/learn-from-task` if the refresh covered a substantial body of work.

## Example run

### Triggered by: PR "add subscription tier management"

```
git diff main..HEAD:
  + src/modules/subscriptions/ (new module — 14 files)
  + migrations/012-create-subscriptions-table.sql
  + src/modules/subscriptions/application/use-cases/*
  + locales/en.json: +8 keys (subscriptions.*)
  + locales/ar.json: +8 keys
  ~ src/app.module.ts: SubscriptionsModule added
  ~ package.json: +@stripe/stripe-node
  ~ .env.example: +STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET
```

### Documents updated

1. **ai/status.md** — prepended Recent Changes entry:
```
### Subscription tier management (P2 start)
- What changed: added /subscriptions module (CRUD + Stripe sync), `subscriptions` table, 3-tier plan (trial/starter/pro).
- Why: kicks off Phase 2 monetization per ai/runbooks/phase-2-plan.md.
- How:
  - Schema: `subscriptions(tenant_id, plan, started_at, expires_at, stripe_subscription_id)` with CHECK on plan enum.
  - Service: `SubscriptionService` wraps Stripe customer + subscription APIs.
  - Webhook: `customer.subscription.updated` → state sync.
  - ADR 0007 records plan-change migration strategy.
- Follow-ups:
  - Usage meter (ticket BILLING-42).
  - Plan-based hard limits (BILLING-19).
  - Admin UI for plan management (P3).
```

2. **ai/modules.md** — new row:
```
| subscriptions | src/modules/subscriptions | Stripe-synced subscription tier management | P2 |
```

3. **ai/stack.md** — added:
```
- Payments: Stripe via @stripe/stripe-node
- Env: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET
```

4. **ai/decisions/0007-subscription-plan-migration-strategy.md** — new ADR.

5. **ai/patterns/** — no new pattern this PR (flag for later if multiple billing features emerge that share a shape).

### Drift found

- `ai/architecture.md` references `src/modules/auth/session/` which was renamed to `src/modules/auth/jwt/` in a prior PR. 
  → Fix: update reference. (Separate mini-PR or include.)

- `ai/status.md` `Updated:` was 42 days old before this refresh.

## Output

```
Doc refresh — <scope>

Phase 1 (Understand): refresh after PR "add subscription tier management".
Phase 2 (Organize): classified — new module, new table, new dependency, new env vars.
Phase 3 (Retrieved): CLAUDE.md, all 7 universals, ai/modules.md + stack.md + architecture.md current state.
Phase 5 (Updated):
  - ai/status.md (prepended Recent Changes entry)
  - ai/modules.md (+1 row)
  - ai/stack.md (Stripe added)
  - ai/decisions/0007-*.md (new ADR)
Phase 6 (Validated): drift BROKEN=1 STALE=0; examples N/A; links 6/6; diagram N/A (architecture untouched); docstrings 71% raw (Δ −4%: 3 new exports, 0 documented).
Phase 7 (Improved): drift log appended (1 finding); /learn-from-task queued.

Files left untouched:
  - ai/architecture.md (no architectural shift this PR)
  - ai/patterns/* (no new pattern)

Drift detected (flag separately, appended to ai/dynamic/drift-log.md):
  1. ai/architecture.md references src/modules/auth/session/ — renamed to src/modules/auth/jwt/.

Recommended follow-ups:
  - Fix the drift finding (mini-PR).
  - Consider extracting billing patterns to ai/patterns/billing.md once we have 2+ flows.

Updated: 2026-05-02 (was 2026-03-21 — 42 days old)

Production bar: drift BROKEN=1 STALE=0 · examples N/A · links 6/6 · diagram N/A · docstrings 71% (Δ−4%) · verdict INCOMPLETE
Status: INCOMPLETE — 1 BROKEN drift finding (ai/architecture.md:47 → renamed path).
        To reach PRODUCTION-GRADE: update that reference from code. Logged to ai/dynamic/drift-log.md.
```

## Rules

- `Updated:` line always bumped to today.
- `## Recent Changes` new entry PREPENDED, never appended.
- NEVER delete prior Recent Changes entries.
- Drift findings reported, not silently fixed (user may need to know).
- No speculative docs — reality only.
- Markdown validity checked (tables, code blocks, links).
