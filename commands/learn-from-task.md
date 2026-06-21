---
description: Phase 6 manual entry point. Promote concrete learnings from the just-completed task into the persistent knowledge layer (ADRs, conventions, patterns, failure catalog).
kind: command
pack: orchestration
version: 1.0.0
related-commands:
  - /setup-project — initial setup
  - /setup-project-health — measures whether learning is happening
  - knowledge-curator agent — the recurring counterpart
---

# /learn-from-task

## The Premise (read first, internalize, do not deviate)

**Existing memory is the truth. Append on real, surprising signal only.** Don't promote trivial events to permanent memory. The persistence pyramid (dynamic → conventions → ADRs → failures) exists precisely to keep one-offs out of formal knowledge — every promotion is a tax on every future agent who has to read it.

**The agent's job is exactly this:**
1. Distill the rule, not the conversation. One sentence. With ≥2 cited examples for conventions.
2. Default to `ai/dynamic/learnings.md` (append-only). Promote only when the persistence pyramid's threshold is hit.
3. Refuse trivial sessions (no edits, single-line chats, throwaway questions) — they are not "tasks" worth learning from.
4. Skip duplicates — if the same observation already exists in dynamic / conventions / ADRs, no-op silently.

## Mechanical halt (trivial-event filter)

1. **Refuse if conversation is under 30 chars**: a session shorter than that is a ping, not a task. No memory entry. Exit silently.
2. **Refuse if file edits == 0**: if no files were edited (no Write/Edit tool calls in the session, no commits since `--since` ref), the "task" produced no diff to learn from. Exit silently.
3. **Refuse promotion to conventions below threshold**: convention rows REQUIRE ≥2 cited example files AND 3 sightings of the observation (the persistence pyramid's "repeat 3x"). Either gate unmet → goes to `ai/dynamic/learnings.md`, not `ai/conventions.md`. The two gates are independent: 3 sightings of the same rule with only 1 cited example still stays in dynamic until a 2nd example is cited.
4. **Refuse to edit existing ADRs**: ADRs are append-only. Supersede with a new ADR; never mutate.
5. **Refuse to write a learning that contradicts an accepted ADR** without explicit supersession: cite the ADR being overturned, write a new ADR, then proceed.
6. **Refuse re-recording**: if the observation already exists in dynamic / conventions / ADRs / failures (text match or paraphrase match), no-op. Re-running the command produces no diff.

The learning loop's manual handle. Run after a non-trivial task to convert raw conversation context into durable knowledge.

## When to run

- A correction landed ("don't use X here, use Y because Z").
- A subtle convention emerged from the diff that wasn't documented.
- A failed approach should be cataloged so future agents don't retry it.
- A decision was made that future readers need to understand.

The recurring counterpart is the `knowledge-curator` agent. It is NOT auto-invoked — the shipped baseline has no post-task hook and no cron that runs it. The git hooks only append review hints to `ai/dynamic/.review-queue` and `session-start.sh` only PRINTS that queue; a human drains it by running `/learn-from-task`, `/audit-knowledge`, `/promote-pattern`, or `/promote-decision`. This command is the synchronous, scoped handle on that loop.

## Inputs

- The current conversation context (the task that just finished).
- Optional: a specific commit range (`--since <ref>`) to scope the analysis.

## Canonical sink set (this command + the pack copy + both `knowledge-curator` copies write the SAME files)

The learning loop has ONE sink set. This command writes ONLY to the raw append-only sinks; the `knowledge-curator` agent later promotes mature entries into the formal layer. The table is **defined once** in [`templates/snippets/learning-sink.md`](../templates/snippets/learning-sink.md) — read it there. Every consumer links to that snippet, so the producer and the promoter can never silently diverge. The consumers (all kept in sync via the snippet) are:

- `commands/learn-from-task.md` (this file)
- `templates/packs/learning/commands/learn-from-task.md` (pack mirror)
- `templates/packs/learning/agents/knowledge-curator.md` (canonical curator)
- `templates/repo-baseline/.claude/agents/knowledge-curator.md` (installed curator)

Change a sink in the snippet, not here — there is no per-consumer copy to keep in sync.

## Outputs (zero, one, or more of — all are raw sinks)

The targets below are the same 8 raw sinks defined in [`templates/snippets/learning-sink.md`](../templates/snippets/learning-sink.md); this table adds only the per-target write **trigger** (when each is written + append-vs-increment) — the sink set itself is owned by the snippet.

| Output target                            | Trigger                                                  |
|------------------------------------------|----------------------------------------------------------|
| `ai/dynamic/interaction-log.md` (append) | Always (the per-task spine: type, status, files, sections) |
| `ai/dynamic/learnings.md` (append)       | Lower-confidence raw note / correction-as-note; not yet promoted |
| `ai/dynamic/learned-patterns.md` (append/incr) | A reusable code shape emerged (status `WATCHING`)   |
| `ai/dynamic/feedback-learned.md` (append/incr) | The user corrected the AI (`Repeated:` counter)     |
| `ai/dynamic/decisions-pending.md` (append) | A decision was made that may graduate to an ADR        |
| `ai/dynamic/drift-log.md` (append)       | Code-vs-convention divergence surfaced during the task   |
| `ai/failures/_index.md` (append entry)   | Approach we tried that did NOT work (don't-retry entry)   |
| `ai/dynamic/changelog.md` (append)       | One-line summary of the task                              |

Formal-layer files (`ai/decisions/<NNNN>-*.md`, `ai/conventions.md` managed section, `ai/patterns/<name>.md`, `.claude/rules/`) are written by `knowledge-curator` on promotion — NOT by this command. This command feeds the sinks; the curator graduates them.

## Promotion rules

This command DOES NOT publish raw observations to formal knowledge. It writes the raw sinks above; the curator applies the persistence pyramid:

```
session-context        → ai/dynamic/learnings.md          (raw, append-only)
recurring code shape    → ai/dynamic/learned-patterns.md   (WATCHING → READY)
user correction         → ai/dynamic/feedback-learned.md   (Repeated counter)
informal decision       → ai/dynamic/decisions-pending.md  (VALIDATED after holding)
failed approach         → ai/failures/_index.md            (append entry — don't-retry catalog)

           ── curator promotes (manual dispatch) ──▶
3 sightings + ≥2 cited examples → ai/conventions.md   (managed section)
READY pattern (≥3 files, ≥2 wks) → ai/patterns/<name>.md
VALIDATED decision      → ai/decisions/<NNNN>-*.md     (ADR, append-only)
Repeated ≥2 feedback    → .claude/rules/<rule>.md
```

A learning surfaced once goes to dynamic. Promote to a convention only when BOTH gates are met: 3 sightings of the same observation AND ≥2 cited example files (halt #3). The pyramid prevents premature codification of one-offs.

## Hard rules (inherits from `templates/governance/hard-rules.md`)

- ADRs are append-only — never edit an existing one. Supersede with a new ADR that references the old.
- Failure catalog entries cite the failed approach + root cause + the alternative that worked. No editorializing.
- Convention promotions require BOTH 3 sightings AND ≥2 example files cited in the rule's RATIONALE (the two gates of halt #3).
- The command writes ONLY through managed markers — see `templates/idempotency.md`.

## Anti-patterns (do NOT do these)

- Writing to `ai/conventions.md` from one example. That's a sample size of 1.
- Logging the entire conversation as a "learning." Distill to the rule, not the discussion.
- Editing an existing ADR to "clarify." Decisions don't change retroactively.
- Adding a learning that contradicts an existing ADR without superseding it explicitly.

## Output format

```markdown
# Learnings from this task

## Promoted to formal

- [ADR 0042] Switched session store from in-memory → Redis
  - Reason: horizontal scaling broke without shared session
  - Path: ai/decisions/0042-session-store-redis.md

- [Convention] Use `Service` suffix for application-layer services
  - Examples: src/users/UserService.py, src/orders/OrderService.py
  - Path: ai/conventions.md (managed section "naming.service-suffix")

## Recorded in dynamic (not yet promoted)

- Observation: 2 places use TaskGroup vs gather; prefer TaskGroup
  - Status: 1/3 supporting examples; promote on next sighting

## Failure catalog entries

- [Failure] TypeORM @InjectRepository in V2 setup
  - Root cause: V2 uses Drizzle, not TypeORM
  - Don't retry: yes
  - Appended to: ai/failures/_index.md (§ Catalog) — one `### <date> — <label>` entry
```

Failure entries are appended to the single append-only catalog `ai/failures/_index.md` under `## Catalog`, using its documented per-entry format:

```markdown
### 2026-06-19 — TypeORM @InjectRepository in V2 setup
Source: <session ref / commit / PR / plan id>
Where: src/orders (V2 repository layer)

What was tried: wired @InjectRepository(Order) expecting a TypeORM data source
Why it failed: V2 uses Drizzle, not TypeORM — the decorator resolves to nothing
What to do instead: use the Drizzle repository pattern (see ai/patterns/drizzle-repo.md)

Status: ACTIVE (still a trap) | RESOLVED | SUPERSEDED
```

Never create per-file `ai/failures/<NNNN>-<slug>.md` entries — the baseline ships ONE append-only index.

## Implementation notes

- The command reads `templates/governance/hard-rules.md` (Always / Never) before promotion to avoid violations.
- Promotion checks `ai/failures/_index.md` — if a "promotion" is in fact a previously-failed approach, refuse and cite the failure entry.
- Idempotency: re-running on the same conversation produces no diff. Already-recorded learnings are skipped.

## Relation to the curator agent

- This command is **synchronous + scoped**: invoked by the user, runs once, on the current task. It writes the raw sinks (the Outputs table above).
- `knowledge-curator` is **manually-dispatched + sweeping**: invoked by the user (directly, or via `/audit-knowledge` / `/promote-pattern` / `/promote-decision`), scans the FULL sink set, promotes mature observations, prunes dead entries, regenerates compact derived files. It is NOT run by a hook or cron in the shipped baseline.

They share the same canonical sink set (see "Canonical sink set" above) and never conflict because:
1. This command writes ONLY the raw `ai/dynamic/` sinks + `ai/failures/_index.md` (append-only); the curator is the only writer of the formal layer.
2. The curator only promotes FROM those sinks, which are append-only.
3. Both respect ADR append-only.
4. Both regenerate (not edit) compact derived files (`_session-digest.md`, etc.).
