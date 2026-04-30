---
name: coverage-gap
description: Find untested branches in recently-changed code. Not "what percent is covered" but "which conditional paths never fired in any test".
---

# coverage-gap

Raw coverage numbers are noise. What matters: did your recent changes introduce untested branches?

## Premise

Find real gaps, no hand-waves. Every reported gap cites `<path:line>` for the uncovered branch (or line, with the missing branch named — "`else` of `if (override != null)`"), the source of the coverage data (`lcov.info` / `coverage.json`), and the merge-base SHA the diff was computed against. "Coverage went down" is not a finding; "`prompt-builder.service.ts:67` else-branch hit 0× in the lcov from this run" is. Generated files, transpiled `?.`/`??` artifacts, and snapshot-only "coverage" are excluded explicitly — not silently swept into the score.

## Halt conditions

- Halt on findings without `<path:line>` + branch identifier + 0-hit citation from the coverage report.
- Halt on coverage deltas reported without naming the merge-base SHA used for the diff.
- Halt on classifications ("HIGH PRIORITY") that don't name the location heuristic (hot module, error path, public API).

## When to use

- Before opening a PR — verify changed lines are exercised.
- After a hotfix — confirm the regression test actually hits the bug path.
- During code review when coverage delta looks suspicious.

## Prerequisites

- Test runner with coverage support (`jest --coverage`, `vitest --coverage`, `pytest-cov`, `go test -cover`, `cargo tarpaulin`).
- `git` available — needed to compute the changed-lines diff.
- Coverage output in a machine-readable format (`lcov.info`, `coverage.json`, `coverage.xml`).

## Procedure

1. Determine the merge base for the branch:
   ```bash
   BASE=$(git merge-base HEAD origin/main)
   ```
2. List changed lines per file:
   ```bash
   git diff --unified=0 "$BASE"..HEAD | \
     awk '/^\+\+\+ b\// {f=substr($2,3)} /^@@/ {match($0,/\+[0-9]+(,[0-9]+)?/); split(substr($0,RSTART+1,RLENGTH-1),a,","); for(i=0;i<(a[2]?a[2]:1);i++) print f":"(a[1]+i)}'
   ```
3. Run coverage:
   ```bash
   npx jest --coverage --coverageReporters=lcov --changedSince="$BASE"
   ```
4. Intersect changed lines with `coverage/lcov.info` — for each `DA:<line>,<hits>` and `BRDA:<line>,<block>,<branch>,<hits|->`, mark `0` or `-` as uncovered.
5. Classify each changed line: covered, line-uncovered, or branch-partial (one side of an `if/else` taken, the other not).
6. Rank by location: hot module > cold module; error path > happy path; public API > internal helper.

## Output

```
Coverage gap — feature/ai-reply-tuning  (base=origin/main)

Files changed: 8  |  Lines changed: 142  |  Covered: 98  |  Uncovered: 44

HIGH PRIORITY (untested branches):
  src/modules/ai/core/prompt-builder.service.ts:67-72
    if (override != null) { ... }   ← else branch hit 0 times
    No test exercises override == null path.

  src/modules/ai/infrastructure/claude.client.ts:103-108
    catch (RateLimitError) { ... }   ← caught 0 times
    No test forces 429 from Anthropic SDK mock.

LOW PRIORITY:
  src/modules/ai/core/pricing.ts:18
    Fallback `return 0` — likely unreachable, candidate for delete.
```

## False positives / gotchas

- Generated code (Prisma client, OpenAPI types) shows as uncovered — exclude via `coveragePathIgnorePatterns`.
- TypeScript `?.` and `??` compile to multiple branches; partial coverage on one transpiled branch is usually acceptable.
- Snapshot tests inflate line coverage but don't exercise branches — don't be misled.
- A branch shown as "0 hits" in `lcov` may be reachable only under a specific Node version flag — check before deleting.
