---
description: "Capture a finished task's decisions, patterns, corrections and failures into the sinks, with provenance."
kind: command
pack: learning
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /learn-from-task

## Canonical sink set (read first — this command + `knowledge-curator` write the SAME files)

The learning loop has ONE sink set. Every observation lands in exactly one of the append-only `ai/dynamic/` files (plus the failure catalog), and `knowledge-curator` later promotes the mature ones into the formal layer. The two writers (this command + the curator) never diverge on WHERE things go because the table is **defined once** in [`templates/snippets/learning-sink.md`](../../../snippets/learning-sink.md) — read it there. The consumers kept in sync via that snippet are:

- `templates/packs/learning/commands/learn-from-task.md` (this file — pack-scoped; there is no root `commands/learn-from-task.md`, and `verify-global-scope.sh` exists to keep it that way)
- `templates/packs/learning/agents/knowledge-curator.md` (canonical curator)
- `templates/repo-baseline/.claude/agents/knowledge-curator.md` (installed curator)

Change a sink in the snippet, not here — there is no per-consumer copy to keep in sync.

## Pre-flight gate (mechanical)

If the just-completed task touched 0 files OR the task description is <30 chars, halt with: `task too small to learn from; nothing to promote.` This prevents promoting empty/spammy patterns.

Closes the learning loop. Without this, every session ends and the lessons evaporate. This is itself the canonical Phase 7 (Improve) implementation that other commands hand off to.

## Phases applied

1, 3, 5. The whole command IS Phase 7 (Improve) for the just-finished task; internally it still runs Understand → Retrieve → Update.

## When to use / NOT to use

- USE: after completing a feature / bug fix / refactor / spike.
- USE: before `/clear` or session end if the work was substantial.
- USE: after a user has corrected the AI multiple times in a session.
- USE: after making a decision in chat that wasn't yet recorded.
- NOT: after trivial sessions (one-line edits, lint fixes, formatting).
- NOT: mid-task (wait until the unit of work is done).

## Phase 1 — Understand (the just-completed task)

Reflect on the just-completed task. Answer (in your head as the AI):
- What was the goal?
- What was actually done? (Files touched, behavior changed, tests added.)
- What decisions were made along the way? (Approach choices, library picks, trade-offs.)
- Which existing patterns were followed?
- Did any new pattern emerge from this task?
- Did the user correct the approach? What was the correction?
- Is there a follow-up the next session should know about?

If the task was trivial (one-line edit, lint fix, formatting): refuse + suggest skipping. Don't pollute the learning log with noise.

## Phase 2 — N/A (no decomposition)

This is a reflection + write command, not a multi-step plan.

## Phase 3 — Retrieve (read the right context)

ALWAYS:
- `ai/dynamic/interaction-log.md` — recent entries (style, format).
- `ai/dynamic/learnings.md` — does this raw observation already exist (increment `Seen:`) or is it new?
- `ai/dynamic/learned-patterns.md` — does this new shape match an already-watching entry (increment count) or is it new (add)?
- `ai/dynamic/feedback-learned.md` — does this user correction repeat a known one (increment Repeated counter) or is it new?
- `ai/dynamic/decisions-pending.md` — does this decision relate to a pending one?
- `ai/failures/_index.md` — is this "approach to try" in fact a previously-failed one? If so, don't re-record; cite the failure entry.
- `ai/status.md` current `Updated:` date for context.

## Phase 4 — N/A (no code generation)

This command produces knowledge entries, not code.

## Entry contract — provenance, reconcile on write, delta edits (every sink below)

An entry nobody can re-check later is the one that rots silently: `memory-hygiene-scan` §1 re-resolves each open entry's evidence and §4 flags entries with none (KN-20, KN-23). So every entry this command writes carries:
- **a dated heading** — `### <YYYY-MM-DD> — <label>`, in the shape the sink's own `## Format per entry` block declares (a project may redefine it; the declared format wins over the template, precedents § 24);
- **a source** — `Source: <task name>` (or `/eval <run>`, or the commit), so a reader can find the work it came from;
- **at least one citation** — a tracked `path:line` (or `path` for a whole file) the observation is about. A preference or decision with no code anchor cites `user, <YYYY-MM-DD>` instead (precedents § 19): it is never stale by code, and it is never invented.

**Reconcile on write** (Mem0-style: compare before adding). After appending an entry, run the engine on that one entry:

```bash
KS="${KS:-.claude/skills}"; [ -f "$KS/memory-hygiene-scan/scripts/sink-audit.py" ] || KS="$HOME/.claude/templates/packs/learning/skills"
python3 -I "$KS/memory-hygiene-scan/scripts/sink-audit.py" . --entry=<sink>:<heading line> --classes=2,3,4
echo "exit $? (0 reconciled · 1 rows to resolve · 2 blocked)"
```

