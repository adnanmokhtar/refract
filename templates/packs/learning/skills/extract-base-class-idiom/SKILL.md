---
name: extract-base-class-idiom
description: Walk a base class + its extenders to extract the project-specific protocol, configuration surface, automatic behaviors, escape hatches, and pitfalls. Output is a pattern file authored in the project's own voice (citing real paths, real extenders, real anti-patterns) — NOT a generic template. Used by /setup-project Phase 2.5 + Phase 4.2a to author ai/patterns/<base>.md from codebase reality instead of copying generic pack content.
---

# Skill: extract-base-class-idiom

## Purpose

Generic pack templates produce generic output. This skill produces project-specific pattern files by reading the actual base class + its extenders + their tests + their callers, then authoring the pattern in the project's voice.

The output should read like a senior engineer who has worked in this codebase for 6 months wrote it — citing real files, real extenders, real failure modes — not like a template that has had paths injected.

## Premise

- Real source is the truth. Read the base class file in full + every sampled extender in full + every cited collaborator before authoring a single section.
- Every method, property, hook, automatic behavior, escape hatch, and pitfall cites `<path:line>` from the actual class — not from an assumed protocol.
- Pitfalls cite a commit SHA, a line in `ai/failures/`, or an in-code `DON'T` / `HACK` comment — never "common mistakes" without evidence.
- Empty extraction is honest — omit the section per Step 7 instead of writing `_TBD_` or generic prose.
- Fabrication — citing a method that doesn't exist on the class, an extender count without a grep, a pitfall with no source — is the failure mode the per-section verifier rejects.

## Mechanical halt

