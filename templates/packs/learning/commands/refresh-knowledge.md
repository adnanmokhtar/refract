---
description: "Re-derive the oracle and profile from source, or close /audit-knowledge findings failing first (--from-audit)."
kind: command
pack: learning
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task, Skill]
---

# /refresh-knowledge [--dry-run] [--from-audit=<report> | <finding-id> … | --all]

| Mode | What it does | Writes |
|---|---|---|
| **default** (re-extract) | Re-runs the extraction engine, diffs the new oracle against the old one, rewrites `.claude/codebase-profile.md` and `ai/` on confirmation, then re-anchors the profile facets of every installed artifact | the oracle, the profile, `ai/` sections above idempotency markers, anchor facet lines (through `apply-anchors.sh`) |
| **`--from-audit=<report>`** | Closes the findings an `/audit-knowledge` report lists, one at a time: the owning engine fires on the site first, the fix lands at the source or the generator, the engine is quiet after, derived files regenerate byte-identically twice | knowledge paths only (§ Edit scope), the run ledger `ai/runs/<date>-knowledge-fix-<4hex>/`, the fix report `ai/audits/<date>-knowledge-fix.md` |

Use the default after major refactors, dependency upgrades, architectural shifts, or quarterly. Use `--from-audit` after `/audit-knowledge` returns `KNOWLEDGE-STALE` or `UNVERIFIED`.

## The Premise (read this first, internalize, do not deviate)

**Codebase is the truth. Refresh = re-derive from source; never carry forward stale memory.** `.claude/codebase-profile.md`, `ai/conventions.md`, the derived files and every anchor block are caches of an earlier read. The repository at `git rev-parse HEAD` — its files, its lockfile, its history — is the only authoritative description of itself.

**The rule when source and knowledge disagree:**

> **If source says X and the knowledge says Y, source wins.** Always. Without prompting the user. The knowledge is rewritten to match the source, never the other way around. The one exception is a *decision*: an Accepted ADR whose chosen option the code no longer has is put to the user (a superseding ADR, or the code change), never rewritten to bless the code.

**A fix is closed when the engine that found it is quiet on that site, for every site of its root cause. Proven, not asserted.** The `--from-audit` input is the `## What to do next` list an `/audit-knowledge` run wrote. This command does not discover defects and does not fix guesses: it turns a reported row into a reproduced one, closes it at the source or the generator, and re-runs the owning engine until it goes quiet.

**The agent does NOT:**
- Ask "did you mean to remove module X?" when the module is gone from source. If source removed it, it is gone: record REMOVED, repoint or delete the references, move on.
- Keep a stale line because "the old description was nicer", or treat the existing profile as a tiebreaker. Re-run detection on a narrower scope, or surface an open question — never default to old.
- **Hand-edit a derived file.** Anchor blocks, `_decision-index.md`, `_convention-cheatsheet.md` and `_session-digest.md` are regenerated from their sources (`apply-anchors.sh`, `@knowledge-curator` § 8). 177 copies of one stale bullet close with one regeneration, not 177 edits.
- **Delete a record.** A memory entry is marked `RESOLVED → <sha>` or `SUPERSEDED` with a reason; a duplicate is merged keeping both citations; an ADR is superseded or amended (precedents § 13, § 17; curator invariant "archive, don't delete").
- Edit code, a manifest, a lockfile or a test to make a knowledge claim true. The code is the truth; a lesson that should become a lint rule or test is handed off (KN-26).
- Fix a row the engine does not reproduce: it is `not reproduced`, and the tree is left alone.

**The agent ONLY pauses when:**
- the diff (default) or the finding set (`--from-audit`) is empty: report and exit cleanly;
- an idempotency marker is missing or moved, or `apply-anchors.sh` reports `MARKER-CORRUPT` (the user places the marker before any write);
- the working tree is dirty (commit or stash first; a refresh on a dirty tree mixes uncommitted noise into "reality");
- a row crosses a STOP line (§ `--from-audit`).

## Phases applied

MAINTAIN type — 1, 3, 4, 5, 6. Phase 4 builds the new profile and diff (default) or runs the per-finding loop (`--from-audit`); Phase 5 updates the knowledge layer itself, this command's reason for existing.

