---
description: /foo — a DIFFERENT artifact that happens to share the basename.
---

# /foo

The dir-precedence walk in check 8a reaches this file first. `_topics.md` says `kind: skill`,
so 8b must resolve `_examples/foo.md` against `skills/foo/SKILL.md` instead. If it does not,
every section and claim below reads as a mismatch and the fixture goes red.

## Arguments

`--all`, `--since <ref>`.

## Hard rules

- Never write outside `ai/foo/`.

## Output format

`ai/foo/<date>-run.md`.

## Failure modes

- Running with no `ai/` directory present.
