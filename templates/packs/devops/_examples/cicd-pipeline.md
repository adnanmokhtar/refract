---
name: cicd-pipeline
kind: example
pack: devops
---

# Pattern: CI/CD Pipeline

> **Hard rule** — Stages gate sequentially: lint → typecheck → test → build → scan → deploy. Each runs from an immutable artifact (image SHA / binary / lambda zip), prod requires approval, secrets come via OIDC or secret manager. Long-lived cloud keys in workflow files are forbidden.

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
Majors land continuously, and the staleness is invisible because the workflow keeps passing.

- **Resolve the current major before writing it** — `gh api repos/<owner>/<repo>/releases/latest
  --jq .tag_name` answers authoritatively, from the source rather than from memory.
- **Pin the way your threat model requires.** A major tag (`@v7`) is mutable; a commit SHA is the
  only immutable pin, and it rots unless Dependabot/Renovate bumps it. SHA + automated bumps for
  anything touching secrets or publishing artifacts; major tag for the rest. Never a branch ref
  (`@master`, `@main`) — that is an unpinned auto-updating dependency inside your release path.
- **`runs-on: ubuntu-latest` also moves** when GitHub rolls the default image, changing preinstalled
  tool versions under you. Pin `ubuntu-<version>` when the build must be reproducible. Decide it.

## CI example (GitHub Actions, Node stack)

Two structural things are load-bearing, and the obvious shape gets both wrong: the image is
**scanned before it is published**, and the scan therefore runs in the **same job** that built it
(a locally-loaded image does not cross a job boundary). Publish-then-scan means a vulnerable image
is already pullable when the gate fails.

```yaml
name: CI
on:
  push: { branches: [main] }
  pull_request:

permissions:
  contents: read          # narrowest default; each job widens only what it needs

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    runs-on: ubuntu-latest        # this label moves — see above
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v7
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
      digest: ${{ steps.publish.outputs.digest }}
    steps:
      - uses: actions/checkout@v7
      - uses: docker/setup-buildx-action@v4

      # 1. Build into the local daemon. No registry write, so a fork PR cannot
      #    publish and the scan below has something to inspect.
      - id: build
        uses: docker/build-push-action@v7
        with:
          load: true
          tags: ci-local/app:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      # 2. Gate. Non-zero exit here means nothing is published.
      - uses: aquasecurity/trivy-action@v0.36.0
        with:
          image-ref: ci-local/app:${{ github.sha }}
          severity: CRITICAL,HIGH
          ignore-unfixed: true
          exit-code: 1

      # 3. Publish only on push, only after the gate. Rebuild is cache-hot.
      - if: github.event_name == 'push'
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - id: publish
        if: github.event_name == 'push'
        uses: docker/build-push-action@v7
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
          cache-from: type=gha

  deploy-staging:
    needs: build-scan-publish
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    timeout-minutes: 15
    environment: staging
    steps:
      - name: Deploy
        # Deploy the DIGEST, not the tag — a tag can be moved after the scan passed.
        run: |
          # kubectl / fly / railway / etc.
          echo "Deploying ghcr.io/${{ github.repository }}@${{ needs.build-scan-publish.outputs.digest }}"

  smoke-test:
    needs: deploy-staging
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - run: curl -f https://staging.example.com/health

  deploy-prod:
    needs: smoke-test
    runs-on: ubuntu-latest
    timeout-minutes: 15
    environment:
      name: production
      # requires manual approval for prod
    steps:
      - run: echo "Deploying to prod"
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
- **Declare `permissions:` explicitly at the top of every workflow.** The default is an
  enterprise/org/repo *setting*, so it differs per repo and can change without touching your
  workflow — do not reason about it. An explicit block also sets everything unnamed to `none`.
- **Never interpolate untrusted input into a `run:` script.** `${{ github.event.* }}` values (PR
  title, branch name, issue body) are attacker-controlled and are substituted into the shell before
  it runs. Bind them to an intermediate `env:` variable and reference `"$VAR"` inside the script.
- `pull_request_target` avoided with untrusted code.
- Scan Docker images **before** push — a scan after publish gates the deploy, not the artifact.
- SBOM generation + signing (cosign, keyless via OIDC). Sign the digest, not the tag.

### Reliability
- No flaky tests in the CI config — fix them instead of retrying.
- If you MUST retry, retry targeted flake-prone suites, not everything.
- `timeout-minutes:` on every job — including the boring ones; a hung deploy job is the expensive case.
- `concurrency:` group per ref with `cancel-in-progress`, or force-pushes stack runs that race each
  other to the same environment.

### Deploys
- Deploy via immutable artifact (Docker image / binary / lambda zip), not source.
- Environments (`staging`, `production`) configured in repo settings.
- Prod requires approval.
- Rollback = deploy previous SHA. One command.

## GitOps alternative

Instead of CD in CI:
- CI builds image + updates manifests in a `infra/` repo.
- Argo CD / Flux watches the `infra/` repo and syncs cluster state.
- Rollback = git revert.

## Enforcement

The pipeline's own linters and scanners — a toolbox for building a pipeline, not an invariant to
hold in mind on every task.

- **Workflow lint:** `actionlint` (syntax, shell, expression errors) and `zizmor` (Actions-specific
  security audit — injection, over-broad permissions, unpinned actions). `nektos/act` runs a job locally.
- **Secrets:** `gitleaks` / `trufflehog` as a pre-commit hook *and* a CI job — the hook catches the
  author, the job catches everyone who bypassed the hook.
- **Images:** `hadolint` lints the Dockerfile, `dive` measures layer waste, `trivy` / `grype` scan
  the built image. The `dockerfile-lint` and `release-security` skills execute these two halves.
- **Dependency updates:** Renovate or Dependabot, grouped by ecosystem. Auto-merge patch bumps on
  green tests; auto-merging a *major* is how a breaking change reaches main unattended. SHA-pinned
  actions only stay current because one of these is running.
- **Branch protection:** required checks matching job names verbatim, no force-push to the default
  branch, signed commits where compliance demands them.
- Alert definitions carry a runbook link (e.g. a `runbook_url` annotation).

## Forbidden

- Secrets in workflow files.
- `pull_request_target` running untrusted code.
- Untrusted `${{ github.event.* }}` interpolated directly into a `run:` block.
- A branch ref (`@master` / `@main`) as an action version.
- `:latest` image tags pushed to prod.
- Skipping security scans to speed up CI, or running them after publish and calling that a gate.
- CI green but no deploy gate (prod deploy should require approval OR be tag-triggered).
- Flaky tests retried on every run (masks real issues).
