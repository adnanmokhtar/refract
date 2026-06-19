---
description: Review changed code for reuse, dead branches, and over-abstraction; propose concrete simplifications.
---

# /simplify [path]

Looks at staged + unstaged diffs and proposes specific simplifications with before/after diffs. Optionally applies them.

## The Premise (read this first, internalize, do not deviate)

**Existing patterns are the truth. Simplification means matching siblings, not innovating.** The repo already has a shape — helpers, base classes, repository pairs, error envelopes, validation primitives. Simplifying means: fewer lines, fewer abstractions, more reuse of what's already there. It does NOT mean: introducing a new helper, a new generic, a new strategy interface, a new base class, a new "cleaner" pattern the agent thinks is nicer.

**The closure verb is `remove-or-inline`.** Each candidate is one of:
- `remove` — delete dead branch / unused export / unreachable return / no-op wrapper.
- `inline` — fold a single-caller wrapper / factory / strategy into its only call site.
- `dedupe` — replace a local re-implementation with the existing helper (cite the helper's `<path>:<line>`).
- `rename-comment-out` — delete a `// gets the user` above `function getUser()`.

That's the entire vocabulary. If the simplification doesn't fit one of those four, it isn't a simplification — it's a refactor or a redesign, and `/simplify` refuses it.

**Forbidden:**
- Introducing a NEW abstraction (helper, base class, mixin, generic, strategy, factory, decorator, hook) — even if "it would be cleaner". The simplify command is an entropy-reducer, not a designer.
- Replacing a clear loop with a clever `reduce`-chain or pipeline.
- Replacing project primitives with stdlib equivalents the project doesn't already use elsewhere (don't introduce `lodash` if the project doesn't use it; do use it if siblings already do).
- Cross-module API rewrites — those go to `/refactor`.
- Applying any candidate without grep-confirming all call sites of an inlined symbol.

**Mechanical halt — refuse refactor that introduces new abstractions; only remove/inline:** before proposing a candidate, the agent classifies it against the four-verb vocabulary. Any candidate that adds a new symbol (function / class / type / interface / file) HALTS with a route-to-`/refactor` note. Net-line-count for an applied simplify run MUST be ≤ 0 (lines removed ≥ lines added). If the diff goes positive, revert.

**Lightweight default.** Staged + unstaged diffs only (or `[path]` arg). No project-wide sweeps, no global pattern proposals, no `ai/patterns/` authoring inside this command. If 3+ duplicates surface, queue a one-line note to `ai/dynamic/learned-patterns.md` for a future `/refactor` to act on; do not act on it here.

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
- `/refactor` — the boundary: `/simplify` only **reuses an existing** helper (dedupe/inline against what's already there) and refuses to add a new symbol; the moment a fix needs a **new** helper / abstraction extracted, it routes to `/refactor`.

### Rules
- `.claude/rules/engineering-principles.md`
- `.claude/rules/quality-principles.md`
