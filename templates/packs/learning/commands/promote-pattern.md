---
description: Graduates an emerging pattern from ai/dynamic/learned-patterns.md to a formal ai/patterns/<name>.md with full structure.
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

Draft the pattern inline first, then surface for one-shot user edit. Do NOT pause for approval before drafting. The user reviews the draft, not the proposal-to-draft.

Plan the steps:
1. Locate the source entry in `learned-patterns.md`.
2. Verify promotion criteria (status + occurrences + lifespan).
3. Dispatch `knowledge-curator` agent to draft the formal file inline (no pre-draft confirmation).
4. Surface the completed draft for one-shot user edit.
5. Write the file + update the source entry + log.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

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
3. Show draft to user. **Pause for approval.**
4. On approval: write `ai/patterns/<name>.md` with the draft.

## Phase 5 — Update (persist changes to the knowledge base)

- Update entry in `ai/dynamic/learned-patterns.md` to `PROMOTED → ai/patterns/<name>.md`.
- Append to `ai/dynamic/changelog.md`: "Pattern promoted: <name>".
- If the pattern affects an existing rule, propose updating the rule (separate flow — ask user).
- If a new ADR is warranted (deliberate trade-off chosen with alternatives), queue to `ai/dynamic/decisions-pending.md`.

## Phase 6 — Validate (verify correctness)

- File exists at `ai/patterns/<name>.md` and renders.
- All template sections present (Context, Structure, Example, Trade-offs, Common mistakes, Testing, References).
- No placeholder text (`<TODO>`, `<name>`, `{{}}`).
- Source entry status updated to PROMOTED with the destination path.
- changelog.md entry appended.

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
