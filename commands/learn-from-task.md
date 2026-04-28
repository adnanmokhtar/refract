---
description: Phase 6 manual entry point. Promote concrete learnings from the just-completed task into the persistent knowledge layer (ADRs, conventions, patterns, failure catalog).
version: 1.0.0
related-commands:
  - /setup-project — initial setup
  - /setup-project-health — measures whether learning is happening
  - knowledge-curator agent — the recurring counterpart
---

# /learn-from-task

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
| `ai/_baseline/failures/<NNNN>-<slug>.md` | Approach we tried that did NOT work (failure entry) |
| `ai/dynamic/learnings.md` (append)       | Lower-confidence note; not yet promoted             |

## Promotion rules

This command DOES NOT publish raw observations to formal knowledge. It uses the persistence pyramid:

```
session-context     → ai/dynamic/learnings.md     (raw, append-only)
repeat 3x           → ai/conventions.md           (managed section)
explicit decision   → ai/decisions/<NNNN>-*.md   (ADR, append-only)
failed approach     → ai/_baseline/failures/     (don't-retry catalog)
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
  - Path: ai/_baseline/failures/0007-typeorm-inject-v2.md
```

## Implementation notes

- The command reads `templates/governance/hard-rules.md` (Always / Never) before promotion to avoid violations.
- Promotion checks `ai/_baseline/failures/_index.md` — if a "promotion" is in fact a previously-failed approach, refuse and cite the failure entry.
- Idempotency: re-running on the same conversation produces no diff. Already-recorded learnings are skipped.

## Relation to the curator agent

- This command is **synchronous + scoped**: invoked by the user, runs once, on the current task.
- `knowledge-curator` is **asynchronous + sweeping**: invoked by hooks/cron, scans `ai/dynamic/`, promotes mature observations, prunes dead entries, regenerates compact derived files.

Both write through the same managed markers. They never conflict because:
1. The curator only promotes from `ai/dynamic/`, which is append-only.
2. Both commands respect ADR append-only.
3. Both regenerate (not edit) compact derived files (`_session-digest.md`, etc.).
