---
description: Phase 6 manual entry point. Promote concrete learnings from the just-completed task into the persistent knowledge layer (ADRs, conventions, patterns, failure catalog).
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
3. **Refuse promotion to conventions on sample size of 1**: convention rows REQUIRE ≥2 cited example files. One example → goes to `ai/dynamic/learnings.md`, not `ai/conventions.md`.
4. **Refuse to edit existing ADRs**: ADRs are append-only. Supersede with a new ADR; never mutate.
5. **Refuse to write a learning that contradicts an accepted ADR** without explicit supersession: cite the ADR being overturned, write a new ADR, then proceed.
6. **Refuse re-recording**: if the observation already exists in dynamic / conventions / ADRs / failures (text match or paraphrase match), no-op. Re-running the command produces no diff.

The learning loop's manual handle. Run after a non-trivial task to convert raw conversation context into durable knowledge.

## When to run

- A correction landed ("don't use X here, use Y because Z").
- A subtle convention emerged from the diff that wasn't documented.
- A failed approach should be cataloged so future agents don't retry it.
- A decision was made that future readers need to understand.

The recurring counterpart is the `knowledge-curator` agent (auto-invoked via post-task hook + weekly cron). This command is the manual fallback.

## Inputs

- The current conversation context (the task that just finished).
- Optional: a specific commit range (`--since <ref>`) to scope the analysis.

## Outputs (zero, one, or more of)

| Output target                            | Trigger                                             |
|------------------------------------------|-----------------------------------------------------|
| `ai/decisions/<NNNN>-<slug>.md`          | Architectural decision (append-only ADR)            |
| `ai/conventions.md` (managed section)    | New convention with ≥2 supporting examples          |
| `ai/patterns/<name>.md`                  | Reusable pattern across modules                     |
| `ai/failures/<NNNN>-<slug>.md` | Approach we tried that did NOT work (failure entry) |
| `ai/dynamic/learnings.md` (append)       | Lower-confidence note; not yet promoted             |

## Promotion rules

This command DOES NOT publish raw observations to formal knowledge. It uses the persistence pyramid:

```
session-context     → ai/dynamic/learnings.md     (raw, append-only)
repeat 3x           → ai/conventions.md           (managed section)
explicit decision   → ai/decisions/<NNNN>-*.md   (ADR, append-only)
failed approach     → ai/failures/     (don't-retry catalog)
```

A learning surfaced once goes to dynamic. Same observation 3 times = promote to formal. The pyramid prevents premature codification of one-offs.

## Hard rules (inherits from `templates/governance/hard-rules.md`)

- ADRs are append-only — never edit an existing one. Supersede with a new ADR that references the old.
- Failure catalog entries cite the failed approach + root cause + the alternative that worked. No editorializing.
- Convention promotions require ≥2 example files cited in the rule's RATIONALE.
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

- [Failure 0007] TypeORM @InjectRepository in V2 setup
  - Root cause: V2 uses Drizzle, not TypeORM
  - Don't retry: yes
  - Path: ai/failures/0007-typeorm-inject-v2.md
```

## Implementation notes

- The command reads `templates/governance/hard-rules.md` (Always / Never) before promotion to avoid violations.
- Promotion checks `ai/failures/_index.md` — if a "promotion" is in fact a previously-failed approach, refuse and cite the failure entry.
- Idempotency: re-running on the same conversation produces no diff. Already-recorded learnings are skipped.

## Relation to the curator agent

- This command is **synchronous + scoped**: invoked by the user, runs once, on the current task.
- `knowledge-curator` is **asynchronous + sweeping**: invoked by hooks/cron, scans `ai/dynamic/`, promotes mature observations, prunes dead entries, regenerates compact derived files.

Both write through the same managed markers. They never conflict because:
1. The curator only promotes from `ai/dynamic/`, which is append-only.
2. Both commands respect ADR append-only.
3. Both regenerate (not edit) compact derived files (`_session-digest.md`, etc.).
