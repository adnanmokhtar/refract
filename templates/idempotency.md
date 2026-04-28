---
artifact: idempotency-contract
purpose: Define what a re-run of /setup-project preserves, merges, regenerates, and never touches. Without this contract, every re-run is a destructive lottery.
imported-by: commands/setup-project.md (orchestrator), Phase 4 (Apply), Phase 5 (Verify).
---

# Idempotency contract

A second invocation of `/setup-project` on the same repo MUST be safe. "Safe" is defined precisely below — by file class, by section, and by marker.

## Per-file class

| File class                              | Behavior on re-run                                                       |
|-----------------------------------------|--------------------------------------------------------------------------|
| `CLAUDE.md`                             | **Merged** — managed blocks regenerated, user blocks preserved (markers) |
| `ai/conventions.md`                     | **Merged** — managed sections regenerated; user-added sections preserved |
| `ai/_session-digest.md`                 | **Regenerated** — derived projection; never hand-edited                  |
| `ai/_convention-cheatsheet.md`          | **Regenerated** — derived from conventions.md                            |
| `ai/_decision-index.md`                 | **Regenerated** — derived from ai/decisions/*.md                         |
| `ai/decisions/<NNNN>-*.md` (ADRs)       | **Append-only** — never touched after creation                           |
| `ai/patterns/<name>.md`                 | **Merged** — header regenerated; body preserved unless --force-overwrite |
| `ai/runbooks/`, `ai/audits/`, `ai/runtime/` | **Append-only**                                                      |
| `.claude/rules/<name>.md`               | **Merged** — managed rules regenerated; user-added rules preserved       |
| `.claude/commands/<name>.md`            | **Replaced** if managed (marker present); skipped if user-added          |
| `.claude/agents/<name>.md`              | **Replaced** if managed; skipped if user-added                           |
| `.claude/hooks/<name>`                  | **Replaced** if managed; skipped if user-added                           |
| `.claude/settings.json`                 | **Never touched** — user-managed                                         |
| `.claude/settings.local.json`           | **Never touched** — per-machine override; the escape hatch               |

## Markers

Generated content is bracketed by HTML comments so a re-run can find and replace its own output without disturbing user edits.

```markdown
<!-- setup-project:managed start id=<artifact-id> v=<version> -->
... regenerated content here ...
<!-- setup-project:managed end -->
```

Outside any `setup-project:managed` block, content is treated as user-authored and is preserved verbatim.

For files where comment syntax differs (JSON, YAML, etc.), use the language's native comment form OR — if the format has none — keep a sibling `<file>.managed` lock-file with a hash of the last managed value; re-run only overwrites if the hash matches.

## Section-level merge

Within a managed file, sections are identified by heading + an optional `id`:

```markdown
## Stack: web-backend-django <!-- setup-project:section id=stack-web-backend-django -->
```

A re-run replaces the body of a managed section in place. New managed sections append at the end of their parent block. User-added sections (no marker) stay where they are.

## ADR rule

ADRs (`ai/decisions/<NNNN>-*.md`) are **append-only**. The command never edits an existing ADR. Mistakes are corrected by a follow-up ADR that references and supersedes the older one.

## Versioning interaction

Generated artifacts include the producing version in their managed marker (`v=2.0.0`). On re-run:

- Same version → in-place replacement, byte-stable when inputs unchanged.
- Newer version + matching migration in `templates/migrations/` → migrate first, then replace.
- Newer version + no migration → emit a warning, leave content alone, surface in the report.

## Verification

Phase 5 enforces idempotency by re-running the command in dry-run mode against its own just-written output and confirming an empty diff. A non-empty diff = bug.

## Anti-patterns (do NOT do these)

- Writing to a managed file without a marker — future re-runs cannot find the block to replace.
- Editing inside someone else's marker — markers belong to one and only one artifact-id.
- Treating all of CLAUDE.md as managed — half the file is the user's project notes.
- Regenerating ADRs — they are decisions, not output.
