---
description: Re-runs Phase 2 codebase profiling, diffs against current ai/conventions.md + .claude/codebase-profile.md, updates files on confirmation.
---

# /refresh-knowledge

Use after major refactors, dependency upgrades, architectural shifts, or quarterly. Catches drift between documented project knowledge and reality.

## Phases applied

MAINTAIN type — 1, 3, 5, 6. Phase 4 here = building the new profile + diff (no code changes); Phase 5 = updating the knowledge layer itself (this command's reason for existing).

## When to use / NOT to use
- USE: quarterly housekeeping; after a major refactor (>20 files touched); after upgrading framework / DB / major dependency; when `convention-drift-detector` shows >5 findings; when new modules with novel patterns have shipped.
- NOT: mid-feature work; fresh after `/setup-project` (nothing has changed yet); dirty working tree (commit/stash first; rerun cleanly).

## Phase 1 — Understand

- Confirm clean tree (`git status --porcelain` empty); refuse if dirty.
- Confirm baseline files exist (`.claude/codebase-profile.md`, `ai/conventions.md`); if absent, this is `/setup-project`'s Phase 2 territory.
- Record commit hash anchor: `git rev-parse HEAD`.
- Success: categorized diff (ADDED / CHANGED / REMOVED) shown to user; on confirmation, knowledge layer updated; user-edited sections preserved below idempotency markers.

## Phase 2 — Organize

- Sub-tasks: re-run detection → build new profile → diff → categorize → propose updates → apply on confirmation.
- `--dry-run`: stop after categorized diff (no writes).

## Phase 3 — Retrieve (re-detect everything)

Re-run Phase 2 detection from `/setup-project`:
- Run all Appendix A detection commands fresh (package manager, framework, DB, multi-tenancy, business signals).
- Walk one full module per layer (controller → service → repo → entity → test).
- Detect business-domain signals fresh.

Read for diff:
- Current `.claude/codebase-profile.md`.
- Current `ai/conventions.md` (auto-populated section above marker only).
- Current `ai/modules.md`, `ai/stack.md`, `ai/business-domain.md`.

## Phase 4 — Generate (new profile + categorized diff)

- Build NEW profile in `.claude/codebase-profile.md.new`.
- Diff: `diff -u .claude/codebase-profile.md .claude/codebase-profile.md.new`.
- Categorize each diff:
  - `ADDED` — new entity / pattern / module / dependency.
  - `CHANGED` — base class moved, suffix convention shifted, layer renamed.
  - `REMOVED` — module deleted, dependency dropped, pattern abandoned.
- Per category, propose update target:
  - ADDED → may require `learned-patterns.md`, `glossary` entry, new ADR.
  - CHANGED → update `ai/conventions.md` + relevant rule + `interaction-log.md`.
  - REMOVED → archive references; may invalidate ADR (write superseding ADR).
- Show categorized diff in plan form; pause for confirmation (unless `--dry-run`).

## Phase 5 — Update (the knowledge layer — this command's purpose)

On confirmation:
- Replace `.claude/codebase-profile.md` with `.codebase-profile.md.new`.
- Update `ai/conventions.md` auto-populated sections ABOVE the idempotency marker; preserve user edits BELOW.
- Append to `ai/dynamic/changelog.md` summarizing the refresh.
- Add entries to `ai/dynamic/learned-patterns.md` for newly-emerged patterns.
- Add entries to `ai/dynamic/decisions-pending.md` for changes requiring human decision.
- Prepend "Knowledge refresh on YYYY-MM-DD" to `ai/status.md` Recent Changes.
- Update `ai/modules.md` rows for ADDED/REMOVED modules.
- Update `ai/stack.md` for dependency changes.

## Phase 6 — Validate

- Re-read `ai/conventions.md` after write — confirm idempotency marker present, user content below preserved.
- Spot-check one ADDED entity / one CHANGED suffix against actual files (no phantom updates).
- Confirm `ai/status.md` `Updated:` line is the new date.
- Self-audit: did the diff include items already in `learned-patterns.md` or `decisions-pending.md`? Don't double-queue.
- Run `/detect-drift` next — if findings drop sharply, the refresh worked; if they don't, conventions are too generic.

## Phase 7 — Improve

- If certain detection patterns are noisy (vendored code, generated files), persist exclusion list in `.claude/refresh-ignore.txt`.
- If quarterly refresh keeps surfacing the same CHANGED items, the auto-detector is stale — queue improvement to `/setup-project` Phase 2.
- If the same dependency upgrade triggers refresh > 1× per quarter, queue automation (CI dependabot + auto-refresh) to `ai/dynamic/decisions-pending.md`.

## Output

```
## /refresh-knowledge — diff against last profile (<old commit hash> -> <new commit hash>)

### Profile changes (12 detected)

ADDED:
- Entity `Subscription` (8 references in src/modules/billing/) — propose to `ai/core/glossary.md`
- New base class `EventSubscriber` at libs/events/src/base/event-subscriber.ts (4 extenders) — propose to conventions
- Dependency `bullmq@5.30` — propose to stack.md + propose `background-jobs` domain tooling

CHANGED:
- Controller suffix matrix expanded: now also `.gateway.ts` for WebSocket controllers (12 instances)
- DI tokens shifted from string constants to Symbol() (4 modules: orders, billing, subscriptions, notifications)

REMOVED:
- Module `legacy-auth/` (deleted in commit abc123) — archive references in conventions, ADR-0008 affected

### Suggested actions
1. Update `ai/conventions.md` suffix matrix to include `.gateway.ts`.
2. Write ADR for "DI tokens: Symbol over string" if intentional.
3. Append `Subscription` entity to glossary.
4. Trigger background-jobs domain tooling generation.
5. Write superseding ADR if ADR-0008 was about legacy-auth.

Apply now? [y/n]
```

## Failure modes

- Refresh on dirty tree — confusing diff; refuse + ask to commit/stash first.
- Refresh too soon after setup — no meaningful changes; report and exit.
- Detected change is actually noise (generated code, vendored lib) — allow user to mark categories as "ignore" persistently in `.claude/refresh-ignore.txt`.
- Existing user edits in conventions.md below the marker — preserve them; only update auto-populated sections.
- Auto-applied updates without confirmation — never; always pause unless `--dry-run`.

## See also

- `/setup-project` Phase 2 — original profiling.
- `/detect-drift` — narrower check (conventions vs code only).
- `ai/dynamic/learned-patterns.md`, `ai/dynamic/decisions-pending.md`, `ai/dynamic/changelog.md`.
