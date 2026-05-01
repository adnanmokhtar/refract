Updated: <YYYY-MM-DD>

# Project Status

The "what's happening RIGHT NOW" file. Updated on every significant change. Read by `_session-digest.md` regen + every agent's pre-flight (Tier 2 — feature work / planning).

> **Hard rule A06**: this file MUST have an `Updated:` line at the top AND a `## Recent Changes` section. Phase 5 verification halts if either is missing.

---

## Overview

<one paragraph: what this product does, who uses it, what current phase / maturity stage it is in>

- **Domain**: <ecommerce / lms / fintech / healthcare / saas-b2b / ...>
- **Stage**: <idea | prototype | MVP | paying customers | scale | mature | sunsetting>
- **Phase / sprint**: <e.g., "Phase 2 — Monetization, Day 4 of 7-day plan">

## In-flight work

What the team is actively building / fixing right now. Each item links to where the work is tracked.

- <task — link to PR / issue / ADR / runbook>
- <task — link>

## Recently shipped (last 30 days)

- <YYYY-MM-DD> — <feature / fix> — <one line>
- <YYYY-MM-DD> — <feature / fix> — <one line>

## Up next (next 30 days)

What's planned but not yet started. Cross-link `ai/runbooks/phase-<N>-plan.md` if the plan exists.

- <next task>
- <next task>

## Tech debt / known issues

Things the team agrees should get fixed but aren't blocking right now. Promote a row to `In-flight work` when work starts.

- <item — owner — rough effort — impact>

## Open architectural decisions

Decisions waiting to be made. Cross-link `ai/dynamic/decisions-pending.md`.

- <pending decision — what's blocking>

## Recent Changes (<YYYY-MM-DD>)

### <Change title>

- **What changed**: <one paragraph>
- **Why it changed**: <one paragraph or ADR link>
- **Migration path** (if breaking): <how callers / consumers update>
- **Follow-ups left**: <link to next ADR / TODO / issue>

(Add a new `### <Change title>` block per significant change. Old entries scroll down; the file is allowed to grow until ~300 lines, at which point the curator archives older entries to `ai/dynamic/changelog.md`.)

---

## Update cadence (when to touch this file)

| Trigger | What to update |
|---|---|
| New feature work starts | Add to `In-flight work` |
| Feature ships | Move to `Recently shipped`; add `Recent Changes` block if non-trivial |
| ADR is merged | Add link in `Recent Changes`; if it changed status quo, note in `Overview` |
| Major dependency upgrade | `Recent Changes` block + tech-debt entry if migration is in flight |
| Phase / sprint transition | Update `Overview § Phase` + `Up next` |
| Incident postmortem | Note in `Recent Changes` + cross-link `ai/failures/<NNNN>.md` |

`/setup-project --refresh` regenerates the `Updated:` line and the file's structural anchors but PRESERVES every existing `### <Change title>` block (append-only; never rewrite history).

## See also

- `ai/_session-digest.md` — derives "current phase" + "in-flight" lines from this file
- `ai/runbooks/phase-<N>-plan.md` — the day-by-day plan for the current phase
- `ai/decisions/` — every ADR; this file just summarizes; full reasoning is there
- `ai/dynamic/changelog.md` — the long-term changelog (older `Recent Changes` entries archive here)
- `ai/dynamic/decisions-pending.md` — open architectural decisions
