---
description: Re-runs the canonical extraction engine (extract-codebase-overview -> _extracted-codebase.md, chaining extract-business-context), diffs the new oracle against the old, and updates .claude/codebase-profile.md + ai/ on confirmation. Knowledge layer only - pack re-apply is /setup-project --refresh.
---

# /refresh-knowledge

Use after major refactors, dependency upgrades, architectural shifts, or quarterly. Catches drift between documented project knowledge and reality.

## The Premise (read this first, internalize, do not deviate)

**Codebase is the truth. Refresh = re-derive from source; never carry forward stale memory.** The `.claude/codebase-profile.md` and `ai/conventions.md` files are caches of a prior detection run — by definition, they are behind. The repository as it sits at `git rev-parse HEAD` is the only authoritative description of itself.

**The rule when source and digest disagree:**

> **If source says X and old digest says Y, source wins.** Always. Without prompting the user. The digest gets rewritten to match source — never the other way around.

**The agent's job is exactly this:**
1. Re-detect everything from scratch (Phase 3) — pretend the existing profile does not exist while building the new one.
2. Diff new-profile against old-profile and categorize ADDED / CHANGED / REMOVED (Phase 4).
3. On confirmation, **overwrite** the digest with source-derived facts (Phase 5). User-edited sections below idempotency markers are preserved; auto-populated sections are replaced wholesale.

**The agent does NOT:**
- Ask "did you mean to remove module X?" when the module is gone from source. If source removed it, it's gone — record REMOVED, archive references, move on.
- Preserve a "CHANGED" digest entry because "the old description was nicer." The new description IS the new truth.
- Refuse to overwrite a convention rule because the user might have liked it. User edits live BELOW the marker; auto-populated lines ABOVE the marker are not user-owned.
- Treat the existing profile as a tiebreaker when the new detection is ambiguous. Re-run detection on a narrower scope, or surface as REMOVED + open question — never default to old.

**The agent ONLY pauses when:**
- Diff is empty (nothing to refresh; report and exit cleanly).
- Idempotency marker is missing or moved (Phase 6 validate; user resolves marker placement before write).
- Working tree is dirty (Phase 1 refusal — commit/stash first; refresh on dirty tree mixes uncommitted noise into "reality").

That's it. Three pause triggers. Everything else is silent source-wins overwrites of auto-populated digest sections.

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

## Phase 3 — Re-extract (invoke the engine; do NOT hand-walk)

> **Hard rule — the oracle is re-derived, not re-asserted.** This phase MUST invoke the
> `extract-codebase-overview` skill and MUST rewrite `.claude/_extracted-codebase.md`. A run that
> updates `codebase-profile.md` / `ai/conventions.md` while leaving the oracle at its old bytes
> produces the exact artefact this command exists to destroy: a knowledge layer stamped with
> today's date over a codebase read at some earlier commit. It is worse than not running, because
> the fresh timestamp reads as evidence.

1. **Re-derive repo shape** (`repo_shape`, `shape_signal`, `members` — one entry per member with
   `name` / `root` / `manifest`, `(none)` being legal) from disk, exactly as `/setup-project`
   Phase 1 does. Do NOT read it out of `.claude/codebase-profile.md § 17`: a member added or
   removed since the last run is one of the changes this command exists to catch, and a cached
   member list cannot show it. A shape that differs from § 17 is itself a `CHANGED` diff entry.
2. **Invoke `extract-codebase-overview`** with those three inputs (all three are `required` in
   that skill's `## Inputs`; an absent `members` halts there with `[SHAPE-INPUT-MISSING]` rather
   than defaulting to `single`). Write to `.claude/_extracted-codebase.md`. The skill runs its own
   Step 2.5 census, its per-section `[SAMPLED: <seen>/<present> <unit>]` markers, its Step 8
   `[CONTESTED: <A> n/N, <B> m/N]` rows and its Step 15 check 7 — none of which a hand-walk
   produces. It chains `extract-business-context` at its Step 13, so `.claude/_extracted-business.md`
   refreshes in the same pass.
3. **Preserve the approval stamp, never re-stamp.** Copy the existing `approved_by:` /
   `approved_hash:` lines into the new oracle **verbatim**. The body changes, so the hash no longer
   matches — that mismatch is the point: `/setup-project-health` check 9 then reports "oracle
   changed since approval by \<name\>@\<date\>" and a human re-reads before audits build on it.
   Auto-restamping here silently certifies an oracle nobody has read
   (`templates/phases/phase-2-profile.md § Oracle approval`).
