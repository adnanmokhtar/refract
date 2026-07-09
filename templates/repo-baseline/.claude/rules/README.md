# Rules — two tiers

Rules in this directory come in two tiers. The tier is decided by one thing: whether the file has `paths:` frontmatter.

## Always-loaded (no `paths:`)

Wired into every session by the project `CLAUDE.md` `@`-imports (`@.claude/rules/<name>.md`). They cost tokens **every turn**, so they are reserved for the few principles that must shape *all* work:

- `read-before-write.md`, `read-codebase-deeply.md`, `think-simplify-surgical.md`, `code-quality.md`

> Claude Code does not auto-load `.claude/rules/` on its own — the `CLAUDE.md` import is what makes these always-on. Adding a file here does **not** load it unless you either `@`-import it (always-on) or give it `paths:` (path-scoped, below).

The combined size of the always-loaded set is guarded in CI by `scripts/check-rule-budget.sh` (default budget 6000 tokens). A new always-on rule that busts the budget must either trim a foundational rule or become path-scoped.

## Path-scoped (`paths:` frontmatter)

```yaml
---
paths:
  - "**/migrations/**"
  - "**/*.tsx"
---
```

NOT imported by `CLAUDE.md`. Instead, the `inject-path-rules.sh` PreToolUse hook watches every Edit/Write, matches the target file against each rule's globs, and injects the matching rule as `additionalContext` — **once per session** (deduped on `session_id`). Cost is near-zero until you actually edit a file the rule governs.

- Example shipped here: `migration-safety.md` (loads only near migration files).
- Glob support: `**` (any depth), `*` (one segment), `**/`, `/**`, literal paths.
- Opt out of injection entirely: `touch .claude/.no-path-rules`.

**When to make a rule path-scoped:** it only applies to a slice of the tree (a stack, a directory, a file type) and doesn't need to shape unrelated work. That is most domain/stack rules — keep the always-on set small and push the rest here.