- a §2 **duplicate** row → delete the line you just appended and increment the existing entry's `Seen:` / `Repeated:` / occurrence list instead, adding your citation to it;
- a §3 **contradiction** pair → keep the new entry, quote both in the output, and mark the older one only when the user's newest explicit statement settles it (`SUPERSEDED → <date>`); otherwise list the pair under "Needs a decision";
- a §4 **provenance** row → add the missing date, source or citation before finishing;
- exit 2 (no engine, unreadable sink) → say so in the output; never print "reconciled".

**Delta edits only.** Append a block or increment a counter with `Edit`; never rewrite a sink file whole (a whole-file rewrite loses detail other sessions wrote, the ACE "context collapse" finding). Never delete another entry: the curator's invariant is archive, don't delete.

## Phase 5 — Update (persist changes to the knowledge base)

1. Append entry to `ai/dynamic/interaction-log.md` using the format:
   ```markdown
   ### <YYYY-MM-DD> — <task name>
   Type: feature | bug | refactor | spike | ops | review
   Status: COMPLETE | IN_PROGRESS | ABANDONED
   Files touched: <count> (<top paths>)

   What was done:
   <2-3 sentences>

   Decisions made:
   - <decision> (→ link if formal ADR planned)

   Patterns followed:
   - <link to ai/patterns/<name>.md>

   Patterns introduced:
   - <if any new shape emerged → entry to learned-patterns.md>

   User corrections / feedback:
   - <if user redirected → entry to feedback-learned.md>

   Open follow-ups:
   - <follow-up + owner + deadline>
   ```

2. If decisions emerged that aren't yet ADRs: append to `ai/dynamic/decisions-pending.md`.

3. If new patterns emerged: append to `ai/dynamic/learned-patterns.md` with status `WATCHING` (and occurrence path = the just-touched files). If a watching entry already covers this shape, increment its occurrence count.

4. If user corrected the AI: append to `ai/dynamic/feedback-learned.md` (with `Repeated: 1` or increment if existing).

5. If a raw observation emerged that isn't a code shape, a decision, or a correction (a low-confidence "noticed once" note): append to `ai/dynamic/learnings.md` with status `RAW`. Increment `Seen:` if it recurs. This is the persistence-pyramid's first rung (`session-context → learnings.md → ai/conventions.md`); the curator promotes it at 3 sightings.

6. If an approach was tried and did NOT work: append ONE entry to the single append-only catalog `ai/failures/_index.md` under `## Catalog` (cite what was tried + root cause + the alternative that worked). Never create per-file `ai/failures/<NNNN>-<slug>.md` entries — the baseline ships ONE index.

7. If the task surfaced a drift between code and convention: append to `ai/dynamic/drift-log.md`.

7b. If a project term was used in a sense its plain reading would get wrong — or two terms that look like synonyms turned out to differ — append to `ai/dynamic/vocabulary.md`: the term, the meaning it carries **here**, the reading it is NOT, and a `<file:line>` where it appears. Increment `Seen:` if the term is already listed. Do NOT log every domain noun; the entity table in `ai/core/glossary.md` already holds those. The curator promotes at 2 independent sightings.

8. Append a one-line summary to `ai/dynamic/changelog.md`.

9. **Confirm-list** — the only path from a lesson to a rule, sensor or precedent ([`learning-sink.md` § Confirm-list and the promotion audit line](../../../snippets/learning-sink.md)). Gather: the run's `ai/runs/<run>/ledger.md` § Diary when the task was a delivery run; the entries this task pushed past their sink threshold; and, when `.claude/scripts/review-dismissals.py` is installed, the `- [ ]` lines that `python3 .claude/scripts/review-dismissals.py propose --write` leaves in `ai/dynamic/calibration-proposals.md`. Show ONE numbered list (candidate · target: a sensor (hook, lint, test) when a script can check it, else a rule `.claude/rules/<x>.md`, a precedent, or `/promote-pattern` / `/promote-decision` · evidence) and ask once. Write only what the human keeps, and append one audit line per kept item to `ai/dynamic/promotions.md`. Nothing kept → write nothing and print `confirm-list: <n> candidates, 0 kept`.

## Phase 6 — Validate (verify correctness)

