# Feature records — index

One folder per card or feature built, next to the code it changed: why it was built, how it was
designed, and what it had to do. Read a feature's folder before changing that feature again.

Each folder, `ai/features/<YYYY-MM-DD>-<slug>/`, holds:
- `brief.md` — the approved brief: the problem, what was done, where, what did not change, how to
  test it, and the questions with their answers and who gave them;
- `design.md` — how it was built: the components, the API endpoints, the data changes and the
  screens, and why this shape and not another. For a bug fix: the cause, and what changed where
  and why;
- `acceptance.md` — the acceptance criteria as approved. For a bug: the expected behaviour and the
  regression test;
- `study.md` — what the study read and found: files and lines, rules, the precedent, every place the
  change applies, existing data, conflicts, questions and answers. The design started from it.

The folder is committed with the change, in the same branch. The PR links live on the card,
since one card may open more than one PR. A later change to the same feature adds a
new folder and names the earlier one; nothing in an old folder is rewritten.

## Index

```
<YYYY-MM-DD> · <title> · <card> · <branch> · ai/features/<YYYY-MM-DD>-<slug>/
```

<!-- Entries start here, newest last. -->
