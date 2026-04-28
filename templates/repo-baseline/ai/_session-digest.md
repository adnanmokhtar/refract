# Session digest

Auto-maintained compact bootstrap context. Loaded at every session-start. **Read this before anything else.**

Last updated: <YYYY-MM-DD by knowledge-curator>

---

## Project (one-screen orientation)

- **Name**: <project-name>
- **Mission**: <one sentence from ai/project-goals.md>
- **Domain**: <ecommerce | lms | fintech | ...>  · **Stage**: <P1 MVP | P2 monetization | scale | mature>
- **Primary user**: <persona from ai/users-and-personas.md>
- **Stack**: <one-line list — backend / frontend / DB / queue / AI provider>

## Architecture (one-line shape)

<one-line summary derived from `.claude/codebase-profile.md` § Architecture — actual layering style + real frameworks + real signal set (multi-tenant if detected, etc.)>

## Top conventions (the 5 you'll violate first if you don't read them)

> All five below are placeholders. Filled at setup time from `ai/_convention-cheatsheet.md` for THIS project. Never copy concrete rule bodies from another project's `_session-digest.md`.

1. <Convention 1 — derived from this project's extraction>
2. <Convention 2>
3. <Convention 3>
4. <Convention 4>
5. <Convention 5>

Full conventions: `ai/conventions.md` · Cheat sheet: `ai/_convention-cheatsheet.md`

## Last 3 decisions (with link)

1. **ADR-NNNN** <YYYY-MM-DD>: <one-line decision>
2. **ADR-NNNN** <YYYY-MM-DD>: <one-line decision>
3. **ADR-NNNN** <YYYY-MM-DD>: <one-line decision>

Decision index: `ai/_decision-index.md` · Pending: `ai/dynamic/decisions-pending.md`

## Top 3 active follow-ups (carried from prior sessions)

1. <follow-up — owner — deadline> (from `ai/dynamic/interaction-log.md`)
2. <follow-up>
3. <follow-up>

## Top 3 user corrections to NEVER repeat

> Corrections accumulate as the project evolves. Filled in by `knowledge-curator` from `ai/dynamic/feedback-learned.md` — leave placeholder until real corrections exist.

1. <correction text from feedback-learned.md> (corrected N×)
2. <correction text>
3. <correction text>

Full feedback: `ai/dynamic/feedback-learned.md`

## In-flight phase (current focus)

<e.g., "Phase 2 — Monetization. Day 4 of 7-day plan. Just finished: usage-tracking endpoints. Next: cost-calculator + margin-applier. See `ai/runbooks/phase-2-monetization-plan.md`.">

## Patterns currently emerging (watching, not yet formal)

- <pattern-name> (N occurrences) → may promote to `ai/patterns/<name>.md` after 3+
- <pattern-name>

Watch list: `ai/dynamic/learned-patterns.md`

## Drift findings (high severity, OPEN)

<count> high-severity entries in `ai/dynamic/drift-log.md`. Resolve before next release.

## Tier 2 / 3 reading (load on demand by task type)

- **Code edit on backend** → `ai/conventions.md` + `.claude/rules/<relevant>.md` + the existing module file
- **New feature** → `ai/business-domain.md` + `ai/business-flows.md` + `ai/runbooks/phase-<current>-plan.md`
- **Architecture decision** → `ai/_decision-index.md` (then drill into specific ADR if relevant)
- **Bug fix** → `ai/runtime/context.md` + `ai/dynamic/drift-log.md` + relevant `ai/patterns/`
- **Audit / review** → full `ai/decisions/` + `ai/conventions.md` + `.claude/rules/`

---

**This file is auto-maintained.** Don't hand-edit — your changes will be overwritten on next `knowledge-curator` run. To update: change the source file (status.md, decisions/, conventions.md, etc.) and run `/audit-knowledge` to regenerate.
