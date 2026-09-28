# Rules — two tiers

Rules in this directory come in two tiers. The tier is decided by one thing: whether the file has `paths:` frontmatter.

## Always-loaded (no `paths:`)

Claude Code loads every `.md` here that has no `paths:` at launch, in every session — recursively, and whether or not `CLAUDE.md` `@`-imports it. They cost tokens **every session**, so they are reserved for the principles that must shape *all* work:

- `read-before-write.md`, `read-codebase-deeply.md`, `think-simplify-surgical.md`, `code-quality.md`, `engineering-baseline.md`

> Adding a file here **loads it**. The `CLAUDE.md` `@`-imports name the always-on set so it can be reviewed; removing an import does not unload a rule — give it `paths:` (below) or delete the file. Source: https://code.claude.com/docs/en/memory § "Organize rules with `.claude/rules/`", and a canary measurement on Claude Code 2.1.236 (`scripts/wire-rule-imports.sh` header in Refract).

The combined size of the always-loaded set is guarded in CI by `scripts/check-rule-budget.sh` (default budget 6000 tokens). A new always-on rule that busts the budget must either trim a foundational rule or become path-scoped.

## Path-scoped (`paths:` frontmatter)

```yaml
---
paths:
  - "**/migrations/**"
  - "**/*.tsx"
---
```

NOT imported by `CLAUDE.md`. Claude Code loads a path-scoped rule when it reads a file matching its globs; the `inject-path-rules.sh` PreToolUse hook adds it before an Edit/Write too (a new file, or one edited without being read), as `additionalContext`, **once per session** (deduped on `session_id`). Cost is near-zero until you work on a file the rule governs.

- Example shipped here: `migration-safety.md` (loads only near migration files).
- Glob support: `**` (any depth), `*` (one segment), `**/`, `/**`, literal paths.
- Opt out of injection entirely: `touch .claude/.no-path-rules`.

**When to make a rule path-scoped:** it only applies to a slice of the tree (a stack, a directory, a file type) and doesn't need to shape unrelated work. That is most domain/stack rules — keep the always-on set small and push the rest here.
