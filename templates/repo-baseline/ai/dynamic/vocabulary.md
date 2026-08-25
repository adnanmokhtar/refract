# Vocabulary (raw term sink)

Append-only sink for **terms this project uses in a sense the plain English reading would get wrong**, and for pairs of terms that look like synonyms and are not. Gathered during AI-assisted work; promoted by `knowledge-curator` into `ai/core/glossary.md § Vocabulary distinctions (don't conflate)` once a term has been seen **twice independently** and carries at least one `<file:line>` citation.

## Why this exists

`ai/core/glossary.md` is populated once, at `/setup-project`, from the detected business-domain pack. Nothing updated it afterwards — so the shared language froze on day one while the codebase kept inventing terms. Every agent that reads the glossary inherits that stale reading, and the cost compounds: a term nobody wrote down gets re-explained in twenty words every session, and two agents pick two different names for the same concept.

This sink is the missing first rung: `session-context → ai/dynamic/vocabulary.md → ai/core/glossary.md`.

## What belongs here — and what does not

**Log it** when:
- A term means something narrower, wider, or simply different from its ordinary reading (`materialize` here means "given a filesystem slot", not "computed").
- Two terms look interchangeable and are not (`cancel` vs `void`, `member` vs `user`, `draft` vs `unpublished`).
- The team says a word constantly and it appears in no document.

**Do NOT log**:
- Every domain noun. `ai/core/glossary.md § Core entities` already holds the entity inventory; a term that is just an entity name goes there, not here.
- Framework or language vocabulary that means what it means everywhere (`middleware`, `migration`, `hook`).
- A name you propose. This sink records language the project **already speaks**, not language you would like it to.

## Format per entry

```
### <YYYY-MM-DD> — <term>
Source: <session ref / commit / PR / user's own wording>
Seen: <count of INDEPENDENT sightings — different files or different sessions>

Means here: <the project-specific meaning, one sentence>
Does NOT mean: <the ordinary reading it gets confused with — or the sibling term it is not>
Cited at: <path:line>   ← required; an uncited term is not promotable

Status: RAW (1 sighting) | PROMOTE_CANDIDATE (2+) | PROMOTED → ai/core/glossary.md | DISCARDED
```

## Promotion threshold

- **2** independent sightings + ≥1 resolving `<file:line>` → `PROMOTE_CANDIDATE`.
- Two is deliberately lower than the 3 used for `learned-patterns.md`: a code shape needs a third occurrence to prove it is not coincidence, whereas a term either carries a project-specific meaning or it does not.
- `knowledge-curator` graduates candidates into `ai/core/glossary.md` and marks the entry `PROMOTED`.
- A term whose citation no longer resolves — the code renamed it — is `DISCARDED` with that reason, never promoted.

## Written by

- `commands/learn-from-task.md` — step 7b of the persistence pyramid.
- `.claude/agents/knowledge-curator.md` — reads this sink and promotes at threshold (§ 3b).

## See also

- `ai/core/glossary.md` — the promotion destination; entities in `## Core entities`, distinctions in `## Vocabulary distinctions`.
- `ai/dynamic/learnings.md` — raw observations about *how to work here* (→ `ai/conventions.md`). A term is not a convention; that is why this file exists separately.
- `ai/business-domain.md` — the domain classification + canonical flows the vocabulary describes.

## Log

_Empty until `/learn-from-task` appends or a human does. The presence of this file is the invitation._
