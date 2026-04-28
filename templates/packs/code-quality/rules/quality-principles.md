# Code Quality Principles

Prevents the slow death: dead code, copy-paste rot, comment lies, and "TODO" graveyards.

## Must

- One reason for a function / class / file to change. If you say "and" describing it ("validates AND saves AND notifies"), split it.
- Functions ≤ 30 lines (hard cap, signature + body, excludes blank lines + closing braces). If it doesn't fit, split — extract a helper, hoist a guard clause, or rethink the responsibility. The cap is a forcing function for the single-responsibility rule above; bypassing requires an explicit comment naming the reason (rare — algorithm with state machine, generated code, etc.).
- Names are descriptive: `unsettledOrders`, not `data` / `result` / `tmp`. Variable scope determines verbosity — loop counter `i` is fine; module-level `i` is not.
- Custom exception types per domain concept: `OrderNotFoundException`, `PaymentDeclinedException`. Never `throw new Error('not found')` — callers can't handle it specifically.
- Validate inputs at the boundary: HTTP / webhook / queue / CLI. Inside the system, types are the contract; don't re-validate.
- Pagination on every list endpoint. Cursor preferred; offset acceptable for shallow lists.
- Parameterized queries always. No string interpolation into SQL.
- Indexes on every FK and on every column used in WHERE / ORDER BY / GROUP BY of common queries.
- Imports tidy: dead imports removed (`ts-prune`, `unimport`, `pyflakes`, `goimports`). No commented-out import blocks.
- Identify inputs, outputs, and dependencies before modifying any logic. If you can't trace them in ~2 minutes (read the function signature, callers via grep, downstream effects), you don't know enough yet — read more, or ask before editing. The "I'll figure it out as I go" pattern is how silent regressions ship.

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
- Pure functions for business logic; side-effects pushed to the edge (services / adapters). Easier to test, easier to reason about.
- Default to no comments. Add one only when the WHY is non-obvious — a hidden constraint, a known workaround, a subtle invariant.
- Consistent ordering inside files: imports → types → constants → public API → private helpers. Match the codebase if it differs.
- Boy Scout Rule: leave code cleaner than you found it. When you touch a file, fix the dead imports / commented-out blocks / vague names / redundant comments in the same change — don't open a "cleanup PR later" ticket that never lands. Bound the scope: clean what's adjacent to your change, not the whole file (avoids ballooning diffs that obscure the real edit).

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
