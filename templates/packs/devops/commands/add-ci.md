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
- **SHA-pin every `uses:` in a privileged job** — one that holds a write scope, `id-token: write`,
  an `environment:` or a secret. Resolve the SHA (`gh api repos/<o>/<r>/commits/<tag> --jq .sha`)
  and keep the version as a trailing comment (`@<sha>  # v7.4.0`); Dependabot bumps both. A moved
  tag runs someone else's code with that job's token. Unprivileged jobs may keep major tags.
- **`persist-credentials: false` on every `actions/checkout`** unless a later step pushes with git.
- Jobs: lint, typecheck, test, build — parallelized; `needs:` only where genuine dependency exists.
- **`security` job** (#48 — on by default; opt out with `--no-security`): dependency vulnerability scan + secret scan, wiring the existing pack skills — `security/skills/deps-audit/SKILL.md` (CVEs / abandoned deps / license issues) + `security/skills/secret-scan-method/SKILL.md` (leaked secrets in tree + history). Runs in parallel with lint/test; advisories the project hasn't triaged are configurable (warn vs fail). A lint-typecheck-test-build CI with no deps/secret gate is the common gap this closes — keep it in sync with the cited `cicd-pipeline.md` pattern.
- **Coverage threshold** on the `test` job — emit coverage and fail under the project's threshold (`ai/conventions.md § Coverage`, default advisory). Coverage tool from `ai/stack.md § Scripts`.
- Cache step keyed on `<lockfile>-<runs-on>`.
- Artifact upload on successful build.
- Optional `docker-build` job gated on tag push. When present, add a **`hadolint` / image-lint step** before the build (the CI half of the `container-build-scan` skill's §9 lane; run it with `--failure-threshold warning`, and fail the step on a `DL1000` parse error, which means the file was never scanned) so a bad Dockerfile fails CI rather than shipping. GitHub Actions: `hadolint/hadolint-action`; GitLab/Bitbucket/Circle: run `hadolint Dockerfile` in the job script (the image is published on Docker Hub).
- **`release-security` step (before anything references the image)** — build the image **once**; on a PR load it locally, on the default branch push it **by digest only** (`outputs: type=image,push-by-digest=true,…` — no tag points at it yet), scan that build, and hand `steps.<id>.outputs.digest` to every later job. Tag, sign and deploy **that digest** after the gate; never publish a second build of the scanned image (a rebuild is a different artifact, and `load: true` drops attestations — `proof-oracles.md` V223). The gate is the build-artifact integrity check the `release-security` skill executes: image CVE scan (`trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1`), SBOM (`syft` → CycloneDX), digest signing (`cosign sign`, **keyless via the job's OIDC** — not a stored key), and SLSA v1 provenance (`actions/attest` v4 — `attest-build-provenance` is now a thin wrapper over it — or `cosign attest --type slsaprovenance1`; `release-security` step 4). This is what the security pack's `@security-auditor` A03 Supply-Chain check dispatches to — without it, "images scanned / SBOM generated / artifacts signed" is asserted but never produced. Fail the release on an unfixed CRITICAL or a missing signature.
- **Concurrency, split by what a cancel would kill.** Workflow level: `group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}` with `cancel-in-progress: ${{ github.event_name == 'pull_request' }}` — superseded PR runs cancel, default-branch runs do not. Every deploy, publish, `terraform apply` or migration job: a job-level `concurrency: { group: deploy-<environment>, cancel-in-progress: false }` keyed on the environment it mutates, so a newer push queues behind it instead of killing it mid-apply (`precedents/devops.md` § 15; `ci-platform-semantics.md` C1). Never `ci-${{ github.ref }}` + `cancel-in-progress: true` over a workflow that holds the docker publish job. GitLab: `resource_group: <environment>` on the deploy job and `interruptible: true` only on the jobs before it.

## Phase 5 — Update

- `ai/status.md` — Recent Changes entry.
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/runbooks/ci.md` — create or append (job names, cache invalidation, secret rotation).
- Print exact required-check names for the user to set in branch protection (no auto-apply).

## Phase 6 — Validate

- **Run the detectors on the emitted file before anything else.** Every row is a defect this
  Phase 4 emitted; fix Phase 4's output and re-emit — never ship and file it.
  1. **Graph** (GitHub Actions): `python3 .claude/scripts/ci-graph.py <emitted file> --check=pin-priv,deploy-concurrency,deploy-gate,timeout`
     (fallback `$HOME/.claude/templates/repo-baseline/.claude/scripts/ci-graph.py`) prints nothing.
     Exit 2 is `NOT-RUN (no YAML loader)`, printed as such — never "clean".
  2. **`pipeline-integrity-scan`** (this pack), §1–§8 on the emitted file only: masked non-domain
     gates, pipes that lose a gate's exit, required checks a skip satisfies, deploy or publish not
     gated on tests, unvalidated refs, timeouts, matrix, schedules. On GitLab, CircleCI, Bitbucket,
     Azure and Jenkins it runs its grep lanes, because the graph does not model them.
  3. **Security review of the emitted file** — `ci-security-scan` when the security pack is
     installed (until that skill ships, `iac-scan` § 5, *CI workflows*). It owns every attacker-path
     class: injection, privileged triggers, pins × privilege, cache poisoning, OIDC width, secrets.
     **Without the security pack,** `pipeline-integrity-scan`'s fallback lane runs those greps and
     tags its rows `security-class (owner pack not installed)`, and the output prints
     `security: owner pack not installed — fallback lane ran` instead of a security PASS.
  A High or Critical row from any of the three halts here.
- **Then dispatch `@ci-reviewer` on the workflow this command just generated**, before the run is
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

Pins:    docker job SHA-pinned (resolved via `gh api …/commits/<tag>`); lint/test jobs on major tags
Concurrency: PR runs cancel · docker publish job group publish-ghcr, cancel-in-progress: false

ci-graph.py: 0 rows (pin-priv, deploy-concurrency, deploy-gate, timeout)
pipeline-integrity-scan: 0 findings (§1–§8 on .github/workflows/ci.yml)
ci-security-scan: 0 findings (security pack)       # or: security: owner pack not installed — fallback lane ran
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
- **No `permissions:` block at all.** The failure mode is not "the default is write" — it is that the
  default is a repo/org/enterprise *setting* invisible from the workflow, so the same file is
  least-privilege in one repo and over-scoped in another. Declare it; then the answer is in the file.
- **Untrusted `${{ github.event.* }}` inside a `run:`** — PR titles, branch names and issue bodies are
  substituted into the shell before it executes. Bind to an intermediate `env:` var and use `"$VAR"`.
- Matrix legs on an unsupported runtime major — burns minutes proving compatibility with something
  that no longer receives security patches. Resolve the supported set from the runtime's release schedule.
- Cache key omits OS — cross-platform cache poisoning.
- No `concurrency` block — stale runs pile up on force-pushes.
- **A workflow-level `cancel-in-progress: true` over a deploy or publish job** — a newer push kills
  the running deploy mid-apply. Cancel PR runs only; key each deploy job's group on its environment.
- **Scanning one build and publishing another** — what ships is not what the gate passed. Push the
  scanned build by digest and deploy that digest.
- No `timeout-minutes:` — a hung job bills until the platform's default cap.

## Related

### Sibling commands in devops pack
- `/dockerize` — sibling command in devops pack

### Agents
- `@ci-reviewer` — dispatched in Phase 6 on the generated workflow. This command writes the pipeline;
  that agent reads it hostilely. A blocker from it halts Phase 7.

### Skills
- `pipeline-integrity-scan` — run in Phase 6 on the emitted file; its §1–§8 rows are the delivery defects a generated pipeline most often carries. Its verdicts cite [`precedents/devops.md`](../../../snippets/precedents/devops.md) and [`ci-platform-semantics.md`](../../../snippets/ci-platform-semantics.md).
- `ci-security-scan` / `iac-scan` § 5 (security pack, when installed) — the attacker-path review of the same file.
- `gitops-audit` — the CI pipeline this command builds ends at *publish* (build → test → scan → push image). If the cluster is Argo CD / Flux managed, `gitops-audit` audits what happens **after** publish — the git→cluster reconciliation loop (out-of-band `kubectl`/`helm` applies, live drift, drift nobody sees). The controller spec (prune, sync waves, `selfHeal` × HPA) is infrastructure `k8s-render-scan` §4's, and a plaintext `kind: Secret` in git is security `iac-scan` §3's, each when its pack is installed. Wire the pipeline here; audit the reconciliation there.

### Patterns
- `ai/patterns/cicd-pipeline.md`
- `ai/patterns/deployment.md`

### Rules
- `.claude/rules/devops-principles.md`