- New `interaction-log.md` entry has Type, Status, Files touched, all sections (even if empty placeholders).
- learned-patterns.md occurrence increments are correct (didn't double-count).
- feedback-learned.md `Repeated` counter is correctly incremented (not reset).
- changelog.md entry is a single line.
- Every entry written this run has a dated heading, a `Source:` and a citation (or `user, <date>`), and its `--entry` reconcile exited 0 or its rows are resolved in the output.
- Every kept confirm-list item has exactly one `ai/dynamic/promotions.md` line (who, when, source, evidence, what), and no unconfirmed candidate was promoted.

## Phase 7 — Improve (this command IS the loop closer)

After this runs, the sinks are surfaced for manual dispatch (the loop is NOT auto-draining — see "Dispatch" below):
- Next session's `session-start.sh` PRINTS the open follow-ups + the learning queue + READY patterns so a human notices them.
- The next session's agents read `feedback-learned.md` and don't repeat the corrected mistake.
- `pattern-emergence-watcher`, when invoked, sees the new entry and starts counting occurrences.
- `/audit-knowledge` (read-only) reports what is ready: a READY pattern or VALIDATED decision past its threshold is a `memory-hygiene-scan` §5 row carrying its `/promote-pattern` or `/promote-decision` command; `knowledge-curator` graduates it there.
- `/refresh-knowledge` catches the long-term changes the per-task entries don't, when you run it after a major refactor / quarterly.

This command writes the sinks; promotion is a human-dispatched follow-up.

## Dispatch (how the sinks get drained — honest wording)

There is **no auto-invoking post-task hook and no cron** in the shipped baseline. The git hooks (`post-commit-learn.sh`, `post-merge-learn.sh`) only APPEND review hints to `ai/dynamic/.review-queue`, and `session-start.sh` only PRINTS that queue. Nothing automatically runs the curator. To drain the queue and promote mature sinks, a human runs one of:

- `/learn-from-task` — this command (synchronous, scoped to the just-finished task).
- `/promote-pattern <name>` / `/promote-decision <id>` — graduate a single READY entry.
- `/audit-knowledge` — sweep all sinks read-only with the five detectors and report what's ready, stale or unreadable.

If you want it automated, wire `/audit-knowledge` into `/schedule` yourself — the baseline does not do this for you.

## Output

```
## /learn-from-task — captured

Phase 1 (Understand): reflected on task — feature/orders-perf, COMPLETE.
Phase 3 (Retrieved): interaction-log.md last 5 entries, learned-patterns.md (1 watching match), feedback-learned.md (no match).
Phase 5 (Updated):
  - interaction-log.md (+1 entry)
  - learnings.md (+1 RAW: prefer TaskGroup over gather)
  - decisions-pending.md (+1: queue-library choice)
  - learned-patterns.md (+1 WATCHING: idempotency-key cache wrapper)
  - feedback-learned.md (no entries this task)
  - failures/_index.md (+1: TypeORM decorator in V2 setup — don't retry)
  - drift-log.md (+1: direct stdout call in <billing service file>)
  - changelog.md (+1 line)
Reconcile (sink-audit --entry): 6 entries → 5 clean · 1 duplicate (merged into learned-patterns.md:41, Seen 2 → 3)
Confirm-list: 3 candidates → 1 kept (sensor: lint for direct stdout calls ← drift-log.md:12) · audit line → promotions.md
Phase 6 (Validated): all entries shape-conformant; each has date, Source and a citation.
Phase 7 (Improved): sinks written; session-start will PRINT follow-ups + queue for manual dispatch (no auto-run).

Decisions queued for ADR consideration:
- "Prefer queue-library X over queue-library Y for our queue layer" (will graduate after 2 weeks if held)

Patterns queued for promotion watch:
- "Idempotency-Key + cache lookup wrapper" (1st occurrence: <place-order use-case file>)

User corrections recorded:
- (none in this task)

Drift findings added:
- <billing service file:42> uses a direct stdout / print call (rule violation) — high severity, OPEN

Follow-ups for next session:
- TODO: complete the payment-webhook handler — currently stubbed
- TODO: add e2e test for the new endpoint

Status: COMPLETE
```

## Failure modes

- **Task was trivial**: refuse + suggest skipping ("nothing meaningful to learn here").
- **Multiple unfinished tasks in session**: ask user which to learn from (or "all").
- **Decisions disagree with existing ADR**: flag conflict; either ADR is wrong, decision is wrong, or this is a deliberate supersession (write a new ADR).
- **Pattern entry duplicates an existing PROMOTED pattern**: don't add to learned-patterns; mention in interaction-log only.

## See also

- `ai/dynamic/interaction-log.md` — the spine (per-task summary).
- `ai/dynamic/learnings.md`, `learned-patterns.md`, `feedback-learned.md`, `decisions-pending.md`, `drift-log.md` — supporting sinks.
- `ai/failures/_index.md` — single append-only don't-retry catalog.
- `knowledge-curator` agent — reads the full sink set above and graduates mature entries to the formal layer (manual dispatch).
- `/promote-pattern` — promotes ready patterns to formal docs.

## Related

### Sibling commands in learning pack
- `/detect-drift` — sibling command in learning pack
- `/promote-pattern` — sibling command in learning pack
- `/refresh-knowledge` — sibling command in learning pack
