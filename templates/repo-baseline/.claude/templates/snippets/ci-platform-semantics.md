# CI platform semantics — the facts every pipeline verdict rests on

One row per fact, each tagged and dated. A pipeline verdict that depends on how a platform runs a
step (does a pipe mask the exit, is a skipped job a pass, does a new push cancel a deploy) names the
row it rests on; a PC-2 verdict that names no row is invalid. Cited by the devops detectors
(`pipeline-integrity-scan`, `pipeline-cache-scan`, `deploy-safety-scan`), by testing
`suite-execution-scan` § 4, by code-quality `suppression-scan` and by security `ci-security-scan`.
Settled questions built on these rows are in [`precedents/devops.md`](precedents/devops.md); the
oracles are in [`proof-oracles.md`](proof-oracles.md) § DevOps.

Tags: `[V]` verified against the source on the date given · `[K]` known, not re-fetched · `[K?]`
uncertain — prove it on a fixture before a skill asserts it. A platform changes these; a row older
than the platform's current docs is re-read before it decides a verdict.

## Shells and exit status

| # | Platform | Fact | Tag · date · source |
|---|---|---|---|
| S1 | GitHub Actions | `run:` with no `shell:` on Linux/macOS runs `bash -e {0}`: errexit, **no pipefail**. An explicit `shell: bash` runs `bash --noprofile --norc -eo pipefail {0}`. With no bash on the runner, the default is `sh -e {0}` | [V] 2026-10-10 · GitHub Docs, *Workflow syntax* |
| S2 | GitHub Actions | Effective shell order: step `shell:` → job `defaults.run.shell` → workflow `defaults.run.shell` → the S1 default (`ci-graph.py --shell-of`) | [V] 2026-10-10 · *Workflow syntax* |
| S3 | GitLab CI | The bash executor runs the script with `set -eo pipefail`; `FF_ENABLE_BASH_EXIT_CODE_CHECK` (default off) adds a per-line check with known false aborts in `else` branches | [K?] · GitLab Runner MR !2671 — prove with one `false \| cat` job |
| S4 | CircleCI | Default shell `/bin/bash -eo pipefail` (or `/bin/sh -eo pipefail`); each step is a fresh shell | [V] 2026-10-10 · CircleCI support, *Step should fail but job finished successfully* |
| S5 | Bitbucket Pipelines | Each build starts with `set -e`, **no pipefail** | [V] 2026-10-10 · Atlassian KB, *Pipelines builds succeed even on command failure* |
| S6 | Azure Pipelines | A multi-line `script:` on Linux has **no errexit**: only the last command's exit code decides the step | [K?] · FreeIPA commit b5bb436 (no Microsoft page states it) — prove on the fixture |
| S7 | Jenkins | An `sh` step runs `sh -xe` unless the script has a shebang; no pipefail | [K] |

Shell probe for S1–S7 (`proof-oracles.md` V210): `bash -e -c 'false | tee /dev/null'` → 0;
`bash -eo pipefail -c 'false | tee /dev/null'` → 1; `bash -c $'false\necho done'` → 0;
`sh -e -c 'false | cat'` → 0.

## Skips, required checks and failure tolerance

| # | Platform | Fact | Tag · date · source |
|---|---|---|---|
| R1 | GitHub Actions | A job skipped by its own `if:` reports **success** | [V] 2026-10-10 · *Troubleshooting required status checks* |
| R2 | GitHub Actions | A job whose `needs:` dependency failed or was skipped is skipped and does **not** report failure, unless its `if:` uses a status function (`always()`, `!cancelled()`); an aggregator needs `if: always()` plus an explicit check of `needs.*.result` | [V] 2026-10-10 · *Workflow syntax*, *Troubleshooting required status checks* |
| R3 | GitHub Actions | A workflow skipped by `paths`, `paths-ignore`, `branches` or a commit-message skip leaves its checks **Pending**: the PR waits ("Waiting for status to be reported"). Path filters are not evaluated on tag pushes; `branches` and `paths` must both match | [V] 2026-10-10 · *Workflow syntax*, *Troubleshooting required status checks* |
| R4 | GitHub Actions | Passing states for a required check: `success`, `skipped`, `neutral`; it must pass on the latest SHA within 7 days; a `workflow_dispatch` run on the head branch does **not** satisfy it | [V] 2026-10-10 · *Troubleshooting required status checks* |
| R5 | GitHub Actions | With the merge queue on, a required-check workflow needs `on: merge_group` beside `pull_request`, or the check is never reported and the merge fails | [V] 2026-10-10 · *Troubleshooting required status checks* |
| R6 | GitHub Actions | A check run and a commit status with the same required name must **both** pass | [V] 2026-10-10 · *Troubleshooting required status checks* |
| R7 | GitHub Actions | Two workflows emitting one job name for one required context: which run the rule matches | [K?] — settle on a sandbox repo before a skill asserts it |
| R8 | GitLab CI | `allow_failure` defaults to **true** only for `when: manual` jobs (false for `rules: … when: manual`); `allow_failure: exit_codes` narrows it | [V] 2026-10-10 · GitLab Docs, *CI/CD YAML syntax reference* |
| R9 | GitLab CI | `retry` is 0–2 and `retry:when` defaults to `always`, which retries real script failures | [V] 2026-10-10 · *CI/CD YAML syntax reference* |
| R10 | GitLab CI | `rules:changes` evaluates **true** on new-branch pipelines and on pipelines with no push event (tag, schedule, manual) unless `compare_to:` is set | [V] 2026-10-10 · *CI/CD YAML syntax reference* |
| R11 | GitLab CI | `needs:optional: true` with the needed job absent starts the job immediately, like `needs: []` | [V] 2026-10-10 · *CI/CD YAML syntax reference* |

