---
description: Generate or update a CI workflow for the detected platform and stack.
---

# /add-ci [platform]

Adds lint + typecheck + test + build pipeline. Detects platform; defaults to GitHub Actions if absent.

## Phases applied

All 7. Phase 5 also recommends required-check names for branch protection.

## When to use / NOT to use
- USE: new repo with no CI; adding a new track (backend gaining a frontend); replacing a broken/partial workflow.
- NOT: existing workflow already covers all required checks — propose edits, not a rewrite.

## Phase 1 — Understand

- Parse `[platform]` if given; else detect (Phase 3).
- Confirm: which jobs to wire as required checks. Single consolidated question if existing CI is partial.
- Success: workflow runs on PR + push to default branch, all jobs pass on first run, branch-protection guidance prints job names verbatim.

## Phase 2 — Organize

- Detect platform + stack commands.
- Plan jobs: lint, typecheck, test, build (parallelized), optional docker-build (tag-only).
- Decide cache key (lockfile + OS).
- Pause for confirmation if existing workflow exists — edit vs replace.

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` — package manager + scripts.
- `ai/stack.md` — language versions + tool commands.

Detect platform:
- `.github/workflows/` → GitHub Actions
- `.gitlab-ci.yml` → GitLab CI
- `bitbucket-pipelines.yml` → Bitbucket
- `.circleci/config.yml` → CircleCI
- None → ask user; default `github`.

Detect stack commands:
- `package.json` scripts (`lint`, `test`, `build`, `typecheck`).
- `pyproject.toml` (`ruff`, `pytest`, `mypy`).
- `go.mod` (`go vet`, `go test`, `golangci-lint`).
- Lockfile → cache key (`pnpm-lock.yaml`, `package-lock.json`, `bun.lockb`, `poetry.lock`, `go.sum`).

EXISTING — read sibling workflow files (other repos in same org) if user references them, to mirror conventions.

## Phase 4 — Generate

Workflow file:
- Triggers: `pull_request` + push to `main`.
- Jobs: lint, typecheck, test, build — parallelized; `needs:` only where genuine dependency exists.
- Cache step keyed on `<lockfile>-<runs-on>`.
- Artifact upload on successful build.
- Optional `docker-build` job gated on tag push.
- `concurrency: ci-${{ github.ref }}` with `cancel-in-progress: true`.

## Phase 5 — Update

- `ai/status.md` — Recent Changes entry.
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/runbooks/ci.md` — create or append (job names, cache invalidation, secret rotation).
- Print exact required-check names for the user to set in branch protection (no auto-apply).

## Phase 6 — Validate

- Open generated file path so user can review.
- After commit + first push, monitor first run; if any job fails, HALT and report.
- Confirm cache hit on second run — miss = key is wrong.

## Phase 7 — Improve

- If workflow needs matrix builds or per-environment jobs, queue ADR to `ai/dynamic/decisions-pending.md`.
- If org has CI conventions worth codifying, queue to `ai/dynamic/learned-patterns.md`.

## Output

```
Created: .github/workflows/ci.yml
Jobs:    lint · typecheck · test · build (parallel) → docker (tag-only)
Cache:   actions/cache@v4 keyed on bun.lockb

Branch protection — set required checks to:
  ci / lint
  ci / typecheck
  ci / test
  ci / build
```

## Failure modes

- Required-check name mismatch with workflow job names — PRs permanently blocked.
- `pull_request_target` on workflows checking out PR code from forks — leaks secrets; use `pull_request`.
- Secrets over-scoped — `GITHUB_TOKEN` defaults to write; explicitly downgrade non-deploy jobs to `contents: read`.
- Matrix builds added without project supporting them — wasted CI minutes.
- Cache key omits OS — cross-platform cache poisoning.
- No `concurrency` block — stale runs pile up on force-pushes.
