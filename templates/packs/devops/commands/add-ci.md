---
description: Generate or update a CI workflow for the detected platform and stack.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /add-ci [platform]

Adds lint + typecheck + test + build pipeline. Detects platform; defaults to GitHub Actions if absent.

> **Note:** For trivial CI additions (1-job test workflow), Phases 1, 3, 5 are 1-line; do not pad.

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
  reason about "the default" — per GitHub's workflow-syntax docs the `GITHUB_TOKEN`'s permissions are
  "initially set to the default setting for the enterprise, organization, or repository", so it is a
  per-repo setting you cannot see from the workflow and it can change without a commit. Declaring
  the block removes the question, and anything not named in it is set to `none`. Then widen **per
  job**, never workflow-wide: `packages: write` on the job that pushes to a container registry
  (without it the push 403s), `id-token: write` on the job that uses OIDC or keyless signing,
  `contents: write` only where a release is actually created.
- **Runner label** — decide, don't inherit. `ubuntu-latest` moves when GitHub rolls the default
  runner image, changing preinstalled tool versions under you; a pinned `ubuntu-<version>` is
  reproducible until you bump it. Pin when the build must be reproducible; take `ubuntu-latest` when
  you would rather meet the rollover early. Record which and why in `ai/runbooks/ci.md`.
- **Action versions are resolved, not remembered** — `gh api repos/<owner>/<repo>/releases/latest
  --jq .tag_name` per action before emitting it. Never a branch ref (`@master` / `@main`). Emit
  `github-actions` in `dependabot.yml` alongside the language ecosystem, or the pins rot.
- Jobs: lint, typecheck, test, build — parallelized; `needs:` only where genuine dependency exists.
- **`security` job** (#48 — on by default; opt out with `--no-security`): dependency vulnerability scan + secret scan, wiring the existing pack skills — `security/skills/deps-audit/SKILL.md` (CVEs / abandoned deps / license issues) + `security/skills/secret-scan/SKILL.md` (leaked secrets in tree + history). Runs in parallel with lint/test; advisories the project hasn't triaged are configurable (warn vs fail). A lint-typecheck-test-build CI with no deps/secret gate is the common gap this closes — keep it in sync with the cited `cicd-pipeline.md` pattern.
- **Coverage threshold** on the `test` job — emit coverage and fail under the project's threshold (`ai/conventions.md § Coverage`, default advisory). Coverage tool from `ai/stack.md § Scripts`.
- Cache step keyed on `<lockfile>-<runs-on>`.
- Artifact upload on successful build.
- Optional `docker-build` job gated on tag push. When present, add a **`hadolint` / image-lint step** before the build (mirrors the `dockerfile-lint` skill: non-root, multi-stage, pinned base, HEALTHCHECK) so a bad Dockerfile fails CI rather than shipping. GitHub Actions: `hadolint/hadolint-action`; GitLab/Bitbucket/Circle: run `hadolint Dockerfile` in the job script (the image is published on Docker Hub).
- **`release-security` step (after the image builds + pushes)** — the build-artifact integrity gate the `release-security` skill executes: image CVE scan (`trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1`), SBOM (`syft` → CycloneDX), digest signing (`cosign sign`, **keyless via the job's OIDC** — not a stored key), and SLSA provenance (`actions/attest-build-provenance` / `cosign attest`). This is what the security pack's `@security-auditor` A03 Supply-Chain check dispatches to — without it, "images scanned / SBOM generated / artifacts signed" is asserted but never produced. Fail the release on an unfixed CRITICAL or a missing signature.
- `concurrency: ci-${{ github.ref }}` with `cancel-in-progress: true`.

## Phase 5 — Update

- `ai/status.md` — Recent Changes entry.
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/runbooks/ci.md` — create or append (job names, cache invalidation, secret rotation).
- Print exact required-check names for the user to set in branch protection (no auto-apply).

## Phase 6 — Validate

- **Dispatch `@ci-reviewer` on the workflow this command just generated**, before the run is
  declared done. A generator that is never read by its own reviewer drifts: the reviewer's findings
  (mutable action pins, missing `permissions:`, expression injection in a `run:`, a scan that runs
  after publish) are exactly the defects this Phase 4 can emit. Treat a Critical/BLOCKER finding as
  a halt — fix Phase 4's output and re-emit, do not ship and file it. If `@ci-reviewer` is not
  installed (minimal mode), say so in the output rather than reporting an unreviewed workflow as
  reviewed.
- Open generated file path so user can review.
- After commit, watch the first run to green; **halt on red**, do not advance to Phase 7 with a failing run. The green-gate command is platform-specific:
  - **GitHub Actions** — `gh run watch` (named; blocks until the run finishes, exits non-zero on failure).
  - **GitLab CI** — no `gh run watch` equivalent; poll `glab ci status` / `glab ci view`, or watch the pipeline in the UI.
  - **Bitbucket Pipelines** — no named CLI watch; poll the Pipelines REST API or watch the UI.
  - **CircleCI** — no named CLI watch; poll `circleci` / the v2 API or watch the UI.

  Only GitHub Actions has the named blocking watch; for the others, surface the poll command and require a green run before Phase 7.
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
- **No `permissions:` block at all.** The failure mode is not "the default is write" — it is that the
  default is a repo/org/enterprise *setting* invisible from the workflow, so the same file is
  least-privilege in one repo and over-scoped in another. Declare it; then the answer is in the file.
- **Untrusted `${{ github.event.* }}` inside a `run:`** — PR titles, branch names and issue bodies are
  substituted into the shell before it executes. Bind to an intermediate `env:` var and use `"$VAR"`.
- Matrix legs on an unsupported runtime major — burns minutes proving compatibility with something
  that no longer receives security patches. Resolve the supported set from the runtime's release schedule.
- Cache key omits OS — cross-platform cache poisoning.
- No `concurrency` block — stale runs pile up on force-pushes.
- No `timeout-minutes:` — a hung job bills until the platform's default cap.

## Related

### Sibling commands in devops pack
- `/dockerize` — sibling command in devops pack

### Agents
- `@ci-reviewer` — dispatched in Phase 6 on the generated workflow. This command writes the pipeline;
  that agent reads it hostilely. A blocker from it halts Phase 7.

### Skills
- `gitops-audit` — the CI pipeline this command builds ends at *publish* (build → test → scan → push image). If the cluster is Argo CD / Flux managed, `gitops-audit` audits what happens **after** publish — the git→cluster reconciliation loop (drift, out-of-band `kubectl apply`, plaintext secrets in git, prune safety). Wire the pipeline here; audit the reconciliation there.

### Patterns
- `ai/patterns/cicd-pipeline.md`
- `ai/patterns/deployment.md`

### Rules
- `.claude/rules/devops-principles.md`