## When to use / NOT to use
- USE (default): quarterly housekeeping; after a major refactor (>20 files touched); after a framework, database or major dependency upgrade; when `/audit-knowledge` reports KN-19 (oracle older than the code) or a KN-07/KN-13 root cause in the profile.
- USE (`--from-audit`): to close the `## What to do next` list of `ai/audits/<date>-knowledge.md`; a finding id (`/refresh-knowledge K-04`); `--all` to work MUST → SHOULD → OPTIONAL.
- NOT: mid-feature work; right after `/setup-project` (nothing changed yet); a dirty tree. Re-selecting packs, re-applying pack artifacts or re-syncing adapters is `/setup-project --refresh` — reach for it when the *stack* moved; reach for this when the *code* moved under a stack that did not.

## Phase 1 — Understand

- Confirm clean tree (`git status --porcelain` empty); refuse if dirty.
- Record the anchor commit: `git rev-parse HEAD`.
- **Default:** confirm the baseline files exist (`.claude/codebase-profile.md`, `ai/conventions.md`); if absent, this is `/setup-project`'s Phase 2 territory. Success: a categorized diff (ADDED / CHANGED / REMOVED) shown to the user; on confirmation, the knowledge layer updated and re-anchored; user-edited sections preserved below idempotency markers.
- **`--from-audit`:** the refuse-to-run gate. Resolve the input to a finding set before any edit: the named report (or the latest `ai/audits/<date>-knowledge.md`, confirmed when several exist) and its `## What to do next` list; finding ids looked up in it; or one finding the user states with its `file:line`, class and evidence, echoed back as one row. **None of these → HALT** and route to `/audit-knowledge`. Never improvise a finding list from a fresh scan. Routed rows (align, documentation, security, baseline) are never touched here.

## Phase 2 — Organize

