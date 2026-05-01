---
name: quality-principles
kind: example
pack: code-quality
---

# Code Quality Principles

Prevents the slow death: dead code, copy-paste rot, comment lies, and "TODO" graveyards.

## Must

- One reason for a function / class / file to change. If you say "and" describing it ("validates AND saves AND notifies"), split it.
- Names are descriptive: `unsettledOrders`, not `data` / `result` / `tmp`. Variable scope determines verbosity — loop counter `i` is fine; module-level `i` is not.
- Custom exception types per domain concept: `OrderNotFoundException`, `PaymentDeclinedException`. Never `throw new Error('not found')` — callers can't handle it specifically.
- Validate inputs at the boundary: HTTP / webhook / queue / CLI. Inside the system, types are the contract; don't re-validate.
- Pagination on every list endpoint. Cursor preferred; offset acceptable for shallow lists.
- Parameterized queries always. No string interpolation into SQL.
- Indexes on every FK and on every column used in WHERE / ORDER BY / GROUP BY of common queries.
- Imports tidy: dead imports removed (`ts-prune`, `unimport`, `pyflakes`, `goimports`). No commented-out import blocks.

## Must not

- `any` / `unknown` casts at boundaries without explicit narrowing. `as any` in TypeScript is a code smell or a CVE.
- `console.log` / `print` / `fmt.Println` debugging in committed code. Use the project logger with structured fields.
- Commented-out code. `git` remembers; commits don't need a tomb.
- Comments paraphrasing the next line: `// increment counter` above `counter++`. Delete it.
- Reference the PR / ticket / reviewer in committed prose ("This was added for PR-1234"). `git blame` is the source.
- `TODO` without owner + delete-by date: `TODO(@alice 2026-06-01): retry on 503`.
- Backwards-compat shims for code that hasn't shipped yet. YAGNI applied to your own untested ideas.
- Speculative abstractions ("we MIGHT need this for X") — wait for the second concrete use.
- `--no-verify` / hook-bypass on commits without explicit authorization. Hooks fail for reasons.

## Should

- Extract a helper / type / class after the SAME shape appears 3 times. Two is coincidence; three is a pattern.
- Functions short enough to read without scrolling — if you can't see it on one screen, split.
- Pure functions for business logic; side-effects pushed to the edge (services / adapters). Easier to test, easier to reason about.
- Default to no comments. Add one only when the WHY is non-obvious — a hidden constraint, a known workaround, a subtle invariant.
- Consistent ordering inside files: imports → types → constants → public API → private helpers. Match the codebase if it differs.

## Review checklist

- [ ] No new `any` / `as any` / `# type: ignore` / `interface{}` without narrowing or comment.
- [ ] No `console.log`, `print`, `var_dump`, `dd`, `byebug` left in.
- [ ] No commented-out code.
- [ ] New custom exceptions have a clear name and are mapped to HTTP status / queue retry policy.
- [ ] New comments explain WHY, not WHAT.
- [ ] Names readable to someone who didn't write them.
- [ ] Lint and type-check pass without `eslint-disable` / `# noqa` / `// @ts-ignore` (or the suppression has a comment justifying it).

## Enforcement

- ESLint / Prettier / Biome with strict config; type-check (`tsc --noEmit` / `mypy --strict` / `pyright`) gates CI.
- `ts-prune` / `unimported` / `vulture` (Python) / `deadcode` (Go) detect dead exports.
- `jscpd` / `simian` for copy-paste detection (>5% duplication blocks PR).
- Pre-commit hook (Husky / lefthook / pre-commit) runs lint + format on staged files.
- Code review style guide auto-enforced where possible — humans review intent, not commas.