- Hand-wave content — `use parameterized queries`, `follow framework conventions`, `your service layer`, generic `<EntityType>` placeholders, a pitfall without `<path:line>` or commit ref — REFUSE to write the section.
- Regenerate the section with concrete citations OR omit it (per Step 7's "no `_TBD_`" rule).
- If a base class genuinely has no automatic behaviors / no pitfalls / no escape hatches in code, record `<NOT-DETECTED: <reason>>` (e.g. `<NOT-DETECTED: thin wrapper, no overrideable hooks>`) and skip the section.
- Never synthesize a section to fill the 9-section template shape — the omission itself is the finding.

## When to use

- `/setup-project` Phase 2.5 — for every detected base class with ≥3 extenders.
- `/setup-project` Phase 4.2a (AUTHOR mode) — generating `ai/patterns/<base>.md`.
- On-demand by `/refresh-knowledge` when a base class evolves.
- Manually when adding a new pattern doc for a base class that doesn't have one.

## Inputs

- `base_class_path` — absolute path to the base class file (e.g., `libs/database/src/repository/data-access.ts`).
- `topic_spec` (optional) — `_topics.md` entry for this pattern; lists required sections. If absent, use the default 9-section template below.
- `output_path` — where to write the pattern (e.g., `ai/patterns/data-access.md`).

## Procedure

### Step 1 — Read the base class fully

Read the entire base class file. NEVER summarize without reading. Note:
- Class signature + generic type parameters (and what each represents).
- Public methods (the protocol — what extenders + callers can use).
- Protected methods (the override surface — what extenders customize).
- Properties that look like configuration (typed, defaulted, often arrays/maps).
- Lifecycle markers (constructor, `onModuleInit`, `afterInsert`, etc.).
- Automatic behaviors (anything happening inside the methods that callers don't have to ask for — auto-tenant filtering, auto-soft-delete, auto-audit, auto-cache, auto-translation merge).
- Escape hatches (methods that explicitly bypass the automatic behaviors, often named `*Raw`, `getBuilder`, `getRepository`, `withDeleted`, etc.).

### Step 2 — Find all extenders

```bash
grep -rln "extends <BaseClassName>" --include="*.ts" --include="*.py" --include="*.java" .
```

For each extender, note:
- Path.
- What configuration properties it sets (look for `static FOO = ...`, `get foo(): ... { return ... }`, etc.).
- What protected methods it overrides.
- What it adds beyond the base.

### Step 3 — Sample 3-5 representative extenders deeply

Pick extenders that span the range:
- Smallest extender (least overrides) → shows the minimum-viable shape.
- Most-overridden extender → shows the maximum-customization shape.
- One with a non-obvious override (e.g., overrides a hook the others ignore) → shows edge cases.

Read each in full. Note configuration values, override bodies, comments explaining WHY.

**Record the denominator, not just the sample.** Note the total extender count found by the caller's grep (`extract-codebase-overview § Step 5` already has it) and carry it through to the output as `<N> of <M> extenders`. "3 extenders sampled" and "3 of 4" and "3 of 273" are three different claims and the first is indistinguishable from the other two. Any statement in the authored pattern that generalizes across extenders ("every subclass sets `X`", "no extender overrides `Y`") rests on the sample, not the population, and is written `[inferred: <basis>; sampled <N>/<M> extenders]` per `phase-2-profile.md § Provenance discipline` — the same rule that governs sampled sections of `_extracted-codebase.md`.

### Step 3.5 — Recursive extraction of cited collaborators (NEW)

The base class almost always references other classes that are themselves part of its protocol — interfaces it consumes, helper classes it composes, criteria/factory/strategy classes its callers must implement. These collaborators are part of the pattern; documenting the base in isolation leaves a gap.

For every type the base class imports + uses in its public/protected signature (NOT every transitive dep — just the ones a caller would need to know about):

1. Read the collaborator file.
2. If it's an interface: extract the contract (methods + types) + 1-2 real implementations.
3. If it's a concrete class: extract its public surface + how the base calls it.
4. **Decide: inline or sibling pattern?**
   - **Inline** in the main pattern doc when the collaborator is small (<50 lines), used in 1-2 places, conceptually part of the base.
   - **Sibling pattern file** (`ai/patterns/<collaborator>.md`) when the collaborator has its own extenders, is referenced from multiple base classes, or is large enough to deserve its own doc. Schedule the sibling extraction after the main one.

For the main pattern doc, always include a "Collaborators documented separately" section linking siblings.

Heuristic for "needs its own pattern doc": collaborator has 3+ implementations OR is referenced by 2+ base classes OR is >100 lines.

### Step 4 — Identify automatic behaviors + their bypass

For each automatic behavior found in Step 1:
- WHAT does it do? (one sentence)
- WHERE in the base class is it implemented? (file:line)
- HOW do you opt out / bypass? (named method, flag parameter, decorator, etc.)
- WHEN should you bypass? (legitimate use cases — usually documented in code comments or visible in 1-2 extenders that bypass)
- WHEN should you NEVER bypass? (the failure mode — what breaks when you skip the auto-behavior)

### Step 5 — Find pitfalls from the codebase

Look for evidence of past mistakes:
- `git log --all -S "<base class name>"` for commits that fixed misuse.
- Comments containing "DON'T", "NEVER", "TODO", "HACK", "WORKAROUND" in the base class file.
- Tests with names like "should not allow X" or "regression test for Y".
- Custom rules in `.claude/rules/` mentioning the base class.
- Existing entries in `ai/dynamic/feedback-learned.md` or `ai/failures/` that reference this base.
- Memory files (`~/.claude/projects/<project>/memory/*.md`) referencing the base.

### Step 5.5 — Mirror existing pattern shape if present (NEW)

In ENHANCE / REFRESH mode, an `ai/patterns/<base>.md` may already exist. Before authoring, READ it.

- Capture its section ORDER (e.g., "Overview → Type Parameters → Key Methods → Automatic Filtering → Criteria System → ...").
- Capture its section NAMES verbatim (the existing voice — "Key Methods" vs "Public Protocol" vs "API Surface" — pick the one already in use).
- Capture its level of formality (table-heavy? prose? code-example-heavy?).

Author the new content INSIDE the existing skeleton:
- Keep every existing section name + order.
- Update existing section content with extracted facts (citing real file:line).
- ADD new sections only when extraction surfaced content the existing doc has no place for (e.g., a "Pitfalls" section the original lacked). Place them at the END unless they're correcting a critical gap mid-flow (e.g., automatic-behaviors deserves to be near the top).
- NEVER reorder existing sections without an explicit reason in the output footer (e.g., "Reordered: moved 'Pitfalls' to position 4 because deprecated APIs are critical to surface early").

In CREATE mode (no existing pattern doc) OR if the existing one is a stub (<30 lines), use the default 9-section structure from Step 6.

### Step 6 — Author the pattern (the output)

Use this 9-section structure (or match `topic_spec` if provided, or match existing shape per Step 5.5):

```markdown
# <BaseName><GenericParams> Pattern

## Overview

<One paragraph: what this base does + where it lives + how many extenders, and how many of those were read (`<N> of <M> sampled`). Cite the file:line.>

## Type parameters
| Param | Represents |
| `Entity` | TypeORM ORM entity class |
| ...     | ...

## Configuration surface (override these in your subclass)

| Property | Type | Default | Purpose |
| `uniquenessFields` | `string[]` | `[]` | Fields validated for uniqueness on save |
| ... | ... | ... | ... |

## The protocol — public methods extenders + callers use

| Method | Purpose | Returns |
| `find(criteriaName?)` | Standard list with criteria | `T[]` |
| ... | ... | ... |

## Override hooks — protected methods you can customize

| Method | When called | Default behavior | Override when |
| `customValidation(dto)` | After uniqueness check, before save | no-op | Adding business rules beyond uniqueness |
| ... | ... | ... | ... |

## Automatic behaviors (the base does this for you — DON'T re-implement)

1. **<Behavior name>** (`<file:line>`)
   - Does: <one sentence>
   - Bypass: <method name + when legitimate>
   - Never bypass when: <the failure mode>

## Escape hatches (when you genuinely need to skip the base)

- `getBuilder(alias)` — raw `SelectQueryBuilder` access. Use when criteria system can't express the query. Tenant + soft-delete are NOT auto-applied; you MUST add them manually.
- ...

## Examples from this codebase

- **Smallest extender**: `<path>` — only sets `uniquenessFields`.
- **Most customized**: `<path>` — overrides 4 hooks; see for a heavy-customization template.
- **Non-obvious override**: `<path>` — uses `<hook>` to <reason>.

## Pitfalls observed in this codebase

- ❌ Calling `dataSource.getRepository()` directly — bypasses tenant + soft-delete filters. Found in `<file:line>` (since fixed). Use `this.getRepository()` from base.
- ❌ ...

## When NOT to use this base

- <Cases where a different base class or pattern is correct.>

## Related patterns + ADRs
- `ai/patterns/<related>.md`
- `ai/decisions/<NNNN>-<related>.md`
```

### Step 7 — Verify the output

Before writing, check:
- Every method/property cited exists in the actual file (no hallucinations).
- Every example file path exists.
- Every pitfall has evidence (file:line or commit reference) — no "common mistakes" without a source.
- No generic prose ("use parameterized queries" without project context).
- No section is empty — if a section genuinely has no content for this base, OMIT the section, don't write `_TBD_`.

If any check fails, regenerate the offending section. If still failing after 1 retry, leave the section out + note in skill output: "section X omitted — no extractable signal."

## Output

Write the pattern file to `output_path`. Print a one-line summary:

```
Authored <output_path>: <N> of <M> extenders sampled, <A> automatic behaviors, <P> pitfalls cited, <Q> escape hatches.
```

## Failure modes

- **Base class is generic + project doesn't actually use it (0-2 extenders)** → don't write a pattern; not enough signal. Report and exit.
- **Base class is huge (>2000 lines) + most code is implementation, not protocol** → focus extraction on the public + protected method signatures + property types; skip implementation walk.
- **Extenders all look identical (cookie-cutter)** → reduces value of "Examples from this codebase" section; pick just 1 and note "all extenders follow this same minimal shape."
- **Base class has no automatic behaviors (it's just a thin wrapper)** → omit the "Automatic behaviors" section entirely; this base may not deserve a pattern doc.

## Quality bar

The output must satisfy: **a senior engineer reading this pattern + the base class file should be able to write a new conforming extender without asking any questions.** If they'd still need to grep around to figure out conventions, the pattern is incomplete.
