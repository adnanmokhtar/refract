---
name: cicd-pipeline
description: "Pattern: CI/CD Pipeline"
kind: ai-pattern
pack: devops
---

# Pattern: CI/CD Pipeline

> **Hard rule** — Stages gate sequentially: lint → typecheck → test → build → scan → deploy. Each runs from an immutable artifact (image SHA / binary / lambda zip), prod requires approval, secrets come via OIDC or secret manager. Long-lived cloud keys in workflow files are forbidden.

**When to apply**
- Code is shipped to a hosted environment users reach.
- Multiple contributors merge to main and merge gates are needed.
- Deploy frequency exceeds "once a quarter" — manual deploys break at that cadence.

**When NOT to apply**
- Library / SDK published only on tag — release pipeline differs from CD.
- Local-only tool with no remote deploy target.
- Throwaway prototype with explicit "no CI" decision recorded.

**Halt conditions / mandatory cites**
- Cite the workflow file (`.github/workflows/<name>.yml:<line>`) defining the gate before claiming a stage exists; "we have CI" without a file path is a halt.
- Cite the OIDC trust policy (`<path:line>` of cloud trust config) before any deploy job; static `AWS_ACCESS_KEY_ID` secrets are forbidden.
- Cite the security-scan rule as `<path:line>` (Trivy / Snyk action) with non-zero exit on CRITICAL; scan-as-warning is a halt.
- Cite the prod environment protection rule (`<path>` of repo settings export or doc) showing required reviewers; unguarded prod is a halt.
- Hand-wave grep ban — never claim "no `:latest` tags in prod" without citing the manifest scan or admission-policy file.

## Stages (in order)

```
commit → lint → typecheck → test → build → scan → publish → deploy staging → smoke → deploy prod
```

Each stage gates the next. Fail fast — lint fails = don't run tests.

## Action versions and runner labels are RESOLVED, never copied

Every action version below was current when written and will not be current when you read it.
Major releases land continuously; a pipeline copied out of a document is stale on arrival, and the
staleness is invisible because the workflow keeps passing. Two rules make this survivable:

- **Resolve the current major before you write it** — `gh api repos/<owner>/<repo>/releases/latest
  --jq .tag_name` gives the authoritative answer for any action, from the source rather than from a
  blog or from memory. Do this for each action you emit; it is one call each.
- **Pin the way your threat model requires.** A major tag (`@v7`) is mutable — the owner can move it,
  and a compromised action org moves it for you. A **commit SHA** is the only immutable pin, and it
  needs Dependabot/Renovate to stay current or it rots into an unpatched action. Pick one
  deliberately: SHA + automated bumps for anything that touches secrets or publishes artifacts,
  major tag for the rest. Never a branch ref (`@master`, `@main`) — that is an unpinned
  auto-updating remote dependency inside your release path.
- **`runs-on: ubuntu-latest` is also a moving reference.** GitHub rolls the label to a new image
  version, which changes preinstalled tool versions under you. Pin `ubuntu-<version>` when the
  build must be reproducible; accept `ubuntu-latest` when you would rather get the rollover early
  than late. Decide it; don't inherit it.

## CI example (GitHub Actions, Node stack)

Four structural things in this example are load-bearing, and the obvious shape gets each wrong:

- **What ships is what was scanned.** The image is built **once**. On a pull request it is loaded
  locally and scanned; on `main` it is pushed **by digest only** (no tag points at it), that digest
  is scanned, and only that digest flows to the deploy jobs. Scanning a `load: true` image and then
  publishing a second build is a rebuild: a different artifact from the one the gate passed, and
  `load: true` also drops its attestations (`proof-oracles.md` V223, *digest continuity*).
- **Cancel only what mutates nothing.** `cancel-in-progress` is right for a superseded PR run and
  wrong for any run that deploys: a newer push to `main` would kill the prod deploy mid-apply. Each
  deploy job therefore takes a job-level group keyed on its **environment** with
  `cancel-in-progress: false`, so a second push queues behind the running deploy (V228;
  `precedents/devops.md` § 15).
- **SHA pins where the job is privileged.** The job that holds `packages: write` and `id-token: write`
  pins every `uses:` to a commit SHA (the SHAs shown were resolved on 2026-10-10 and are stale by
  the time you read this — resolve them again); the unprivileged `quality` job keeps major tags
  (§ Action versions above).
- **No credential left in `.git/config`.** Every checkout sets `persist-credentials: false`; nothing
  in this pipeline pushes with git.

`python3 .claude/scripts/ci-graph.py . --check=pin-priv,deploy-concurrency` prints nothing for this
workflow. The earlier shape of this example printed 6 `PIN×PRIV` and 2 `DEPLOY-CANCEL` rows (measured
2026-10-10).

