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
- **A workflow-level `permissions:` block, always, even when it is just `contents: read`.** Do not
  reason about "the default" — the `GITHUB_TOKEN`'s permissions are initially set to the default
  setting for the enterprise, organization, or repository, so it is a per-repo setting invisible from
  the workflow and changeable without a commit. Declaring the block removes the question, and
  anything not named in it is set to `none`. Widen **per job**: `packages: write` on the job that
  pushes to a container registry (without it the push 403s), `id-token: write` for OIDC / keyless
  signing, `contents: write` only where a release is created.
- **Runner label** — decide, don't inherit. `ubuntu-latest` moves when GitHub rolls the runner image;
  a pinned `ubuntu-<version>` is reproducible until you bump it. Record which and why in `ai/runbooks/ci.md`.
- **Action versions are resolved, not remembered** — `gh api repos/<owner>/<repo>/releases/latest
  --jq .tag_name` per action before emitting it. Never a branch ref (`@master` / `@main`). Add
  `github-actions` to `dependabot.yml` alongside the language ecosystem, or the pins rot.
- Jobs: lint, typecheck, test, build — parallelized; `needs:` only where genuine dependency exists.
- Cache step keyed on `<lockfile>-<runs-on>`.
- Artifact upload on successful build.
- Optional `docker-build` job gated on tag push.
- `concurrency: ci-${{ github.ref }}` with `cancel-in-progress: true`, and `timeout-minutes:` on every job.

## Phase 5 — Update

- `ai/status.md` — Recent Changes entry.
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/runbooks/ci.md` — create or append (job names, cache invalidation, secret rotation).
- Print exact required-check names for the user to set in branch protection (no auto-apply).

## Phase 6 — Validate

- **Dispatch `@ci-reviewer` on the workflow just generated**, before declaring done. A generator
  never read by its own reviewer drifts. Treat a Critical/BLOCKER finding as a halt — fix Phase 4's
  output and re-emit. If the agent is not installed, say so rather than reporting an unreviewed
  workflow as reviewed.
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
Perms:   workflow contents: read; docker job adds packages: write + id-token: write
Runner:  ubuntu-latest (unpinned — recorded in ai/runbooks/ci.md as a deliberate choice)
Cache:   actions/cache@v6 (resolved via `gh api .../releases/latest`) keyed on bun.lockb

ci-reviewer: PASS (0 blockers; 1 medium — SHA-pin the docker job's actions)

Branch protection — set required checks to:
  ci / lint
  ci / typecheck
  ci / test
  ci / build
```

## Failure modes

- Required-check name mismatch with workflow job names — PRs permanently blocked.
- `pull_request_target` on workflows checking out PR code from forks — leaks secrets; use `pull_request`.
- No `permissions:` block at all — the failure is not "the default is write", it is that the default
  is a repo/org setting invisible from the workflow, so the same file is least-privilege in one repo
  and over-scoped in another. Declare it; then the answer is in the file.
- Untrusted `${{ github.event.* }}` inside a `run:` — PR titles, branch names and issue bodies are
  substituted into the shell before it executes. Bind to an intermediate `env:` var and use `"$VAR"`.
- Matrix legs on an unsupported runtime major — burns minutes proving compatibility with something
  that no longer receives security patches.
- Cache key omits OS — cross-platform cache poisoning.
- No `concurrency` block — stale runs pile up on force-pushes.
- No `timeout-minutes:` — a hung job bills until the platform's default cap.
