# tests/setup-project/

Snapshot-style fixture tests for the `/setup-project` command.

## Why

Refactors of the orchestrator (M2 split, M3 polish) are only safe if we can detect regressions. Before this scaffold there was no way to assert "the same input still produces the same output."

## Layout

```
tests/setup-project/
  fixtures/         ← input repos, one per scenario
    empty/          ← bare directory; tests new-project mode
    django/         ← Django/DRF skeleton
    nextjs/         ← Next.js + Tailwind skeleton
    monorepo/       ← mixed: backend + frontend in subdirs
  snapshots/        ← expected outputs, one dir per fixture
    empty/
    django/
    nextjs/
    monorepo/
  run.sh            ← (M3) drives the command, diffs against snapshot
```

## Contract

- **Fixtures are inputs only.** Their contents represent the state of a target repo BEFORE `/setup-project` runs.
- **Snapshots are outputs.** They contain the exact files `/setup-project` is expected to write under `CLAUDE.md`, `ai/`, `.claude/` for that fixture.
- **Snapshots are append-only across versions.** When the command's output changes intentionally, regenerate via `run.sh --update-snapshots` and review the diff in the PR.

## Status

- M1: directory scaffold + fixture stubs (this commit).
- M2: each fixture populated with realistic source files; first snapshots captured.
- M3: `run.sh` driver lands; CI gate added.

## How fixtures get populated (M2)

Each fixture must be:

- Realistic enough to trigger the relevant track's detection signals.
- Small enough to commit (no real `node_modules`, no real virtualenvs).
- Self-contained (no external network calls during test).

A fixture is "complete" when:

1. Running `/setup-project --dry-run` against it lists the expected tracks.
2. Running `/setup-project` against a copy produces the snapshot byte-for-byte.
3. Running `/setup-project` a second time on the same copy produces NO diff (idempotency).