```yaml
name: CI
on:
  push: { branches: [main] }
  pull_request:

permissions:
  contents: read          # narrowest default; each job widens only what it needs

# Cancel a superseded PR run, never a run on main: on main the run deploys, and a cancel there
# kills a deploy mid-apply. Each deploy job also takes its own environment-keyed group below.
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  quality:
    runs-on: ubuntu-latest        # see § Action versions — this label moves
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false  # nothing below pushes with git; keep the token out of .git/config
      - uses: pnpm/action-setup@v6
      - uses: actions/setup-node@v7
        with:
          node-version-file: .nvmrc   # the repo declares the version, not this file
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: pnpm run lint
      - run: pnpm run typecheck
      - run: pnpm run test -- --coverage
      - uses: codecov/codecov-action@v7

  build-scan-publish:
    needs: quality
    runs-on: ubuntu-latest
    timeout-minutes: 20
    permissions:
      contents: read
      packages: write     # REQUIRED to push to ghcr.io with GITHUB_TOKEN — omit it and the push 403s
      id-token: write     # OIDC: keyless cosign signing + cloud auth, no long-lived keys
    outputs:
      digest: ${{ steps.push.outputs.digest }}
    # Every `uses:` in this job is pinned to a full commit SHA: it holds a write token and an OIDC
    # identity, and a moved tag runs someone else's code with both (trivy-action's tags were
    # force-moved in 2026-03). Resolve each SHA with `gh api repos/<o>/<r>/commits/<tag> --jq .sha`;
    # Dependabot's `github-actions` ecosystem keeps the SHA and the comment current.
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
        with:
          persist-credentials: false
      - uses: docker/setup-buildx-action@f87e5991a6d7451dcb8d9637bfbc97413f497069  # v4.4.1

      # 1a. Pull request: build into the local daemon and scan it. No registry write, so a fork PR
      #     cannot publish.
      - if: github.event_name == 'pull_request'
        uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc  # v7.4.0
        with:
          load: true
          tags: ci-local/app:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      # 1b. Push to main: build ONCE and push by digest only. No tag points at it and nothing
      #     deploys it until the gate below passes; the deploy jobs receive this exact digest.
      - if: github.event_name == 'push'
        uses: docker/login-action@dbcb813823bdd20940b903addbd779551569679f  # v4.6.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - id: push
        if: github.event_name == 'push'
        uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc  # v7.4.0
        with:
          outputs: type=image,name=ghcr.io/${{ github.repository }},push-by-digest=true,name-canonical=true,push=true
          cache-from: type=gha
          cache-to: type=gha,mode=max

      # 2. Gate. It scans the artifact that ships: the local build on a PR, the pushed digest on
      #    main. A non-zero exit fails the job, so no deploy job receives the digest.
      - uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25  # v0.36.0
        with:
          image-ref: ${{ github.event_name == 'push' && format('ghcr.io/{0}@{1}', github.repository, steps.push.outputs.digest) || format('ci-local/app:{0}', github.sha) }}
          severity: CRITICAL,HIGH
          ignore-unfixed: true
          exit-code: 1

  deploy-staging:
    needs: build-scan-publish
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    timeout-minutes: 15
    environment: staging
    concurrency:              # one deploy per environment at a time; a newer push waits, never cancels
      group: deploy-staging
      cancel-in-progress: false
    steps:
      - name: Deploy
        env:                  # the DIGEST the gate scanned, never a tag: a tag can move after the scan
          IMAGE: ghcr.io/${{ github.repository }}@${{ needs.build-scan-publish.outputs.digest }}
        run: |
          # kubectl / fly / railway / etc.
          echo "Deploying $IMAGE"

  smoke-test:
    needs: deploy-staging
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - run: curl -f https://staging.example.com/health

  deploy-prod:
    needs: [build-scan-publish, smoke-test]
    runs-on: ubuntu-latest
    timeout-minutes: 15
    environment:
      name: production      # requires manual approval for prod
    concurrency:
      group: deploy-production
      cancel-in-progress: false
    steps:
      - env:
          IMAGE: ghcr.io/${{ github.repository }}@${{ needs.build-scan-publish.outputs.digest }}
        run: echo "Promoting $IMAGE to prod"   # the same digest staging ran, never a rebuild
```

## Principles

### Speed
- Cache dependencies (actions/cache, pnpm cache, apt cache).
- Parallelize independent jobs (`needs:` only when truly dependent).
- Incremental builds (Turbo / Nx / remote cache).
- Target: PR CI < 5 min. Commit to deploy < 15 min.

### Signals
- Every stage reports clearly (green / red / yellow with why).
- Failures link to the failing step + logs.
- Slack / Discord notification on main failures.

### Security
- No secrets in workflow files (use `${{ secrets.X }}`).
- OIDC for cloud auth (no long-lived access keys).
- **Declare `permissions:` explicitly at the top of every workflow.** Do not reason about "the
  default" — the default is an enterprise/org/repo *setting*, so it differs per repo and can be
  changed without touching your workflow. An explicit block also means anything you do not name is
  set to `none`, which is the posture you want. Widen per job, never workflow-wide.