4. **Invoke `extract-base-class-idiom`** per load-bearing unit found in the new oracle's
   `## Base classes` and rewrite `.claude/_extracted-idioms.md` — same stamp-preservation rule.
   Skip only when the new oracle records no unit with ≥3 dependents.

Read for diff (prior state — read AFTER the new extraction is written, so nothing stale leaks into it):
- Prior `.claude/_extracted-codebase.md` (git: `git show HEAD:.claude/_extracted-codebase.md`, or the
  pre-write in-memory copy) — the oracle-vs-oracle diff is the substantive one.
- Current `.claude/codebase-profile.md`.
- Current `ai/conventions.md` (auto-populated section above marker only).
- Current `ai/modules.md`, `ai/stack.md`, `ai/business-domain.md`.

**What this command is NOT.** It refreshes the *knowledge layer* — oracle, profile, `ai/`. It does
NOT re-select packs, re-apply pack artifacts, re-anchor `## Project-specific` blocks, or re-run
adapters. That is `/setup-project --refresh` (`phase-2-profile.md § Mode behavior`: "In REFRESH
mode: orchestrator runs ALL 15 steps" plus Phases 3-5). Reach for `--refresh` when the *stack* moved;
reach for this when the *code* moved under a stack that did not.

## Phase 4 — Generate (new profile + categorized diff)

- Build NEW profile in `.claude/codebase-profile.md.new` **from the oracle Phase 3 just wrote** —
  the five machine-parsed headings (`Architecture`, `Naming`, `Testing`, `Data access`,
  `Error handling`) come from `_extracted-codebase.md`, not from a second independent read. Two
  reads of the same repo that disagree is a bug with no owner.
- Diff: `diff -u .claude/codebase-profile.md .claude/codebase-profile.md.new`.
- **Diff the oracle too** — `diff -u <prior _extracted-codebase.md> .claude/_extracted-codebase.md`.
  Three of its deltas are reportable in their own right and are invisible in the profile diff:
  - **Coverage delta** — `## Coverage` `<seen>/<present>` this run vs last, per member. Coverage
    that *fell* while the repo grew means the walk is now thinner, not that the project got simpler;
    report it as `CHANGED` even when no section text moved.
  - **Provenance delta** — the `[found:] / [inferred:] / [unconfirmed]` counts. A claim that moved
    `[found:] → [inferred:]` is a fact that stopped being verifiable, and it is a refresh finding.
  - **`[CONTESTED]` rows appearing or clearing** — a category that split since the last run is
    `ADDED` (a convention became unsettled); one that resolved to unanimous is `REMOVED`.
- Categorize each diff:
  - `ADDED` — new entity / pattern / module / dependency.
  - `CHANGED` — base class moved, suffix convention shifted, layer renamed.
  - `REMOVED` — module deleted, dependency dropped, pattern abandoned.
- Per category, propose update target:
  - ADDED → may require `learned-patterns.md`, `glossary` entry, new ADR.
  - CHANGED → update `ai/conventions.md` + relevant rule + `interaction-log.md`.
  - REMOVED → archive references; may invalidate ADR (write superseding ADR).
- **A newly-`[CONTESTED]` category is never proposed as a convention update.** It goes to
  `ai/conventions.md § Unsettled conventions` with both options + counts + a citation each
  (`templates/phases/phase-4.7-deep.md § Unsettled conventions` defines the row shape), and to
  `ai/dynamic/decisions-pending.md` as "pick one or accept the split". Writing the 60% side into
  the auto-populated section is the averaging bug: it hands the next agent a rule that is wrong for
  40% of the files, with a citation that resolves.
- Show categorized diff in plan form; pause for confirmation (unless `--dry-run`).

### Mechanical halt — source-vs-digest conflict

**Refuse to advance to Phase 5 if any diff entry is unresolved (verb missing, both-sides marked authoritative, or auto-resolution would silently keep digest text).** Cite both sides; pick source. The halt log MUST include:

```
## /refresh-knowledge halt — source-vs-digest conflict on <key>
Source (HEAD <new-sha>): <fact derived from re-detection>
Digest (cached at <old-sha>): <stale fact still in the file>
Resolution: source wins (digest will be overwritten on confirm).
Reason for halt: <verb-missing | marker-shadowed | scope-ambiguous>
```

The halt prints, the user reads, the user types `y` — then Phase 5 overwrites the digest with the source-derived line. There is no "keep digest" branch. If the user genuinely wants the digest text kept, they move it BELOW the idempotency marker (where it becomes a user edit) and re-run; the auto-populated section above the marker is always source-derived.

**Self-policed (no external validator):** there is no `check_source_wins_resolution` function — the agent itself, in Phase 6, re-reads the halt log and confirms each cited conflict was closed by overwriting the digest, not by reverting the source-derived line. Reverting source loses the refresh; that is the exact failure mode this halt prevents. If any cited conflict shows the digest text surviving above the marker, the refresh is incomplete — redo Phase 5 for that key.

## Phase 5 — Update (the knowledge layer — this command's purpose)

On confirmation:
- Replace `.claude/codebase-profile.md` with `.claude/codebase-profile.md.new` (the file Phase 4 actually wrote), then remove the `.new` scratch file.
- Update `ai/conventions.md` auto-populated sections ABOVE the idempotency marker; preserve user edits BELOW.
- Append to `ai/dynamic/changelog.md` summarizing the refresh.
- Dispatch `pattern-emergence-watcher` over the ADDED/CHANGED set and let IT write
  `ai/dynamic/learned-patterns.md`. Do not author pattern entries inline: the agent owns the
  Rule-of-Three floor, the stack-default exclusion and the `WATCHING` status, and an entry
  written here bypasses all three — which is how `learned-patterns.md` fills with framework
  defaults nobody will ever promote.
- Add entries to `ai/dynamic/decisions-pending.md` for changes requiring human decision.
- Prepend "Knowledge refresh on YYYY-MM-DD" to `ai/status.md` Recent Changes.
- Update `ai/modules.md` rows for ADDED/REMOVED modules.
- Update `ai/stack.md` for dependency changes.
- Update `ai/conventions.md § Unsettled conventions` from the new oracle's `[CONTESTED]` rows —
  add rows that appeared, drop rows whose category is now unanimous. A category may appear there
  OR as a settled rule, never both.

## Phase 6 — Validate

- **Oracle actually moved** — `.claude/_extracted-codebase.md` mtime is this run AND its
  `Coverage:` / census `<short-sha>` names the commit recorded in Phase 1. An unchanged oracle after
  a non-empty diff means Phase 3 was skipped and every other check below is measuring stale input.
- **Approval stamp preserved, not re-issued** — `approved_by:` is byte-identical to its pre-run
  value. If it changed, the run auto-certified an oracle no human re-read; restore the old value.
- Re-read `ai/conventions.md` after write — confirm idempotency marker present, user content below preserved.
- Spot-check one ADDED entity / one CHANGED suffix against actual files (no phantom updates).
- Confirm `ai/status.md` `Updated:` line is the new date.
- Self-audit: did the diff include items already in `learned-patterns.md` or `decisions-pending.md`? Don't double-queue.
- Source-wins self-check (no external validator): for each conflict in the halt log, confirm the digest line was overwritten with the source-derived fact above the marker — not reverted. A surviving stale digest line above the marker means the refresh is incomplete; redo Phase 5 for that key.
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
- Entity `Subscription` (8 references in <modules-root>/billing/) — propose to `ai/core/glossary.md`
- New base class `EventSubscriber` at <libs-root>/events/base/event-subscriber.<ext> (4 extenders) — propose to conventions
- Dependency `<background-jobs-library>@<version>` — propose to stack.md + propose `background-jobs` domain tooling

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

- `/setup-project --refresh` — the *wider* command: re-selects packs, re-applies artifacts, re-anchors, re-syncs adapters. Use it when the stack itself moved.
- `extract-codebase-overview` · `extract-business-context` · `extract-base-class-idiom` — the skills this command invokes.
- `/detect-drift` — narrower check (conventions vs code only).
- `ai/dynamic/learned-patterns.md`, `ai/dynamic/decisions-pending.md`, `ai/dynamic/changelog.md`.

## Related

### Sibling commands in learning pack
- `/detect-drift` — sibling command in learning pack
- `/learn-from-task` — sibling command in learning pack
- `/promote-pattern` — sibling command in learning pack

### Patterns
- `ai/patterns/setup-quality-scoring.md`
