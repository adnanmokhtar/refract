---
description: Review changed code for reuse, dead branches, and over-abstraction; propose concrete simplifications.
---

# /simplify [path]

Looks at staged + unstaged diffs and proposes specific simplifications with before/after diffs. Optionally applies them.

## Phases applied

All 7. Phase 4 = propose diffs (no auto-apply without confirmation).

## When to use / NOT to use
- USE: right after writing a draft, before opening a PR; reviewing a sibling's PR with too much code for the problem.
- NOT: file is intentionally verbose (generated code, schema, fixture); cross-module API change (use `/refactor` instead).

## Phase 1 — Understand

- Parse `[path]` arg if given; else default to staged + unstaged diffs.
- Confirm scope: own diff vs teammate's PR — different consent rules.
- Success: each candidate has a one-line rationale + before/after, and lint/typecheck stay green after applied edits.

## Phase 2 — Organize

- Resolve target file list (`git diff --name-only HEAD` + `git diff --name-only --cached`, or path arg).
- For each file, queue 7 detector passes (see Phase 3).
- Trivial single-file scope: skip planning, proceed.

## Phase 3 — Retrieve

- `CLAUDE.md` + `ai/conventions.md` — what counts as "verbose" here (project may codify it).
- `ai/patterns/` — the canonical shapes; "wrapper with one implementer" only flags if it diverges from documented pattern.
- For each changed file: existing helpers/utilities in the same layer (grep before flagging "duplicated logic").

## Phase 4 — Generate (candidates)

For each file, scan for:
- **Duplicated logic** — same shape exists in a helper / utility / sibling. Grep first.
- **Over-abstraction** — wrapper class / factory / strategy with one implementer.
- **Dead branches** — `if (false)`, unreachable returns, conditions that became invariants.
- **Over-validation** — validating types TypeScript already enforces; null-checks on non-nullable types.
- **Premature parameterization** — `options: { foo?: bool }` where every caller passes the same value.
- **Verbose error handling** — try/catch that re-throws unchanged.
- **Reinventing stdlib** — manual `groupBy` / `chunk` / `partition` when `lodash` / `Array.prototype` covers it.
- **Comment-as-rename** — `// gets the user` above `function getUser()`.

Produce candidates with before/after snippets + one-line rationale. Ask user which to apply.

## Phase 5 — Update

- Apply selected edits via Edit tool.
- No knowledge-base updates unless a new "duplicated logic" finding reveals a missing entry in `ai/patterns/` — then queue to `ai/dynamic/learned-patterns.md`.

## Phase 6 — Validate

- Lint + typecheck on touched files; revert if anything fails.
- Re-run scoped tests — coverage must not move.
- For removed branches: confirm no test exercised them (if it did, the branch wasn't dead).

## Phase 7 — Improve

- If 3+ similar duplicates found across files, queue a pattern entry (e.g. "extract X helper") to `ai/dynamic/learned-patterns.md`.
- If a "wrapper with one implementer" recurs, append to `ai/dynamic/drift-log.md` — the abstraction policy may be too eager.

## Output

```
3 candidates in src/orders/orders.service.ts:

[1] L42  Duplicated query
    Existing helper: ordersRepo.findByTenant() at libs/repos/orders.ts:88
    Before:  const o = await this.qb('orders').where(...).getMany();
    After:   const o = await this.ordersRepo.findByTenant(tenantId);

[2] L88  Wrapper with one implementer
    OrderFactory.create() only used by OrderService.create() — fold into the call site.

[3] L120 Premature options
    paginate(opts: { limit?: number; offset?: number })  every caller passes both.

Apply [1,2,3] / [1,3] / none?
```

## Failure modes

- Cross-module simplification breaks a public API consumer — never apply without grep-confirming all call sites.
- "Simplify" turning into "optimize" (clever reduce-chain replacing clear loop) — opposite of this command's goal.
- Verbose form is correct (audit logs, retry logic for known-flaky API) — skip when in doubt.
- Test coverage moves after applied edit — revert; the change was not behavior-preserving.
- Reviewing teammate's PR — get consent before applying anything.

## Related

### Sibling commands in code-quality pack
- `/check-health` — sibling command in code-quality pack
- `/find-module` — sibling command in code-quality pack
- `/pre-commit` — sibling command in code-quality pack
- `/review-changes` — sibling command in code-quality pack

### Rules
- `.claude/rules/engineering-principles.md`
- `.claude/rules/quality-principles.md`