- **Never interpolate untrusted input into a `run:` script.** `${{ github.event.* }}` values — PR
  title, branch name, issue body, commit message — are attacker-controlled and are substituted into
  the shell *before* it runs, so a crafted title is arbitrary code with your token. Bind them to an
  intermediate `env:` variable and reference `"$VAR"` inside the script; the shell then treats the
  value as data. This is the most common Actions vulnerability class and it is invisible on review
  unless you are looking for the `${{ }}` inside the `run:`.
- `pull_request_target` avoided with untrusted code.
- **SHA-pin every `uses:` in a job that holds a write scope, `id-token: write`, an `environment:` or
  a secret**, with the version as a trailing comment and Dependabot's `github-actions` ecosystem
  bumping both. A moved tag runs someone else's code with that job's token (trivy-action's tags were
  force-moved in 2026-03). Attacker-path review of a workflow is the security pack's
  (`ci-security-scan`, else `iac-scan` § 5) when it is installed.
- `persist-credentials: false` on every `actions/checkout` unless a later step pushes with git.
- Scan Docker images **before** anything references them, not after (see the example) — a scan
  that runs after a tagged publish gates the deploy, not the artifact. Then ship **that** digest:
  a second build after the scan is a different artifact.
- SBOM generation + signing (cosign, keyless via OIDC). Sign the digest, not the tag.

### Reliability
- No flaky tests in the CI config — fix them instead of retrying.
- If you MUST retry, retry targeted flake-prone suites, not everything.
- `timeout-minutes:` on every job (prevents hung runs eating billable minutes). It is in the example
  above because "every job" includes the boring ones — a hung deploy job is the expensive case.
- `concurrency:` with `cancel-in-progress` **only where the cancelled unit mutates nothing shared**:
  PR CI and per-PR previews. A deploy, `terraform apply`, migration or publish job takes a job-level
  group keyed on the environment (`deploy-staging`, `deploy-production`) with
  `cancel-in-progress: false`; the default `queue: single` then keeps one running and one pending
  run (`ci-platform-semantics.md` C1). A workflow-level cancel covers every job beneath it,
  including the deploys.

### Deploys
- Deploy via immutable artifact (Docker image / binary / lambda zip), not source. Staging and prod
  receive the **same digest** the scan passed; promotion never rebuilds.
- Environments (`staging`, `production`) configured in repo settings.
- Prod requires approval.
- Rollback = deploy the previous **digest**. One command; a tag may have moved or been pruned.

## GitOps alternative

Instead of CD in CI:
- CI builds image + updates manifests in a `infra/` repo.
- Argo CD / Flux watches the `infra/` repo and syncs cluster state.
- Rollback = git revert.

## Enforcement

The pipeline's own linters and scanners. These live here rather than in the always-loaded rule
because they are a toolbox you reach for while building a pipeline, not an invariant you must hold
in mind on every task — and because tool names are the least durable thing in this pack.

- **Workflow lint:** `actionlint` (syntax, shell, expression errors) and `zizmor` (Actions-specific
  security audit — injection, over-broad permissions, unpinned actions). `nektos/act` runs a job
  locally before you push; it is a smoke check, not proof of a gate (`precedents/devops.md` § 45–46).
- **Pipeline structure:** `.claude/scripts/ci-graph.py` (deploy concurrency, deploy gating, pins ×
  privilege, timeouts) and the `pipeline-integrity-scan` skill (a red build that still merges or
  deploys, on every CI platform).
- **Secrets:** `gitleaks` / `trufflehog` as a pre-commit hook *and* a CI job — the hook catches the
  author, the job catches everyone who bypassed the hook.
- **Images:** `hadolint` lints the Dockerfile, `dive` measures layer waste, `trivy` / `grype` scan
  the built image. The `dockerfile-lint` and `release-security` skills execute these two halves.
- **Dependency updates:** Renovate or Dependabot, grouped by ecosystem. Auto-merging patch bumps on
  green tests is a reasonable default; auto-merging a *major* is how a breaking change reaches main
  unattended. Note that SHA-pinned actions only stay current because one of these is running.
- **Branch protection:** required checks matching the job names verbatim, no force-push to the
  default branch, signed commits where compliance demands them.
- Alert definitions carry a runbook link (e.g. a `runbook_url` annotation) — an alert without one
  is noise within a quarter.

## Forbidden

- Secrets in workflow files.
- `pull_request_target` running untrusted code.
- Untrusted `${{ github.event.* }}` interpolated directly into a `run:` block.
- A branch ref (`@master` / `@main`) as an action version — an unpinned remote dependency in the
  release path, and worse than the mutable major tag it looks like.
- `:latest` image tags pushed to prod.
- Skipping security scans to speed up CI, or running them after publish and calling that a gate.
- CI green but no deploy gate (prod deploy should require approval OR be tag-triggered).
- A workflow-level `cancel-in-progress: true` over a workflow that holds a deploy or publish job.
- Publishing or deploying a rebuild of the image the scan passed.
- A tag-pinned third-party action in a job that holds a write token, an OIDC identity or a secret.
- Flaky tests retried on every run (masks real issues).
