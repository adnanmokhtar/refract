---
description: Locate a module, feature, or concept across the codebase quickly.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /find-module <name|concept>

Parallel search across directory names, filenames, identifiers, and string usage. Reports primary location plus related files and registration status.

## The Premise (read this first, internalize, do not deviate)

**Existing module map is the truth. Don't invent paths; cite real ones.** The repo already has a shape — directories, registration files (`ai/modules.md`, framework module manifests, package roots). Every answer this command emits is a citation of something that exists on disk OR an honest "not found" with a conventions-based suggestion clearly labelled as a suggestion.

**The closure verb is `cite-or-halt`.** Each result row is one of:
- `cite` — `<path>` exists on disk, confirmed by `ls` / `find` / `rg`.
- `not-found-suggest` — no match; emit a conventions-based suggested location, label it `(suggested, not yet present)`.
- `halt` — query is a common noun without qualifier, or the module map disagrees with disk reality. Refuse to answer; surface the ambiguity.

**Forbidden:**
- Inventing a plausible-looking path the agent did not verify (e.g., `<modules-root>/<name>/` "should be there" without checking).
- Reporting a `cite` row when the path was not actually listed by a tool call.
- Silently merging "suggested" and "found" into the same bucket.
- Answering on a common-noun query (`user`, `order`, `item`) without a qualifier.

**Mechanical halt — refuse to invent paths; cite or halt:** every emitted path MUST trace to a tool-call result in this run. If the agent cannot produce a `cite` and cannot honestly suggest from siblings, it halts and asks for synonyms or a qualifier. No fabricated paths, ever.

**Lightweight default.** This is a DIAGNOSTIC, read-only command — no edits, no agent dispatch, no ceremony. Four parallel greps + one `ai/modules.md` read + one clustered output. If the answer needs more than that (cross-repo, multi-monorepo, alias glossary), surface the limit; do not expand scope mid-run.

## Phases applied

DIAGNOSTIC type — 1, 2, 3 dominate. No Generate/Update/Validate/Improve unless the search reveals stale `ai/modules.md` (then a one-line update).

## When to use / NOT to use
- USE: onboarding to an unfamiliar repo; pre-flight before editing — find every place a concept lives; searching for the right module to extend instead of creating a new one.
- NOT: name is a common noun without qualifier (`/find-module user`) — too many false matches.

## Phase 1 — Understand

- Parse `<name|concept>`.
- If common noun (`user`, `order`, `item`), suggest qualifier and ask.
- Success: primary location named OR "not found" with conventions-based suggestion of where it would live.

## Phase 2 — Organize

- Plan 4 parallel searches (Phase 3).
- Decide scoring shape (path match > identifier match > string match).

## Phase 3 — Retrieve (the searches)

Parallel:
- **Directory match** — `find . -type d -iname "*<name>*"` excluding dependency caches (`node_modules`, `vendor`, `.venv`, `target`, etc.) and build outputs (`dist`, `build`, `out`, etc.) and `.git`.
- **Filename match** — `find . -type f -iname "*<name>*"` with same exclusions.
- **Identifier match** — `rg -n "(class|interface|type|function|const|enum)\s+<Name>"`.
- **String reference** — `rg -nF "<name>"` (literal) for i18n keys / config / comments.

Read `ai/modules.md` (if present) for registration status + canonical owner.

Rank (an ORDER, not a score — the numbers this used to print were invented, and a fabricated
weight is exactly what this command's own `cite-or-halt` verb exists to forbid):

1. **Exact directory or file name match** — the module is named for the concept. Strongest signal by a wide margin.
2. **Identifier defined** — a `class` / `type` / `function` / `enum` declaration of the name. This is where the concept *lives*, even when the path does not say so.
3. **Substring in path with matching casing** — same concept, different naming convention.
4. **String / literal reference** — i18n keys, config, comments. Tells you who *talks about* the concept, not where it is implemented.

Where two candidates tie, break by **`ai/modules.md` registration** (a registered owner outranks an unregistered file) and then by import count (the most-imported definition is the canonical one). If nothing separates them, say so and list both — a confident single answer picked at random is worse than an honest pair.

Cluster results: primary module / related modules / DB layer / tests.

If primary not found, read 1-2 sibling modules to infer convention, suggest where it WOULD live (the project's actual module-shape, per `_extracted-codebase.md § Top-level layout`).

## Phase 4 — Generate (the report)

Format the clustered results (see Output).

## Phase 5 — Update (only if drift detected)

- If `ai/modules.md` claims registration but directory absent (or vice versa), queue a one-line correction to `ai/dynamic/drift-log.md`. No auto-edit.

## Phase 6 — Validate

- Cross-check: `ai/modules.md` says registered — does the directory exist?
- For "not found" verdict: ask user for synonyms (concept aliases — "subscription" might be "membership" or "plan") before declaring final.

## Phase 7 — N/A

Pure read; no learning hook. (If repeated "not found" on same query reveals a missing alias glossary, that's a `/refresh-knowledge` job.)

## Output (found)

```
Query: subscription

Primary:
  <modules-root>/subscriptions/         14 files
  Registered in ai/modules.md: yes

Related:
  <shared-root>/guards/subscription-active.<ext>
  <modules-root>/billing/                references subscription tier in 4 files

Database:
  <migrations-root>/20250310-subscriptions/migration.sql
  <modules-root>/subscriptions/infrastructure/persistence/subscription.orm-entity.<ext>

Tests:
  <modules-root>/subscriptions/**/*.<test-ext>   18 files
  e2e/subscriptions.e2e-spec.<test-ext>       1 file

Sibling modules (similar shape, useful for new code):
  <modules-root>/orders/        — same module structure
  <modules-root>/invoices/      — same module structure
```

## Output (not found)

```
Query: refunds

No matching module.

Suggested location based on conventions:
  <modules-root>/refunds/
    core/
    application/
    infrastructure/
    refunds.module.<ext>

Related concepts already in repo:
  <modules-root>/orders/  (refund logic might attach here — confirm domain ownership before deciding)
```

## Failure modes

- Common noun matches dominate (`user`, `order`, `item`) — require a qualifier.
- `node_modules` / `vendor` matches dominate raw greps — always exclude.
- `ai/modules.md` lies (file moved without doc update) — cross-check directory existence.
- Concept aliases ("subscription" → "membership") — ask for synonyms before declaring not-found.
- Tests in monorepos can live far from source (`tests/` at repo root) — don't conclude "no tests" without checking.
- Speed budget < 10s — fall back to `grep -r` if `rg` absent, but flag the slowness.

## Related

### The boundary this command owns

**Read-only location lookup, and nothing else.** Four parallel searches plus one `ai/modules.md` read, answering "where does this concept live". It dispatches no agent, writes no file, and forms no opinion about the code it finds.

**Anti-triggers:**
- *"…and tell me what's wrong with it"* → `/review-changes` (a diff), `/check-health` (the repo), or `/audit` (global, ranked at scale).
- *"…and clean it up"* → `/simplify` or `/optimize` (global).
- A common noun with no qualifier (`user`, `order`, `item`) → halt and ask; the match set is noise.
- Cross-repo or multi-monorepo lookup → out of scope; say so rather than partially answering.

### Sibling commands in code-quality pack
- `/review-changes`, `/check-health`, `/pre-commit` — all of them assume you already know which module you are looking at. This is the step before.
- `/simplify` — its "is there already a helper for this?" question is this command's search, run for a different reason.

### Rules
- `.claude/rules/engineering-principles.md`
- `.claude/rules/quality-principles.md`