- **Default:** re-run detection → build new profile → diff → categorize → propose updates → apply on confirmation → re-anchor → validate. `--dry-run` stops after the categorized diff (no writes).
- **`--from-audit`:** MUST FIX (HIGH) first, then SHOULD FIX, then OPTIONAL. Within a tier, the widest root cause first: a generator (`apply-anchors.sh` for N anchors), the profile, an index, a consumer hook, before a single line. For each row record before touching anything: its `file:line` and site count, its class, the **owning engine** (the re-run probe), its remedy (table below) and whether it crosses a STOP line.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md). Then:
- [`precedents/learning.md`](../../../snippets/precedents/learning.md) and [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Learning (V490–V509): the tier and the variant list each fix must pass.
- [`learning-sink.md`](../../../snippets/learning-sink.md): sink states and thresholds.
- **Default only — re-extract (invoke the engine; do NOT hand-walk).**

> **Hard rule — the oracle is re-derived, not re-asserted.** This phase MUST invoke the
> `extract-codebase-overview` skill and MUST rewrite `.claude/_extracted-codebase.md`. A run that
> updates `codebase-profile.md` / `ai/conventions.md` while leaving the oracle at its old bytes
> produces the exact artefact this command exists to destroy: a knowledge layer stamped with
> today's date over a codebase read at some earlier commit.

1. **Re-derive repo shape** (`repo_shape`, `shape_signal`, `members`) from disk, exactly as `/setup-project` Phase 1 does. Do NOT read it out of `.claude/codebase-profile.md § 17`: a member added or removed since the last run is one of the changes this command exists to catch. A shape that differs from § 17 is itself a `CHANGED` diff entry.
2. **Invoke `extract-codebase-overview`** with those three inputs (all `required`; an absent `members` halts there with `[SHAPE-INPUT-MISSING]`). Write to `.claude/_extracted-codebase.md`. The skill runs its Step 2.5 census, its `[SAMPLED: <seen>/<present> <unit>]` markers, its Step 8 `[CONTESTED]` rows and its Step 15 check 7, and chains `extract-business-context` at its Step 13.
3. **Preserve the approval stamp, never re-stamp.** Copy the existing `approved_by:` / `approved_hash:` lines into the new oracle **verbatim**. The body changes, so the hash no longer matches: `/setup-project-health` check 9 then reports "oracle changed since approval" and a human re-reads before audits build on it (`templates/phases/phase-2-profile.md § Oracle approval`).
4. **Invoke `extract-base-class-idiom`** per load-bearing unit in the new oracle's `## Base classes` and rewrite `.claude/_extracted-idioms.md`, with the same stamp rule. Skip only when no unit has ≥3 dependents.

Read for the diff (AFTER the new extraction is written, so nothing stale leaks into it): the prior oracle (`git show HEAD:.claude/_extracted-codebase.md`), the current profile, `ai/conventions.md` (auto-populated section only), `ai/modules.md`, `ai/stack.md`, `ai/business-domain.md`.

## Phase 4 — Generate

### Default — new profile + categorized diff
- Build the NEW profile in `.claude/codebase-profile.md.new` **from the oracle Phase 3 just wrote**: the five machine-parsed headings (`Architecture`, `Naming`, `Testing`, `Data access`, `Error handling`) come from `_extracted-codebase.md`, not from a second read.
- Diff: `diff -u .claude/codebase-profile.md .claude/codebase-profile.md.new`, and the oracle against its prior version. Three oracle deltas are reportable on their own: **coverage** (`<seen>/<present>` fell while the repo grew → `CHANGED`), **provenance** (`[found:] → [inferred:]` is a fact that stopped being verifiable), **`[CONTESTED]` rows** appearing (`ADDED`) or clearing (`REMOVED`).
- Categorize: `ADDED` (entity, pattern, module, dependency) · `CHANGED` (base class moved, suffix shifted, layer renamed, **a profile facet line changed** — every anchor citing it is now stale) · `REMOVED` (module deleted, dependency dropped).
- Propose per category: ADDED → `learned-patterns.md` (through `pattern-emergence-watcher`), glossary, ADR; CHANGED → `ai/conventions.md`, the rule, re-anchor; REMOVED → repoint or delete references, a superseding ADR if one was about it.
- **A newly-`[CONTESTED]` category is never proposed as a convention update.** It goes to `ai/conventions.md § Unsettled conventions` with both options, counts and a citation each (`templates/phases/phase-4.7-deep.md § Unsettled conventions`), and to `ai/dynamic/decisions-pending.md` as "pick one or accept the split".
- Show the categorized diff in plan form; pause for confirmation (unless `--dry-run`).

**Mechanical halt — source-vs-knowledge conflict.** Refuse to advance to Phase 5 if any diff entry is unresolved (verb missing, both sides marked authoritative, or auto-resolution would keep the old text). Cite both sides; pick source:

```
## /refresh-knowledge halt — source-vs-knowledge conflict on <key>
Source (HEAD <new-sha>): <fact derived from re-detection>
Knowledge (cached at <old-sha>): <stale fact still in the file>
Resolution: source wins (the knowledge will be overwritten on confirm).
Reason for halt: <verb-missing | marker-shadowed | scope-ambiguous>
```

There is no "keep the old text" branch: a user who wants it kept moves it BELOW the idempotency marker, where it becomes a user edit. **The check is external, not self-policed:** Phase 6 re-runs `knowledge-facts.py . --classes=1,4,5,6` and every key named in the halt log must read one value, equal to the source (V494, V496).

### `--from-audit` — the per-finding loop

This mode inherits the two invariants of [`fix-bug-core.md`](../../../snippets/fix-bug-core.md): the failing check first, and the sibling ledger `N_found == N_fixed + N_explained + N_followup`. Here the failing check is the owning engine on the site, and the sibling sweep is that engine's `--expand` list for the root cause.

```bash
KS="${KS:-.claude/skills}"; [ -f "$KS/knowledge-ref-scan/scripts/kn_common.py" ] || KS="$HOME/.claude/templates/packs/learning/skills"
export GIT_OPTIONAL_LOCKS=0
probe() { python3 -I "$KS/$1/scripts/$2" . --only="$3"; echo "exit $? (1 fires · 0 quiet · 2 blocked)"; }
# probe knowledge-ref-scan knowledge-refs.py CLAUDE.md:12      probe knowledge-fact-scan knowledge-facts.py .claude/agents/x.md:20
# probe memory-hygiene-scan sink-audit.py ai/dynamic/drift-log.md:41      probe decision-record-scan adr-index.py docs/decisions/0014-x.md:5
# context-load-scan has no --only: python3 -I "$KS/context-load-scan/scripts/load-budget.py" . --classes=<n>
```

**Per finding, all six steps:**
1. **Re-verify, then fail first.** Run the probe on the finding's `file:line` and paste the row it prints (exit 1). Exit 0 → `not reproduced`: record it, make no edit, move on. Exit 2 → `blocked` with the reason. A Refuted row is never patched; an Unconfirmed one is settled by its probe (a second reader for a pair, a lockfile for an `UNREAD` key) first.
2. **Apply the remedy for its class:**

| Class | Remedy (never the alternative) | Proof |
|---|---|---|
| KN-01/02/04 dead path, symbol, xref | RENAMED → repoint to the successor `git log --follow` / `git log -S` names; DELETED → delete the line, or repoint by hand when the line is an instruction an agent needs (STOP and ask) | V490, V491 |
| KN-03 dead command | repoint to the script or command that exists; an uninstalled pack command → say which pack installs it, or remove the instruction | V492 |
| KN-05, KN-15, KN-13 anchors, KN-12 copies | regenerate: `bash ~/.claude/scripts/apply-anchors.sh . --apply`, twice; never edit a block by hand | V493, V496 |
| KN-07/11 fact | overwrite with the lockfile-derived value at the source (`codebase-profile.md`, `CLAUDE.md`, the `ai/` file), then regenerate what derives from it | V494 |
| KN-08/09 count, module map | recompute from the tree and overwrite; prefer a count with its set named and dated | V495, V498 |
| KN-13 index, cheatsheet, digest | `@knowledge-curator` mode `regenerate` (§ 8), twice | V496 |
| KN-14 citation | repoint the line number when the text moved; re-verify the claim when the text changed (then it is a KN-07 fix) | V497 |
| KN-20 stale entry | re-verify: still true → repoint the citation; fixed → `RESOLVED → <sha>`; obsolete → `SUPERSEDED` with the reason | V499 |
| KN-21/22 duplicate, contradiction | merge into the older entry keeping both citations; a contradiction is settled only by the newest explicit user statement, the other marked `SUPERSEDED → <date>` (else STOP) | V500 |
| KN-23/24/25 provenance, lifecycle, n=1 | add date, source and citation; a stuck READY or VALIDATED entry → `/promote-pattern` or `/promote-decision` (their own approval gate), or record the state and reason; narrow an n=1 universal lesson | V501 |
| KN-26 lesson → enforcement, KN-36 unguarded | hand off: a convention to `/align` (align pack, when installed); a hook, lint rule or test to `/add-feature`, which writes it failing first on a violating snippet; an eval case to `/eval --seed` | V502 |
| KN-27 consumer contract | make the entries match the declared format, or (when the consumer is a project hook) make it read the declared `## Format per entry`; a Refract-shipped consumer is a framework fix (route `/setup-project --refresh` after the pack update) | V503 |
| KN-28 ADR reciprocity, superseded cited | add the missing link (`Superseded by` / `Supersedes`, or `Amended by` for a partial); repoint the citation to the successor | V504, V505 |
| KN-28 chosen option absent | **STOP**: a superseding ADR or a code change is the user's decision | V506 |
| KN-29 ADR home | repoint project-owned consumers to the home `adr-index.py --list` resolves; an installed pack command is regenerated by `/setup-project --refresh`, never hand-edited | V505 |
| KN-31/32 load | move detail to an on-demand file, scope a rule with `paths:`, add `@AGENTS.md` to `CLAUDE.md` (never just another `@import` of the same bulk) | V507, V508 |
| KN-19 oracle age | run this command's default mode | V509 |

3. **Edit scope.** `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, `ai/**` (never `ai/audits/**` or other history), `.claude/codebase-profile.md`, project-owned `.claude/rules/**`, and anchor blocks only through the generator. Any code, manifest, lockfile or test file, or a pack-shipped artifact body outside its anchor → STOP and route.
4. **Pass after.** The probe exits 0 on the site; then the **whole root cause**: the engine's `--expand` lists no remaining site of that group; then the **decoys**: the class re-run prints no row that was not there before the edit (`diff` of the candidate rows before and after, minus the closed ones). An edited line's new claim must itself resolve (re-probe it).
5. **Derived files, twice.** Regenerate, snapshot (`shasum` of every file the generator touched), regenerate again, compare: the second run changes no byte (`cmp`, never mtime — a write that changes nothing still moves the mtime). A second run that changes a byte is a non-idempotent generator: record `INCOMPLETE` and report it.
6. **Record** the fix-ledger row in `ai/runs/<date>-knowledge-fix-<4hex>/ledger.md`, with the probe output before and after.

**STOP and ask before:** deleting an instruction line whose target was deleted with no successor; settling a contradiction no explicit user statement settles; changing an ADR status beyond the reciprocal link, or writing a superseding ADR (`/add-adr` or `/promote-decision`); promoting an entry (the promote commands carry their own approval); moving content out of a user-authored `CLAUDE.md` section; regenerating anchors when `apply-anchors.sh` prints `MARKER-CORRUPT`; anything outside the edit scope.

Fix ledger (required artifact):
```
| Finding | Class | Probe before | Remedy | Probe after | Root cause (--expand) | Twice | State |
|---------|-------|--------------|--------|-------------|------------------------|-------|-------|
| K-01 | KN-07+13 | knowledge-facts --only .claude/agents/a.md:20 exit 1 | profile already right; apply-anchors --apply ×2 | exit 0 | 0 of 177 sites | identical | closed |
| K-04 | KN-20 | sink-audit --only ai/dynamic/drift-log.md:41 exit 1 | RESOLVED → 3fa91c0 | exit 0 | — | — | closed |
| K-07 | KN-28 | adr-index --only docs/decisions/0009-x.md:4 exit 1 | — | — | — | — | STOP: chosen option absent (user) |
```
A row with no failing-first probe, a root-cause re-run above 0, or a second regeneration that changed a byte is **not** closed.

## Phase 5 — Update

**Default**, on confirmation:
- Replace `.claude/codebase-profile.md` with the `.new` file Phase 4 wrote, then remove the scratch file.
- **Re-anchor.** `bash ~/.claude/scripts/apply-anchors.sh . --apply`: it rewrites the five profile facet lines of every live anchor whose text no longer matches the profile (`REANCHOR`), rewrites the legacy header that named framework paths (`HEADER`), and reports a corrupt marker set without touching it (`MARKER-CORRUPT`). Run it a second time: it must print `Profile facets re-anchored: 0` and change no byte. Without this step a profile correction leaves every anchor stale (177 copies on a real monorepo).
- Update `ai/conventions.md` auto-populated sections ABOVE the idempotency marker; preserve user edits BELOW. Update `§ Unsettled conventions` from the new `[CONTESTED]` rows (a category appears there OR as a settled rule, never both).
- Dispatch `pattern-emergence-watcher` over the ADDED/CHANGED set and let IT write `ai/dynamic/learned-patterns.md` (it owns the Rule-of-Three floor, the stack-default exclusion and `WATCHING`).
- Add entries to `ai/dynamic/decisions-pending.md` for changes needing a human decision.
- `@knowledge-curator` mode `regenerate`: `_session-digest.md`, `_decision-index.md`, `_convention-cheatsheet.md`.
- Update `ai/modules.md` rows for ADDED/REMOVED modules and `ai/stack.md` for dependency changes; append to `ai/dynamic/changelog.md`; prepend "Knowledge refresh on YYYY-MM-DD" to `ai/status.md` Recent Changes.

**`--from-audit`:** the edits of the loop; `ai/audits/<YYYY-MM-DD>-knowledge-fix.md` with the fix ledger, `Re-audit: <was> → <now>` and `Status: COMPLETE | INCOMPLETE`; one line in `ai/dynamic/changelog.md`.

## Phase 6 — Validate

- **Oracle actually moved** (default) — `.claude/_extracted-codebase.md`'s `Coverage:` census `<short-sha>` names the commit recorded in Phase 1 (V509). An unchanged oracle after a non-empty diff means Phase 3 was skipped.
- **Approval stamp preserved, not re-issued** — `approved_by:` is byte-identical to its pre-run value.
- **Source wins, checked by the engine** — `knowledge-facts.py . --classes=1,4,5,6` prints no row for a key the halt log names, and no anchor site cites a profile line it contradicts. This replaces the old self-check: the engine, not the agent that wrote the edit, decides.
- **Anchors idempotent** — the second `apply-anchors.sh --apply` printed `Profile facets re-anchored: 0`, `Stale citations repaired: 0`, and a before/after `shasum` of `.claude/` matches.
- Re-read `ai/conventions.md` after write: idempotency marker present, user content below it preserved. Spot-check one ADDED entity and one CHANGED suffix against actual files.
- `--from-audit`: every closed row has a probe before (exit 1) and after (exit 0), a root-cause re-run at 0, and for derived files an identical second regeneration; the sibling ledger balances.
- Run `/audit-knowledge` next: the classes this run touched must not regress.

## Phase 7 — Improve

- Noisy detection (vendored code, generated files) → persist exclusions in `.claude/refresh-ignore.txt`.
- The same CHANGED items every quarter → the auto-detector is stale; queue an improvement to `/setup-project` Phase 2.
- A root cause closed twice (the anchors regenerated again after another profile change) → wire `apply-anchors.sh --apply` to run whenever `codebase-profile.md` changes (a post-commit hook), and queue that to `ai/dynamic/decisions-pending.md`.

## Output

Default:
```
## /refresh-knowledge — diff against last profile (<old commit hash> -> <new commit hash>)

### Profile changes (12 detected)
ADDED:   Entity `Subscription` (8 references in <modules-root>/billing/) — propose to `ai/core/glossary.md`
CHANGED: Data access facet: "MikroORM (MySQL), ULID PKs" → "MikroORM (Postgres 16), UUIDv7 PKs" — 177 anchors cite it: re-anchor
REMOVED: Module `legacy-auth/` (deleted in abc123) — 3 references repointed or deleted; ADR-0008 affected
Re-anchor: apply-anchors.sh --apply → REANCHOR 177 · HEADER 0 · MARKER-CORRUPT 0; second run 0 changes (byte-identical)
Engine check: knowledge-facts --classes=1,4,5,6 → 0 rows on the halted keys

Apply now? [y/n]
```

`--from-audit`: the fix ledger, then `Re-audit: KNOWLEDGE-STALE (2 high) → TRUE` and `Status: COMPLETE | INCOMPLETE`.

## What to do next — required closing section
Every run ends with `## What to do next`: ONE ordered, numbered to-do. **MUST FIX** (open or STOPped HIGH rows) first, then **SHOULD FIX**, then **OPTIONAL**. Each step carries the `file:line`, the **Fix** and the **Verify** (the probe and its V-number). A STOPped row names the decision the user owes (the superseding ADR, the contradiction, the instruction line). The closing steps: re-run `/audit-knowledge`; `/learn-from-task`. A fully closed run collapses to one line. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Refresh on a dirty tree — confusing diff; refuse.
- Refresh too soon after setup — no meaningful changes; report and exit.
- **Profile corrected, anchors left stale** — the defect this command used to ship: every installed artifact kept the old facet line. Phase 5 re-anchors; Phase 6 proves it.
- **Hand-editing 177 anchors** — a second regeneration overwrites them, and the next profile change repeats the defect. Fix the generator's input.
- **"Closed" with the engine never re-run** — not closed.
- Auto-applied updates without confirmation (default mode) — never; always pause unless `--dry-run`.

## Related

### Sibling commands in learning pack
- `/audit-knowledge` — finds what this command closes (`--from-audit`).
- `/detect-drift` — conventions only (dispatches align when installed).
- `/learn-from-task`, `/promote-pattern`, `/promote-decision` — the producers and graduations a fix may hand to.

### Skills and agents
`extract-codebase-overview`, `extract-business-context`, `extract-base-class-idiom` (default mode); the five learning detectors (the probes); `@knowledge-curator` (mode `regenerate`); `@pattern-emergence-watcher`.

### Shared contracts
[`fix-bug-core.md`](../../../snippets/fix-bug-core.md) · [`precedents/learning.md`](../../../snippets/precedents/learning.md) · [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Learning · [`learning-sink.md`](../../../snippets/learning-sink.md) · [`review-action-plan.md`](../../../snippets/review-action-plan.md)
