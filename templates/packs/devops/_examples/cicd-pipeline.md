---
name: cicd-pipeline
kind: example
pack: devops
---

# Pattern: CI/CD Pipeline

## Stages (in order)

```
commit → lint → typecheck → test → build → scan → publish → deploy staging → smoke → deploy prod
```

Each stage gates the next. Fail fast — lint fails = don't run tests.

## CI example (GitHub Actions, Node stack)

```yaml
name: CI
on:
  push: { branches: [main] }
  pull_request:

permissions:
  contents: read
  id-token: write      # for OIDC cloud auth

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: pnpm run lint
      - run: pnpm run typecheck
      - run: pnpm run test -- --coverage
      - uses: codecov/codecov-action@v4

  build:
    needs: quality
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          push: ${{ github.event_name == 'push' }}
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  scan:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: aquasecurity/trivy-action@master
        with:
          image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
          severity: CRITICAL,HIGH
          exit-code: 1

  deploy-staging:
    needs: [build, scan]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Deploy
        run: |
          # kubectl / fly / railway / etc.
          echo "Deploying ${{ github.sha }} to staging"

  smoke-test:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
      - run: curl -f https://staging.example.com/health

  deploy-prod:
    needs: smoke-test
    runs-on: ubuntu-latest
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
- `permissions:` scoped to minimum.
- `pull_request_target` avoided with untrusted code.
- Scan Docker images before push.
- SBOM generation + signing (cosign).

### Reliability
- No flaky tests in the CI config — fix them instead of retrying.
- If you MUST retry, retry targeted flake-prone suites, not everything.
- `timeout-minutes:` on every job (prevents hung runs eating billable minutes).

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

## Forbidden

- Secrets in workflow files.
- `pull_request_target` running untrusted code.
- `:latest` image tags pushed to prod.
- Skipping security scans to speed up CI.
- CI green but no deploy gate (prod deploy should require approval OR be tag-triggered).
- Flaky tests retried on every run (masks real issues).
