---
name: dead-branch-scan
description: Find unreachable code branches — code after return, conditions that can never be true, and feature flags always on/off.
allowed-tools: [Read, Grep, Glob, Bash]
---

# dead-branch-scan

Static + runtime detection of code that never executes. Dead code hides bugs, inflates bundles, and confuses readers.

## Premise

Find real issues, cite `<path:line>` for every finding. "DEFINITELY DEAD" requires either a linter rule firing (`no-unreachable`) or a literal `if (false)` / `if (true)`. "LIKELY DEAD" requires type-narrowing analysis pointing at the specific catch / branch. Feature-flag findings cite the flag name + its current config + the age from `git log`. Coverage-zero branches cite `lcov.info` line + sibling branch hits to confirm reachability is real, not test gap.

## Halt conditions

- Refuse to mark "delete" without the linter or coverage data backing the verdict.
- Refuse to flag exhaustiveness `default: const _: never = x` — that's intentional.
- Halt if the build doesn't compile — reachability analysis is unreliable on broken types.
- Don't auto-delete; propose, get author confirmation, ship as a separate cleanup PR.
- Tests intentionally hit "impossible" paths via mocks — exclude the project's test directories + naming patterns (`__tests__/` / `tests/` / `spec/` and `*.spec.<ext>` / `test_*.py` / `*_test.go` / framework-equivalent).

## When to use

- Before a refactor — clear out cruft first so diffs stay small.
- After a feature-flag rollout — once the flag is fully on, the off-branch is dead.
- After a major version bump — handlers for retired error types may be unreachable.
- Quarterly — pair with `coverage-gap` to find branches with 0 hits.

## Prerequisites

- Working tree compiles cleanly (TypeScript/ESLint/etc. need a green build to reason about reachability).
- Coverage report from a recent test run (for runtime detection).
- Feature-flag config source: `flags.json`, LaunchDarkly export, or env vars.

## Procedure

1. Run the linter's reachability rules:
   ```bash
   npx eslint . --rule 'no-unreachable: error' --rule 'no-constant-condition: error' --rule 'no-fallthrough: error' --no-eslintrc
   # Or all-in-one for TS:
   npx tsc --noEmit --strict   # surfaces narrowing-implied dead catches
   ```
2. Grep for hard-coded literal conditions:
   ```bash
   rg -n 'if\s*\((true|false|0|1|null)\)' --type ts --type js
   rg -n '\bswitch\s*\([^)]+\)[^{]*\{' -A 30 --type ts | rg -n 'case\s+[^:]+:'   # then audit
   ```
3. Intersect coverage with branches: any `BRDA:<line>,<block>,<branch>,0` in `lcov.info` whose sibling branch has hits indicates a dead/untested branch.
4. Audit feature-flag usage:
   ```bash
   rg -n 'isEnabled\(.FLAG_[A-Z_]+.\)' --type ts -o | sort -u
   ```
   Cross-reference each flag against the config source — flags `true` everywhere → false branch dead; flags `false` everywhere → true branch dead.
5. Compute flag age from first commit:
   ```bash
   git log --diff-filter=A -- '*flags*' | head
   ```
6. Classify findings: definitely dead (delete), likely dead (confirm with author), feature-flag-debt (staged removal PR).

## Output

```
Dead branch scan

DEFINITELY DEAD (delete):
  <modules-root>/legacy/migrate.<ext>:142-167
    Code after a fatal-throw / panic / raise on line 141 — unreachable.

  <modules-root>/orders/service.<ext>:84
    `if (false)` (or language-equivalent) — was a feature toggle, flag fully rolled out 6 months ago.

LIKELY DEAD (confirm):
  <modules-root>/auth/session.<ext>:23
    Catch clause for an exception type that no callee throws — type narrowing in the try-block shows it's never thrown here.

FEATURE FLAG TTL:
  FLAG_NEW_CHECKOUT    enabled 8 months ago, no off-branch usage → remove flag + dead branch
  FLAG_BETA_FEATURE    disabled 14 months ago, no on-branch usage → delete dead branch
```

## False positives / gotchas

- Exhaustiveness sentinels (TypeScript's `default: const _: never = x; throw ...`, Rust's `unreachable!()`, Kotlin's `else -> error(...)`, language-equivalent) LOOK unreachable but are intentional — keep them.
- Type narrowing across module boundaries can be wrong if a caller circumvents types — don't delete catches without checking call sites.
- Tests intentionally hit "impossible" paths via mocks — exclude the project's test directories + naming patterns (`__tests__/` / `tests/` / `spec/` and `*.spec.<ext>` / `test_*.py` / `*_test.go` / framework-equivalent) from runtime-dead detection.
- Flags may have non-config consumers (admin override, A/B framework) — audit beyond the static config.
- Don't auto-delete. Propose, let the author confirm, ship as a separate cleanup PR.

## Related

- `debt-ledger` — the disjoint sibling: this skill finds *unreachable* code (delete candidates); `debt-ledger` tracks *reachable, running* but knowingly-suboptimal code (dated TODOs, suppressions, deprecated-API use, version lag) as a longitudinal ranked ledger.
