# Declared idioms

Shared units this project depends on that `/setup-project` must always extract, whatever their
number of users. A unit built on purpose (a wrapper, a gate, a token source) starts with fewer
than three users, and the extraction threshold would otherwise drop it on every run. The command
that halted for it would then halt again
(`.claude/templates/snippets/decide-before-change.md` § 10).

- **Who writes a row:** the command that built the unit, in the same commit, or the person.
- **Who reads it:** `/setup-project` Phase 2.5 extracts every row into
  `.claude/_extracted-idioms.md`, and `audit-setup.sh` fails a run that drops one. Commands read
  `_extracted-idioms.md`, not this file, so the command that writes a row adds the same unit
  there too.
- **Kinds:** `wrapper`, `composable`, `service`, `base-class`, `type-primitive`, `tokens`.
- **To remove a unit,** delete its row.

| kind | path | role | declared by | date |
|---|---|---|---|---|
