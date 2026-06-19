---
description: Comprehensive post-work documentation refresh. Prepends Recent Changes entry, updates modules / stack / conventions if they changed, runs drift detection, writes ADRs / patterns / runbooks as discovered, and flags stale docs.
kind: command
pack: documentation
---

# /doc-refresh

Run after EVERY significant change. Keeps `ai/` honest with reality. This command IS Phase 5 (Update) elevated to a standalone routine — it's the heavyweight version other commands invoke implicitly.

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
✅ Doc refresh complete

Phase 1 (Understand): refresh after PR "add subscription tier management".
Phase 2 (Organize): classified — new module, new table, new dependency, new env vars.
Phase 3 (Retrieved): CLAUDE.md, all 7 universals, ai/modules.md + stack.md + architecture.md current state.
Phase 5 (Updated):
  - ai/status.md (prepended Recent Changes entry)
  - ai/modules.md (+1 row)
  - ai/stack.md (Stripe added)
  - ai/decisions/0007-*.md (new ADR)
Phase 6 (Validated): no placeholders, markdown renders, Updated: bumped.
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

Status: COMPLETE
```

## Rules

- `Updated:` line always bumped to today.
- `## Recent Changes` new entry PREPENDED, never appended.
- NEVER delete prior Recent Changes entries.
- Drift findings reported, not silently fixed (user may need to know).
- No speculative docs — reality only.
- Markdown validity checked (tables, code blocks, links).
