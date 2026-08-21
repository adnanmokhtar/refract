---
description: /bar — the command the fallback next to it declares itself a literal copy of.
generated-from: templates/packs/p/commands/bar.md
---
<!-- Faithful seed copy. REGENERATE whenever the command changes. Do not hand-edit; edit the command and re-copy. -->

# /bar

Run the bar sweep over the current diff. Smaller than `/foo`, deeper than reading the log by hand.

## Pre-flight

- `ai/bar/` exists, or create it.
- The working tree is committed, or the run is aborted.

## Hard rules

- Never write outside `ai/bar/`.
- One finding per row. A row with no `<path:line>` is deleted, not softened.

## Procedure

1. Collect the diff.
2. Classify each hunk.
3. Rank by blast radius.
4. Write the report.

## Output

`ai/bar/<date>-run.md`, with a table:

| finding | path:line | severity | fix |
|---|---|---|---|

## Failure modes

- Running with no `ai/` directory present.
- Ranking by hunk count instead of blast radius.

## Related

- `foo` — the sibling skill.
