# tests/setup-project/snapshots/

Expected outputs of `/setup-project` for each fixture in `../fixtures/`. Populated in M2.

A snapshot directory mirrors the artifact tree the command writes to a target repo:

```
snapshots/<fixture>/
  CLAUDE.md
  ai/
    _session-digest.md
    _convention-cheatsheet.md
    conventions.md
    decisions/
    patterns/
  .claude/
    rules/
    commands/
    agents/
```

`run.sh --update-snapshots` (M3) regenerates these from a real run; reviewers diff the changes in PRs.
