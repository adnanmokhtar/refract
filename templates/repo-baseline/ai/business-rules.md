# Business rules — the current state (Tier 2)

How this business works **today**: the rules the product applies, area by area, in one line each,
with where the code enforces them. Read before analysing a task, before asking the owner a
question, and before calling something a defect: a rule written here is the business's decision,
and it outranks a general idea of how this kind of business usually works.

Last updated: <YYYY-MM-DD>

> **How this file stays true** (`.claude/templates/snippets/study-before-build.md` § 7):
> - A task that adds, changes or removes a rule edits that rule **here, in place**, in the same
>   change, and appends one line to `ai/business-rules-history.md`.
> - The old wording never stays beside the new one. The history file keeps the past.
> - An area nobody has written yet is filled the first time a task touches it, read from the code.
> - Each rule cites where it is enforced (`file:line`). When nothing in the code enforces it, the
>   line says so: `not enforced`.

## Format

```
### <Area> (orders, stock, shipping, wallets, permissions, merchants, …)
- <the rule, one plain line> — <file:line> · since <date> (<card or PR>)
```

<!-- Areas start here. Add one `### <Area>` section the first time a task touches the area. -->
