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
- **SHA-pin every `uses:` in a privileged job** (a write scope, `id-token`, an `environment:` or a
  secret): `@<sha>  # v7.4.0`, resolved with `gh api repos/<o>/<r>/commits/<tag> --jq .sha`.
- `persist-credentials: false` on every checkout unless a later step pushes with git.
- Jobs: lint, typecheck, test, build — parallelized; `needs:` only where genuine dependency exists.
- Cache step keyed on `<lockfile>-<runs-on>`.
- Artifact upload on successful build.
- Optional `docker-build` job gated on tag push: build **once**, push by digest, scan **that** build
  before any tag or deploy references it, and pass the digest on — never publish a rebuild of the
  scanned image (`proof-oracles.md` V223).
- **Concurrency split by what a cancel would kill:** workflow-level
  `cancel-in-progress: ${{ github.event_name == 'pull_request' }}` (PR runs only); every deploy or
  publish job gets a job-level group keyed on its environment with `cancel-in-progress: false`
  (`precedents/devops.md` § 15). Never `ci-${{ github.ref }}` + cancel over the docker job.
- `timeout-minutes:` on every job.

## Phase 5 — Update

- `ai/status.md` — Recent Changes entry.
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/runbooks/ci.md` — create or append (job names, cache invalidation, secret rotation).
- Print exact required-check names for the user to set in branch protection (no auto-apply).

## Phase 6 — Validate

- **Run the detectors on the emitted file first:** `ci-graph.py <file> --check=pin-priv,deploy-concurrency,deploy-gate,timeout`
  prints nothing (exit 2 = NOT-RUN, never "clean"); `pipeline-integrity-scan` §1–§8 on that file;
  and `ci-security-scan` when the security pack is installed (until it ships, `iac-scan` § 5).
  Without the security pack, `pipeline-integrity-scan`'s fallback lane runs and its rows are tagged
  `security-class (owner pack not installed)`. A High or Critical row halts.
- **Then dispatch `@ci-reviewer` on the workflow just generated**, before declaring done. A generator
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

Pins:    docker job SHA-pinned; lint/test jobs on major tags

ci-graph.py: 0 rows · pipeline-integrity-scan: 0 findings · ci-security-scan: 0 findings
ci-reviewer: PASS (0 blockers)

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
- A workflow-level `cancel-in-progress: true` over a deploy or publish job — a newer push kills the
  running deploy mid-apply.
- Scanning one build and publishing another — what ships is not what the gate passed.
- No `timeout-minutes:` — a hung job bills until the platform's default cap.