## Concurrency, environments, timeouts, schedules, caches

| # | Platform | Fact | Tag · date · source |
|---|---|---|---|
| C1 | GitHub Actions | `concurrency`: at most one running and one pending run per group; a new pending run replaces the old pending one (`queue: single`, the default); `cancel-in-progress: true` also cancels the **running** one; `queue: max` keeps up to 100 pending FIFO and is invalid with `cancel-in-progress` | [V] 2026-10-10 · *Workflow syntax* |
| C2 | GitLab CI | `resource_group` is the deploy mutex (default process mode `unordered`; `oldest_first` / `newest_first` via the API [K]); `interruptible` defaults to false; `workflow:auto_cancel:on_new_commit` is `conservative` / `interruptible` / `none` | [V] 2026-10-10 · *CI/CD YAML syntax reference* |
| C3 | GitHub Actions | An environment's protection rules all pass before the job reaches a runner; environment secrets are unavailable until a reviewer approves; `deployment: false` skips the deployment object and cannot be combined with custom protection rules | [V] 2026-10-10 · *Workflow syntax*, *Secure use reference* |
| C4 | GitHub Actions | `jobs.<id>.timeout-minutes` defaults to **360**; a step timeout has no default (max 360). `THR-CI-JOB-TIMEOUT` | [V] 2026-10-10 · *Workflow syntax* |
| C5 | GitHub Actions | Scheduled workflows are disabled after **60 days** with no repository activity (public repos) and are disabled by default on public forks | [V] 2026-10-10 · GitHub Docs, *Disabling and enabling workflows* |
| C6 | GitHub Actions | A cache restores from its own branch, the default branch and the PR base branch; PR caches are scoped to `refs/pull/N/merge`; tags are isolated; keys are immutable; 7-day idle eviction; 10 GB default (raisable, billed above); entries are unsigned, and anyone with read access can open a PR and read cache contents | [V] 2026-10-10 · GitHub Docs, *Dependency caching reference* |

## Dated changes that flip verdicts (gate 3)

| Date | Platform | Change | Tag · source |
|---|---|---|---|
| 2025-10-28 | GitHub | Immutable releases GA (`.immutable` on a release) | [V] · GitHub changelog |
| 2025-12-08 | GitHub | `pull_request_target` always runs the default-branch workflow | [V] · GitHub changelog (2025-11-07) |
| 2026-06-18 | GitHub | `actions/checkout` v7.0.0 refuses a fork-PR checkout under `pull_request_target` / `workflow_run` unless `allow-unsafe-pr-checkout: true` | [V] · actions/checkout releases |
| 2026-07-20 | GitHub | The same block backported to v2.8.0 / v3.7.0 / v4.4.0 / v5.1.0 / v6.1.0 | [V] · actions/checkout releases |
| 2026-09-17 | GitHub | Workflow execution protections GA; the default rule disabling `pull_request_target` on public repos is enforced 2026-11-02 | [V] · GitHub changelog |
| — | Helm | Helm 4 renames `--atomic` to `--rollback-on-failure` and changes `--wait` | [K?] · re-read `helm upgrade --help` on the installed major |

Sources: the devops research notes C § 1 and § 8 (sources #1–#11) and A § 9, fetched 2026-10-10.
Paraphrased; no text reproduced.
