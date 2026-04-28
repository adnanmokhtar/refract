# templates/migrations/

Notes for upgrading repos that were set up by an older version of `/setup-project`.

## Why

Generated artifacts (CLAUDE.md, ai/, .claude/) carry a `setup-project: vN` marker. When the command's contract changes (file layout, frontmatter, idempotency markers), this directory holds the migration script + notes.

## Layout

```
templates/migrations/
  v1-to-v2.md   ← human-readable: what changed, what to expect
  v1-to-v2.sh   ← optional automated migrator (run by /setup-project --upgrade)
```

## Contract

- Migrations are append-only. Once shipped, never edit a past migration in place.
- `/setup-project --upgrade` reads the version marker in the target repo, then runs each migration in sequence.
- Migrations MUST be idempotent: running twice on the same repo is a no-op the second time.

Populated as needed from Milestone 2 onward.
