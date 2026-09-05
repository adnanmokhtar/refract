---
description: Graduates an emerging pattern from ai/dynamic/learned-patterns.md to a formal ai/patterns/<name>.md with full structure.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /promote-pattern <name>

Used when a pattern in `ai/dynamic/learned-patterns.md` has reached `READY` status (3+ occurrences, 2+ weeks held up). Writes a formal pattern file that becomes part of the project's authoritative knowledge base.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## When to use / NOT to use

- USE: an entry in `learned-patterns.md` shows status `READY`.
- USE: a code shape repeats across 3+ modules and you want it codified before the 4th repetition diverges.
- USE: after a successful spike where the spike's approach proved durable.
- NOT: for one-off shapes (use Rule of Three: wait for the third occurrence before formalizing).
- NOT: for framework-default patterns (the framework's default module / component / unit-of-composition — whatever the stack provides — those are stack-given, not project-emergent).
- NOT: for patterns that contradict an existing formal pattern (resolve the contradiction first; don't have two competing patterns).

## Phase 1 — Understand (the ask)

- Parse the `<name>` argument. If absent, ask the user for the candidate pattern name.
- Confirm intent: this WILL write a formal pattern file and mutate `learned-patterns.md`. Not a dry-run.
- State the success criteria: a new `ai/patterns/<name>.md` exists with all required sections; the source entry is marked PROMOTED.

## Phase 2 — Organize (decompose the work)

ONE approval gate, and it is AFTER the draft. Draft the pattern inline first, then pause once for the user to approve/edit the completed draft (Phase 4 step 3). Do NOT pause before drafting to ask "may I draft?" — the user reviews the draft, not the proposal-to-draft. (This is the same single gate Phase 4 enforces; there is no second, earlier gate.)

Plan the steps:
1. Locate the source entry in `learned-patterns.md`.
2. Verify promotion criteria (status + occurrences + lifespan).
3. Dispatch `knowledge-curator` agent to draft the formal file inline (no pre-draft confirmation).
4. Surface the completed draft for one-shot user edit.
5. Write the file + update the source entry + log.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

PATTERN-SPECIFIC:
- `ai/dynamic/learned-patterns.md` for the entry matching `<name>`. If absent, refuse + suggest adding via `pattern-emergence-watcher`.
- Existing `ai/patterns/*.md` for shape consistency (header style, section order).
- Each occurrence file referenced in the entry — verify the shape is real and consistent.

## Phase 4 — Generate (produce the output)

1. Verify status is `READY` (or `WATCHING` with ≥3 occurrences + ≥2 weeks lifespan). If not, refuse + report current status.
2. Invoke `knowledge-curator` agent to draft the formal pattern file. The draft uses the standard pattern template:
   ```markdown
   # Pattern: <Name>

   <one paragraph: what + when + what problem it solves>

   ## Context
   <signals saying "use this here">

   ## Structure
   <diagram or text walkthrough>

   ## Example
   ```ts
   // pulled from one of the occurrences
   ```

   ## Variants
   <if there are 2-3 ways the pattern bends>

   ## Trade-offs
   <pros, cons, when NOT to use>

   ## Common mistakes
   <traps when implementing this pattern>

   ## Testing
   <how to test code using it>

   ## References
   <links to occurrence files; related ADRs / rules>
   ```
3. Show draft to user. **Pause for approval — this is the ONE and only approval gate** (Phase 2 deliberately skips a pre-draft gate so the user reviews real content, not a promise).
4. On approval: write `ai/patterns/<name>.md` with the draft.

## Phase 5 — Update (persist changes to the knowledge base)

- Update entry in `ai/dynamic/learned-patterns.md` to `PROMOTED → ai/patterns/<name>.md`.
- Append to `ai/dynamic/changelog.md`: "Pattern promoted: <name>".
- Regenerate the Tier-1 derived files via `knowledge-curator § 8` — `ai/_session-digest.md` § "Patterns currently emerging" is sourced from `learned-patterns.md` status `WATCHING`, so until it regenerates the digest every session auto-loads still advertises this pattern as un-formalized.
- If the pattern affects an existing rule, propose updating the rule (separate flow — ask user).
- If a new ADR is warranted (deliberate trade-off chosen with alternatives), queue to `ai/dynamic/decisions-pending.md`.

## Phase 6 — Validate (verify correctness)

Do NOT report success on assertion. HALT unless every check below passes — the same bar
`/promote-decision` Phase 6 sets, because the failure is the same: a half-promoted entry now exists
in two places and they will drift.

- **File exists** at `ai/patterns/<name>.md` and renders.
- **Required sections present**: Context, Structure, Example, Trade-offs, Common mistakes, Testing, References.
- **No placeholder / TODO text** (`<TODO>`, `<name>`, `{{}}`) remains in the authored file.
- **Source entry updated, by grep** — `grep` `ai/dynamic/learned-patterns.md` for `<name>`: it MUST
  resolve exactly once and that line MUST read `PROMOTED → ai/patterns/<name>.md`. A `WATCHING`
  entry surviving beside the formal file is the orphaned original; halt.
- **changelog.md entry appended** — grep confirms the "Pattern promoted: `<name>`" line, exactly once.
- **Digest regenerated** — `ai/_session-digest.md` § "Patterns currently emerging" no longer lists
  `<name>` (it is formal now). A digest still advertising it as emerging is `knowledge-curator § 8`
  not having run; re-run it rather than editing the derived file by hand.

## Phase 7 — Improve (feed the learning loop)

- Run `/learn-from-task` to capture: which pattern was promoted, which rule it might affect, follow-ups (rule update, ADR).
- If the user requested edits to the draft → append the correction to `ai/dynamic/feedback-learned.md` so future drafts mirror their style.
- If pattern promotion revealed gaps in `pattern-emergence-watcher`'s detection (e.g., it missed an obvious occurrence) → log to `ai/dynamic/drift-log.md`.

## Output

```
## /promote-pattern auth-token-rotation

Phase 1 (Understand): promote 'auth-token-rotation' from learned-patterns to formal patterns.
Phase 2 (Organize): locate → verify → draft → approve → write → log.
Phase 3 (Retrieved): learned-patterns.md, 4 occurrence files, 2 sibling pattern files for shape.
Phase 4 (Generated): ai/patterns/auth-token-rotation.md (draft pending approval).

Source entry: ai/dynamic/learned-patterns.md (status READY, 4 occurrences)

Preview:
---
# Pattern: Auth Token Rotation
...
[draft contents]
---

Promote? [y/n] (y writes the file + marks entry PROMOTED)

After approval:
Phase 5 (Updated): learned-patterns.md (PROMOTED), changelog.md (+1 line).
Phase 6 (Validated): file renders, all sections present, no placeholders.
Phase 7 (Improved): /learn-from-task queued.

Suggestions:
- Update `.claude/rules/auth.md` to reference this pattern as the canonical implementation.
- Consider an ADR if the rotation strategy was a deliberate choice with alternatives considered.

Status: COMPLETE
```

## Failure modes

- **Pattern is too generic**: refuse + ask user to scope tighter (e.g., "auth pattern" → "JWT rotation with refresh token replay detection").
- **Pattern conflicts with existing**: refuse + show the conflict; user resolves by either updating existing OR explicitly superseding it (rare).
- **Insufficient occurrences**: refuse + report current count; suggest waiting OR proactively check for missed occurrences.
- **Source entry not found**: refuse + suggest running `pattern-emergence-watcher` first.

## See also

- `/learn-from-task` — how patterns enter `learned-patterns.md`.
- `pattern-emergence-watcher` agent — populates `learned-patterns.md`.
- `knowledge-curator` agent — drafts the formal pattern file.
- `ai/patterns/` — destination.

## Related

### Sibling commands in learning pack
- `/detect-drift` — sibling command in learning pack
- `/learn-from-task` — sibling command in learning pack
- `/refresh-knowledge` — sibling command in learning pack

### Patterns
- `ai/patterns/setup-quality-scoring.md`
