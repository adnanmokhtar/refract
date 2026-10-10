# Seeded defects — `ci-defects`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: `Acme Shop` — a NestJS 11 / Fastify monorepo shipped from six CI platforms (GitHub Actions, GitLab, CircleCI, Bitbucket, Azure, Jenkins), with Dockerfiles, compose, kustomize, Argo Rollouts, Argo CD, release-please, changesets and offline GitHub settings snapshots.
Pipeline integrity, CI caches, release integrity, deploy safety and config parity, container builds, compose,
progressive delivery and GitOps drift — seeded across every platform file, five service roots and `deploy/` — plus
28 hand-offs to the security, testing, infrastructure and observability audits, and 28 decoys: correct siblings that
look like a seeded defect and must NOT be reported.

Invocation: /devops-audit --whole-repo
Invocation[/security-audit]: /security-audit
Invocation[/test-audit]: /test-audit --whole-repo
Invocation[/infra-audit]: /infra-audit --whole-repo
Invocation[/obs-audit]: /obs-audit --whole-repo
Stage with: --git — the audits read the history for their context map, and a whole-repo run on a copy with no base
branch says so with the flag instead of leaving the diff lookup to fail.

Eval source: Track A batch 4, item 27 (`eval-batch4-devops.md` § 4.7). Classes follow the owning skills' own § numbering
(`templates/packs/devops/skills/*/SKILL.md`; the routed rows name their owner's skill and §). Roots: `apps/api`
(NestJS 11.1 on `@nestjs/platform-fastify`, MikroORM 6.4, BullMQ producer, Unleash, Joi config schema), `apps/worker`
(BullMQ consumer, MikroORM CLI), `apps/web` (React 19 + Vite, OpenFeature, nginx final stage), `apps/admin` (NestJS +
Prisma, one replica — the decoy service), `services/billing-go` (Go 1.24, distroless), `services/reports-py` (FastAPI +
Alembic + gunicorn, `uv`), `packages/sdk` (npm, changesets). CI: 13 GitHub workflows plus `.github/actions/setup`,
`.gitlab-ci.yml` (billing), `.circleci/config.yml` (reports tests and client publish), `bitbucket-pipelines.yml`
(reports deploy), `azure-pipelines.yml` (admin deploy), `Jenkinsfile.groovy` (worker). Deploy: kustomize `deploy/k8s`
(base, staging and prod overlays, the billing migration Job), `deploy/rollouts` (three Rollouts, three
AnalysisTemplates), `deploy/web` + `deploy/argocd/app-web.yaml` (Argo CD owns `shop-web`), the billing Helm chart,
`deploy/ecr-lifecycle.json`, `deploy/monitoring` (deploy-path alerts). Compose: `compose.yaml`, `compose.override.yaml`,
`compose.prod.yaml`, `scripts/deploy-host.sh`.

**Settings are scored offline.** `.refract-fixture/gh-api/` holds the verbatim response shapes of
`GET /repos/acme/shop/rules/branches/main` (required contexts `all-green`, `test`, `build`, `image-scan`, `web-green`;
a `merge_queue` rule), `/rulesets` (one branch ruleset, no tag ruleset) and `/environments` (production with
`deployment_branch_policy: null`). `ci-graph.py` takes them as `--contexts=all-green,test,build,image-scan,web-green
--merge-queue`; a real repo answers the same calls with `gh api`. The rows that rest on them are CD-PI-03a–d, CD-PI-05a,
CD-DS-03b and CD-RI-01a.

Departures from the eval, stated so a reader can audit them:
- **Routing owners follow the task, not the eval's perf/db rows.** The eval routed one row to `/perf-audit` (a terminus
  liveness ping) and one to `/db-audit` (a `DROP COLUMN`). This key has no perf or db run: the `DROP COLUMN` stays as
  the evidence of CD-DS-01e (devops' DP-1d, auto-rollback over a contract migration), and two observability rows
  (`alert-rule-lint` §1/§4 through `rule-inventory.py`) take the freed slots. 20 security + 3 testing + 3
  infrastructure + 2 observability = 28.
- **`ci-graph.py` has no `--rules-file`/`--env-file`** (the eval's names); it takes `--contexts=` and `--merge-queue`.
- **CD-PI-03d** is the `always()` + `!= "failure"` aggregator (`AGGREGATOR-WEAK`), the shape the graph decides; the
  eval's `!failure()` form prints no graph row.
- **The gitops pair targets the Argo-managed `shop-web` namespace** (`deploy/argocd/app-web.yaml`): the CI step is in
  `deploy.yml`'s `deploy-web` job, not in `ci.yml`, so PR CI holds no deploy verb.
- **CD-DS-03a** (a prod deploy with no environment) is GitLab's `deploy_billing`, so `hotfix.yml` can carry the
  environment-keyed split group (CD-DS-02c); the eval put both on `hotfix.yml`.
- **The migrate-on-entrypoint seed is the worker's** (`apps/worker/entrypoint.sh`, CD-DS-01b): the api ships
  `CMD npm start` (CD-CB-02a), so a second entrypoint would have hidden that row.
- **The VITE per-environment build arg is dropped from release §4**: a static SPA built per environment is precedents
  § 20. Release §4's third seed is a GitLab scan by tag after the push (CD-RI-04c). Release §3 gains `twine upload`
  on CircleCI; total release rows 17, deploy rows 18 (the eval's 16 and 17).
- **Bitbucket carries no security seed**: the eval's security list names none for it.
- **File names chosen for the scorer**: `score.py` keys a finding on the file's basename and cannot parse a bare
  `Jenkinsfile`, so the Jenkins pipeline is `Jenkinsfile.groovy` (every detector globs `Jenkinsfile*`), the admin image
  is `apps/admin/Containerfile` and the storefront's is `apps/web/Dockerfile.web` — otherwise a report on a decoy in one
  `Dockerfile` is credited to a seed at a nearby line of another `Dockerfile` (IR-10).
- **The compose drain is gunicorn's 25 s** (`--graceful-timeout 25`), so the infrastructure grace row reads 20 s
  against 25 s instead of the eval's 30 s against 45 s.

Ownership and scoring. Five runs, five results rows, each staged in its own copy. **`/devops-audit`** (the
`Invocation:` line) scores the 117 devops rows: a whole-repo run dispatches all eight detectors plus `ci-graph.py`.
The 28 `CD-HO-*` hand-off rows are scored **only under their owner** — `/security-audit` (20: `ci-security-scan` §1–§6,
§9 and `iac-scan` §1–§3), `/test-audit` (3: `suite-execution-scan` §4, §6), `/infra-audit` (3: `k8s-availability-scan`
§6, §7 and `k8s-render-scan` §4), `/obs-audit` (2: `alert-rule-lint` §1, §4) — and `/devops-audit` must list each as a
routed row, never grade it; a `/devops-audit` finding on them is UNMATCHED, not credited.

Secrets. None. Every credential is a `${{ secrets.* }}` reference, a `secretKeyRef` or a `CANARY` placeholder
(`STRIPE_API_KEY=CANARY-placeholder-not-a-key`, `POSTGRES_PASSWORD: canary-placeholder`). Security rows are
configuration shapes only; no exploit payload is in the tree. SHAs and digests are fixture values, not real pins.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`, which also fails if a decoy sits close enough to a defect in the
same file for their scoring windows to overlap. If you edit fixture source, re-run it.

## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| CD-PI-01a | `.github/workflows/ci.yml:114` | critical | `/devops-audit` | pipeline/masked-gate |
| CD-PI-01b | `.gitlab-ci.yml:32` | high | `/devops-audit` | pipeline/masked-gate |
| CD-PI-01c | `Jenkinsfile.groovy:33` | high | `/devops-audit` | pipeline/masked-gate |
| CD-PI-01d | `azure-pipelines.yml:28` | high | `/devops-audit` | pipeline/masked-gate |
| CD-PI-02a | `.github/workflows/ci.yml:120` | critical | `/devops-audit` | pipeline/exit-lost-in-pipe |
| CD-PI-02b | `bitbucket-pipelines.yml:21` | high | `/devops-audit` | pipeline/exit-lost-in-pipe |
| CD-PI-02c | `Jenkinsfile.groovy:26` | high | `/devops-audit` | pipeline/exit-lost-in-pipe |
| CD-PI-03a | `.github/workflows/ci.yml:4` | critical | `/devops-audit` | pipeline/required-check-path-filtered |
| CD-PI-03b | `.github/workflows/ci.yml:44` | critical | `/devops-audit` | pipeline/required-check-skipped |
| CD-PI-03c | `.github/workflows/ci.yml:2` | high | `/devops-audit` | pipeline/merge-queue-not-triggered |
| CD-PI-03d | `.github/workflows/ci.yml:156` | high | `/devops-audit` | pipeline/aggregator-weak |
| CD-PI-04a | `.github/workflows/deploy.yml:85` | critical | `/devops-audit` | pipeline/deploy-ungated |
| CD-PI-04b | `.github/workflows/release.yml:12` | critical | `/devops-audit` | pipeline/publish-ungated |
| CD-PI-04c | `.gitlab-ci.yml:87` | critical | `/devops-audit` | pipeline/deploy-ungated |
| CD-PI-04d | `Jenkinsfile.groovy:41` | critical | `/devops-audit` | pipeline/deploy-ungated |
| CD-PI-04e | `.github/workflows/promote.yml:12` | high | `/devops-audit` | pipeline/workflow-run-no-conclusion |
| CD-PI-05a | `.github/workflows/deploy.yml:91` | high | `/devops-audit` | pipeline/unvalidated-ref |
| CD-PI-05b | `.gitlab-ci.yml:89` | high | `/devops-audit` | pipeline/unvalidated-ref |
| CD-PI-06a | `.github/workflows/deploy.yml:83` | medium | `/devops-audit` | pipeline/no-timeout |
| CD-PI-06b | `.github/workflows/deploy.yml:79` | medium | `/devops-audit` | pipeline/unbounded-wait |
| CD-PI-07a | `.github/workflows/ci.yml:68` | medium | `/devops-audit` | pipeline/matrix-excludes-runtime |
| CD-PI-07b | `.github/workflows/ci.yml:81` | medium | `/devops-audit` | pipeline/matrix-dynamic-unguarded |
| CD-PI-08a | `.github/workflows/nightly.yml:13` | high | `/devops-audit` | pipeline/schedule-dead |
| CD-PI-08b | `.github/workflows/nightly.yml:5` | low | `/devops-audit` | pipeline/schedule-dead |
| CD-PC-01a | `.github/workflows/ci-web.yml:66` | medium | `/devops-audit` | cache/key-no-lockfile |
| CD-PC-01b | `.circleci/config.yml:31` | medium | `/devops-audit` | cache/key-no-lockfile |
| CD-PC-01c | `.github/workflows/_build.yml:34` | high | `/devops-audit` | cache/prefix-restore-skips-install |
| CD-PC-02a | `.github/workflows/_build.yml:50` | low | `/devops-audit` | cache/buildx-mode-min |
| CD-PC-02b | `.github/workflows/_build.yml:57` | low | `/devops-audit` | cache/buildx-shared-scope |
| CD-PC-03a | `.github/workflows/ci.yml:38` | medium | `/devops-audit` | cache/affected-shallow-clone |
| CD-PC-03b | `.github/workflows/ci-web.yml:3` | medium | `/devops-audit` | cache/pr-workflow-no-concurrency |
| CD-PC-04a | `.github/workflows/ci-web.yml:43` | low | `/devops-audit` | cache/serial-chain |
| CD-PC-04b | `.gitlab-ci.yml:3` | low | `/devops-audit` | cache/serial-stages |
| CD-RI-01a | `.github/workflows/release.yml:4` | high | `/devops-audit` | release/ref-movable |
| CD-RI-01b | `.gitlab-ci.yml:56` | high | `/devops-audit` | release/ref-movable |
| CD-RI-02a | `apps/api/package.json:3` | medium | `/devops-audit` | release/version-split |
| CD-RI-02b | `.changeset/pre.json:2` | medium | `/devops-audit` | release/prerelease-left-on |
| CD-RI-03a | `.github/workflows/release.yml:29` | medium | `/devops-audit` | release/non-idempotent |
| CD-RI-03b | `.github/workflows/release.yml:73` | high | `/devops-audit` | release/non-idempotent |
| CD-RI-03c | `.circleci/config.yml:57` | medium | `/devops-audit` | release/non-idempotent |
| CD-RI-04a | `.github/workflows/deploy.yml:100` | critical | `/devops-audit` | release/shipped-not-tested |
| CD-RI-04b | `.github/workflows/release.yml:68` | high | `/devops-audit` | release/rebuild-after-scan |
| CD-RI-04c | `.gitlab-ci.yml:61` | high | `/devops-audit` | release/scan-by-tag |
| CD-RI-05a | `scripts/verify-release.sh:5` | high | `/devops-audit` | release/verify-any-identity |
| CD-RI-05b | `scripts/verify-release.sh:6` | high | `/devops-audit` | release/verify-any-repo |
| CD-RI-05c | `.github/workflows/release.yml:77` | medium | `/devops-audit` | release/sbom-attached-not-attested |
| CD-RI-06a | `.github/workflows/release-pr.yml:17` | medium | `/devops-audit` | release/bot-token-no-checks |
| CD-RI-06b | `.github/workflows/release-pr.yml:29` | medium | `/devops-audit` | release/bot-token-no-checks |
| CD-RI-07a | `.github/workflows/ghcr-cleanup.yml:24` | high | `/devops-audit` | release/rollback-target-pruned |
| CD-RI-07b | `deploy/ecr-lifecycle.json:9` | high | `/devops-audit` | release/rollback-target-pruned |
| CD-DS-01a | `apps/api/src/main.ts:10` | high | `/devops-audit` | deploy/migrate-on-boot-multi-replica |
| CD-DS-01b | `apps/worker/entrypoint.sh:4` | high | `/devops-audit` | deploy/migrate-on-boot-multi-replica |
| CD-DS-01c | `deploy/k8s/base/reports-deployment.yaml:18` | high | `/devops-audit` | deploy/migrate-in-init-container |
| CD-DS-01d | `.gitlab-ci.yml:92` | high | `/devops-audit` | deploy/migrate-after-rollout |
| CD-DS-01e | `bitbucket-pipelines.yml:22` | high | `/devops-audit` | deploy/auto-rollback-over-contract |
| CD-DS-02a | `.github/workflows/deploy.yml:14` | high | `/devops-audit` | deploy/concurrency-cancels-deploy |
| CD-DS-02b | `.gitlab-ci.yml:77` | high | `/devops-audit` | deploy/concurrency-cancels-deploy |
| CD-DS-02c | `.github/workflows/hotfix.yml:29` | high | `/devops-audit` | deploy/split-concurrency-groups |
| CD-DS-03a | `.gitlab-ci.yml:84` | critical | `/devops-audit` | deploy/environment-unprotected |
| CD-DS-03b | `.refract-fixture/gh-api/environments.json:36` | critical | `/devops-audit` | deploy/environment-unprotected |
| CD-DS-04a | `.github/workflows/deploy.yml:107` | high | `/devops-audit` | deploy/rollout-not-waited |
| CD-DS-04b | `.gitlab-ci.yml:82` | high | `/devops-audit` | deploy/rollout-not-waited |
| CD-DS-05a | `apps/api/src/main.ts:12` | high | `/devops-audit` | deploy/shutdown-hooks-inert |
| CD-DS-05b | `apps/worker/src/main.ts:10` | high | `/devops-audit` | deploy/no-shutdown-handler |
| CD-DS-05c | `services/billing-go/cmd/billing/main.go:19` | high | `/devops-audit` | deploy/no-shutdown-handler |
| CD-DS-06a | `apps/api/src/payments/stripe-webhook.controller.ts:12` | high | `/devops-audit` | parity/config-undeclared |
| CD-DS-06b | `services/reports-py/app/exports.py:12` | medium | `/devops-audit` | parity/config-undeclared |
| CD-DS-06c | `apps/worker/Dockerfile:2` | medium | `/devops-audit` | parity/runtime-drift |
| CD-PD-01a | `flags/flags.yaml:18` | low | `/devops-audit` | delivery/dead-flag |
| CD-PD-02a | `apps/api/src/invoices/invoice.flags.ts:2` | low | `/devops-audit` | delivery/stale-flag |
| CD-PD-05a | `deploy/rollouts/analysis-template.yaml:14` | high | `/devops-audit` | delivery/canary-never-fails |
| CD-PD-05b | `deploy/rollouts/analysis-template.yaml:29` | high | `/devops-audit` | delivery/canary-unscoped |
| CD-PD-05c | `deploy/rollouts/reports-rollout.yaml:2` | high | `/devops-audit` | delivery/canary-no-analysis |
| CD-PD-08a | `apps/web/src/flags.ts:7` | medium | `/devops-audit` | delivery/unsafe-default |
| CD-PD-08b | `apps/api/src/refunds/refund.service.ts:15` | high | `/devops-audit` | delivery/unsafe-default |
| CD-PD-09a | `apps/web/src/search/SearchPage.tsx:5` | medium | `/devops-audit` | delivery/build-time-flag |
| CD-PD-09b | `flags/flags.yaml:25` | medium | `/devops-audit` | delivery/build-time-flag |
| CD-GO-01a | `scripts/hotfix.sh:6` | high | `/devops-audit` | gitops/out-of-band-mutation |
| CD-GO-01b | `.github/workflows/deploy.yml:122` | high | `/devops-audit` | gitops/out-of-band-mutation |
| CD-CB-01a | `apps/web/Dockerfile.web:28` | medium | `/devops-audit` | container/named-user-runasnonroot |
| CD-CB-01b | `apps/api/Dockerfile:23` | medium | `/devops-audit` | container/named-user-runasnonroot |
| CD-CB-02a | `apps/api/Dockerfile:26` | high | `/devops-audit` | container/pid1-signal |
| CD-CB-02b | `apps/worker/Dockerfile:21` | high | `/devops-audit` | container/pid1-signal |
| CD-CB-02c | `services/reports-py/Dockerfile:16` | medium | `/devops-audit` | container/pid1-signal |
| CD-CB-03a | `apps/api/Dockerfile:13` | medium | `/devops-audit` | container/layer-order |
| CD-CB-03b | `services/reports-py/Dockerfile:8` | medium | `/devops-audit` | container/layer-order |
| CD-CB-04a | `apps/api/Dockerfile:14` | high | `/devops-audit` | container/lockfile-not-enforced |
| CD-CB-04b | `services/reports-py/Dockerfile:9` | medium | `/devops-audit` | container/lockfile-not-enforced |
| CD-CB-04c | `apps/worker/Dockerfile:9` | high | `/devops-audit` | container/lockfile-not-enforced |
| CD-CB-05a | `services/reports-py/Dockerfile:10` | medium | `/devops-audit` | container/heredoc-no-errexit |
| CD-CB-05b | `services/billing-go/Dockerfile:9` | low | `/devops-audit` | container/run-cd-relative-workdir |
| CD-CB-05c | `services/billing-go/Dockerfile:10` | medium | `/devops-audit` | container/arg-scope |
| CD-CB-06a | `apps/api/Dockerfile:25` | medium | `/devops-audit` | container/healthcheck-binary-missing |
| CD-CB-06b | `apps/worker/Dockerfile:20` | medium | `/devops-audit` | container/healthcheck-wrong-port |
| CD-CB-07a | `apps/web/Dockerfile.web:2` | medium | `/devops-audit` | container/base-eol |
| CD-CB-07b | `services/billing-go/Dockerfile:4` | medium | `/devops-audit` | container/platform-constant |
| CD-CB-07c | `apps/api/Dockerfile:20` | high | `/devops-audit` | container/libc-mismatch |
| CD-CB-08a | `apps/worker/Dockerfile:16` | low | `/devops-audit` | container/builder-residue |
| CD-CB-08b | `services/reports-py/Dockerfile:7` | medium | `/devops-audit` | container/build-tools-shipped |
| CD-CB-09a | `services/billing-go/Dockerfile:16` | low | `/devops-audit` | container/duplicate-cmd |
| CD-CB-09b | `services/reports-py/Dockerfile:6` | low | `/devops-audit` | container/apt-update-alone |
| CD-CB-10a | `SECURITY.md:8` | high | `/devops-audit` | container/reproducibility-claimed-not-built |
| CD-CB-10b | `services/reports-py/Dockerfile:3` | medium | `/devops-audit` | container/base-by-tag-under-claim |
| CD-CP-01a | `compose.yaml:37` | medium | `/devops-audit` | compose/depends-on-ungated |
| CD-CP-01b | `compose.yaml:32` | medium | `/devops-audit` | compose/depends-on-ungated |
| CD-CP-02a | `compose.yaml:58` | medium | `/devops-audit` | compose/healthcheck-never-healthy |
| CD-CP-02b | `compose.yaml:17` | medium | `/devops-audit` | compose/healthy-gate-no-healthcheck |
| CD-CP-03a | `compose.yaml:8` | medium | `/devops-audit` | compose/interpolation-no-default |
| CD-CP-03b | `compose.yaml:10` | medium | `/devops-audit` | compose/interpolation-no-default |
| CD-CP-04a | `scripts/deploy-host.sh:8` | high | `/devops-audit` | compose/override-loaded-in-prod |
| CD-CP-04b | `compose.override.yaml:6` | high | `/devops-audit` | compose/debug-port |
| CD-CP-05a | `compose.prod.yaml:12` | medium | `/devops-audit` | compose/image-untagged |
| CD-CP-05b | `compose.prod.yaml:4` | medium | `/devops-audit` | compose/image-latest |
| CD-CP-06a | `compose.yaml:1` | low | `/devops-audit` | compose/legacy-key |
| CD-CP-06b | `compose.yaml:24` | medium | `/devops-audit` | compose/scale-blocker |
| CD-CP-07a | `compose.yaml:48` | medium | `/devops-audit` | compose/oneshot-restart-always |
| CD-CP-07b | `compose.yaml:40` | medium | `/devops-audit` | compose/stop-grace-short |
| CD-HO-SEC-a | `.github/workflows/issue-triage.yml:35` | critical | `/security-audit` | security/privileged-trigger-untrusted-checkout |
| CD-HO-SEC-b | `.github/workflows/pr-target.yml:23` | critical | `/security-audit` | security/privileged-trigger-untrusted-checkout |
| CD-HO-SEC-c | `.github/workflows/issue-triage.yml:21` | critical | `/security-audit` | security/expression-injection |
| CD-HO-SEC-d | `.github/workflows/issue-triage.yml:45` | critical | `/security-audit` | security/expression-injection |
| CD-HO-SEC-e | `.github/workflows/issue-triage.yml:22` | high | `/security-audit` | security/github-env-injection |
| CD-HO-SEC-f | `.github/actions/setup/action.yml:14` | high | `/security-audit` | security/composite-input-injection |
| CD-HO-SEC-g | `.github/workflows/issue-triage.yml:62` | critical | `/security-audit` | security/ai-agent-untrusted-input |
| CD-HO-SEC-h | `.github/workflows/release.yml:50` | high | `/security-audit` | security/pin-privilege |
| CD-HO-SEC-i | `.github/workflows/deploy.yml:63` | medium | `/security-audit` | security/image-no-digest |
| CD-HO-SEC-j | `.github/workflows/release.yml:23` | high | `/security-audit` | security/cache-in-release |
| CD-HO-SEC-k | `.gitlab-ci.yml:41` | critical | `/security-audit` | security/expression-injection |
| CD-HO-SEC-l | `Jenkinsfile.groovy:19` | critical | `/security-audit` | security/expression-injection |
| CD-HO-SEC-m | `azure-pipelines.yml:17` | high | `/security-audit` | security/logging-command-injection |
| CD-HO-SEC-n | `.circleci/config.yml:50` | high | `/security-audit` | security/expression-injection |
| CD-HO-SEC-o | `apps/worker/Dockerfile:4` | high | `/security-audit` | security/container-root |
| CD-HO-SEC-p | `apps/api/Dockerfile:11` | high | `/security-audit` | security/secret-build-arg |
| CD-HO-SEC-q | `compose.yaml:53` | high | `/security-audit` | security/compose-exposure |
| CD-HO-SEC-r | `deploy/k8s/overlays/prod/kustomization.yaml:9` | high | `/security-audit` | security/deploy-by-mutable-tag |
| CD-HO-SEC-s | `.github/workflows/release.yml:31` | medium | `/security-audit` | security/long-lived-publish-token |
| CD-HO-SEC-t | `.github/workflows/release.yml:6` | medium | `/security-audit` | security/workflow-write-permissions |
| CD-HO-TST-a | `.github/workflows/ci.yml:45` | critical | `/test-audit` | testing/required-test-job-masked |
| CD-HO-TST-b | `apps/api/package.json:9` | medium | `/test-audit` | testing/zero-tests-pass |
| CD-HO-TST-c | `.gitlab-ci.yml:26` | medium | `/test-audit` | testing/retry-no-gate |
| CD-HO-INF-a | `deploy/k8s/base/reports-deployment.yaml:14` | medium | `/infra-audit` | infrastructure/shutdown-grace |
| CD-HO-INF-b | `deploy/k8s/base/api-deployment.yaml:8` | medium | `/infra-audit` | infrastructure/revision-history-zero |
| CD-HO-INF-c | `deploy/argocd/app-web.yaml:18` | high | `/infra-audit` | infrastructure/gitops-replicas-vs-hpa |
| CD-HO-OBS-a | `deploy/monitoring/rollout-alerts.rules.yml:6` | high | `/obs-audit` | observability/selector-not-in-inventory |
| CD-HO-OBS-b | `deploy/monitoring/rollout-alerts.rules.yml:13` | medium | `/obs-audit` | observability/page-without-for |

Severity split: 19 critical · 61 high · 53 medium · 12 low. Total 145 seeded defects (117 scored under `/devops-audit`, 20 under `/security-audit`, 3 under `/test-audit`, 3 under `/infra-audit`, 2 under `/obs-audit`), 28 decoys.

### Coverage by detector §

One row per detector §; every devops § carries at least two seeds, except `progressive-delivery` §1 and §2, one each (the eval counts them as one row, §1–§2).

| detector § | classes | seeded | ids |
|------------|---------|--------|-----|
| `pipeline-integrity-scan §1` | pipeline/masked-gate | 4 | CD-PI-01a, CD-PI-01b, CD-PI-01c, CD-PI-01d |
| `pipeline-integrity-scan §2` | pipeline/exit-lost-in-pipe | 3 | CD-PI-02a, CD-PI-02b, CD-PI-02c |
| `pipeline-integrity-scan §3` | pipeline/aggregator-weak, pipeline/merge-queue-not-triggered, pipeline/required-check-path-filtered, pipeline/required-check-skipped | 4 | CD-PI-03a, CD-PI-03b, CD-PI-03c, CD-PI-03d |
| `pipeline-integrity-scan §4` | pipeline/deploy-ungated, pipeline/publish-ungated, pipeline/workflow-run-no-conclusion | 5 | CD-PI-04a, CD-PI-04b, CD-PI-04c, CD-PI-04d, CD-PI-04e |
| `pipeline-integrity-scan §5` | pipeline/unvalidated-ref | 2 | CD-PI-05a, CD-PI-05b |
| `pipeline-integrity-scan §6` | pipeline/no-timeout, pipeline/unbounded-wait | 2 | CD-PI-06a, CD-PI-06b |
| `pipeline-integrity-scan §7` | pipeline/matrix-dynamic-unguarded, pipeline/matrix-excludes-runtime | 2 | CD-PI-07a, CD-PI-07b |
| `pipeline-integrity-scan §8` | pipeline/schedule-dead | 2 | CD-PI-08a, CD-PI-08b |
| `pipeline-cache-scan §1` | cache/key-no-lockfile, cache/prefix-restore-skips-install | 3 | CD-PC-01a, CD-PC-01b, CD-PC-01c |
| `pipeline-cache-scan §2` | cache/buildx-mode-min, cache/buildx-shared-scope | 2 | CD-PC-02a, CD-PC-02b |
| `pipeline-cache-scan §3` | cache/affected-shallow-clone, cache/pr-workflow-no-concurrency | 2 | CD-PC-03a, CD-PC-03b |
| `pipeline-cache-scan §4` | cache/serial-chain, cache/serial-stages | 2 | CD-PC-04a, CD-PC-04b |
| `release-integrity-scan §1` | release/ref-movable | 2 | CD-RI-01a, CD-RI-01b |
| `release-integrity-scan §2` | release/prerelease-left-on, release/version-split | 2 | CD-RI-02a, CD-RI-02b |
| `release-integrity-scan §3` | release/non-idempotent | 3 | CD-RI-03a, CD-RI-03b, CD-RI-03c |
| `release-integrity-scan §4` | release/rebuild-after-scan, release/scan-by-tag, release/shipped-not-tested | 3 | CD-RI-04a, CD-RI-04b, CD-RI-04c |
| `release-integrity-scan §5` | release/sbom-attached-not-attested, release/verify-any-identity, release/verify-any-repo | 3 | CD-RI-05a, CD-RI-05b, CD-RI-05c |
| `release-integrity-scan §6` | release/bot-token-no-checks | 2 | CD-RI-06a, CD-RI-06b |
| `release-integrity-scan §7` | release/rollback-target-pruned | 2 | CD-RI-07a, CD-RI-07b |
| `deploy-safety-scan §1` | deploy/auto-rollback-over-contract, deploy/migrate-after-rollout, deploy/migrate-in-init-container, deploy/migrate-on-boot-multi-replica | 5 | CD-DS-01a, CD-DS-01b, CD-DS-01c, CD-DS-01d, CD-DS-01e |
| `deploy-safety-scan §2` | deploy/concurrency-cancels-deploy, deploy/split-concurrency-groups | 3 | CD-DS-02a, CD-DS-02b, CD-DS-02c |
| `deploy-safety-scan §3` | deploy/environment-unprotected | 2 | CD-DS-03a, CD-DS-03b |
| `deploy-safety-scan §4` | deploy/rollout-not-waited | 2 | CD-DS-04a, CD-DS-04b |
| `deploy-safety-scan §5` | deploy/no-shutdown-handler, deploy/shutdown-hooks-inert | 3 | CD-DS-05a, CD-DS-05b, CD-DS-05c |
| `deploy-safety-scan §6` | parity/config-undeclared, parity/runtime-drift | 3 | CD-DS-06a, CD-DS-06b, CD-DS-06c |
| `progressive-delivery §1` | delivery/dead-flag | 1 | CD-PD-01a |
| `progressive-delivery §2` | delivery/stale-flag | 1 | CD-PD-02a |
| `progressive-delivery §5` | delivery/canary-never-fails, delivery/canary-no-analysis, delivery/canary-unscoped | 3 | CD-PD-05a, CD-PD-05b, CD-PD-05c |
| `progressive-delivery §8` | delivery/unsafe-default | 2 | CD-PD-08a, CD-PD-08b |
| `progressive-delivery §9` | delivery/build-time-flag | 2 | CD-PD-09a, CD-PD-09b |
| `gitops-audit §1` | gitops/out-of-band-mutation | 2 | CD-GO-01a, CD-GO-01b |
| `container-build-scan §1` | container/named-user-runasnonroot | 2 | CD-CB-01a, CD-CB-01b |
| `container-build-scan §2` | container/pid1-signal | 3 | CD-CB-02a, CD-CB-02b, CD-CB-02c |
| `container-build-scan §3` | container/layer-order | 2 | CD-CB-03a, CD-CB-03b |
| `container-build-scan §4` | container/lockfile-not-enforced | 3 | CD-CB-04a, CD-CB-04b, CD-CB-04c |
| `container-build-scan §5` | container/arg-scope, container/heredoc-no-errexit, container/run-cd-relative-workdir | 3 | CD-CB-05a, CD-CB-05b, CD-CB-05c |
| `container-build-scan §6` | container/healthcheck-binary-missing, container/healthcheck-wrong-port | 2 | CD-CB-06a, CD-CB-06b |
| `container-build-scan §7` | container/base-eol, container/libc-mismatch, container/platform-constant | 3 | CD-CB-07a, CD-CB-07b, CD-CB-07c |
| `container-build-scan §8` | container/build-tools-shipped, container/builder-residue | 2 | CD-CB-08a, CD-CB-08b |
| `container-build-scan §9` | container/apt-update-alone, container/duplicate-cmd | 2 | CD-CB-09a, CD-CB-09b |
| `container-build-scan §10` | container/base-by-tag-under-claim, container/reproducibility-claimed-not-built | 2 | CD-CB-10a, CD-CB-10b |
| `compose-scan §1` | compose/depends-on-ungated | 2 | CD-CP-01a, CD-CP-01b |
| `compose-scan §2` | compose/healthcheck-never-healthy, compose/healthy-gate-no-healthcheck | 2 | CD-CP-02a, CD-CP-02b |
| `compose-scan §3` | compose/interpolation-no-default | 2 | CD-CP-03a, CD-CP-03b |
| `compose-scan §4` | compose/debug-port, compose/override-loaded-in-prod | 2 | CD-CP-04a, CD-CP-04b |
| `compose-scan §5` | compose/image-latest, compose/image-untagged | 2 | CD-CP-05a, CD-CP-05b |
| `compose-scan §6` | compose/legacy-key, compose/scale-blocker | 2 | CD-CP-06a, CD-CP-06b |
| `compose-scan §7` | compose/oneshot-restart-always, compose/stop-grace-short | 2 | CD-CP-07a, CD-CP-07b |
| `ci-security-scan §1 (security)` | security/privileged-trigger-untrusted-checkout | 2 | CD-HO-SEC-a, CD-HO-SEC-b |
| `ci-security-scan §2 (security)` | security/composite-input-injection, security/expression-injection, security/github-env-injection | 4 | CD-HO-SEC-c, CD-HO-SEC-d, CD-HO-SEC-e, CD-HO-SEC-f |
| `ci-security-scan §3 (security)` | security/ai-agent-untrusted-input | 1 | CD-HO-SEC-g |
| `ci-security-scan §4 (security)` | security/image-no-digest, security/pin-privilege | 2 | CD-HO-SEC-h, CD-HO-SEC-i |
| `ci-security-scan §5 (security)` | security/cache-in-release | 1 | CD-HO-SEC-j |
| `ci-security-scan §9 (security)` | security/expression-injection, security/logging-command-injection | 4 | CD-HO-SEC-k, CD-HO-SEC-l, CD-HO-SEC-m, CD-HO-SEC-n |
| `iac-scan §1 (security)` | security/container-root, security/secret-build-arg | 2 | CD-HO-SEC-o, CD-HO-SEC-p |
| `iac-scan §2 (security)` | security/compose-exposure | 1 | CD-HO-SEC-q |
| `iac-scan §3 grep 4j (security)` | security/deploy-by-mutable-tag | 1 | CD-HO-SEC-r |
| `ci-security-scan §6 (security)` | security/long-lived-publish-token, security/workflow-write-permissions | 2 | CD-HO-SEC-s, CD-HO-SEC-t |
| `suite-execution-scan §4 (testing)` | testing/required-test-job-masked, testing/zero-tests-pass | 2 | CD-HO-TST-a, CD-HO-TST-b |
| `suite-execution-scan §6 (testing)` | testing/retry-no-gate | 1 | CD-HO-TST-c |
| `k8s-availability-scan §7 (infrastructure)` | infrastructure/shutdown-grace | 1 | CD-HO-INF-a |
| `k8s-availability-scan §6 (infrastructure)` | infrastructure/revision-history-zero | 1 | CD-HO-INF-b |
| `k8s-render-scan §4 (infrastructure)` | infrastructure/gitops-replicas-vs-hpa | 1 | CD-HO-INF-c |
| `alert-rule-lint §4 (observability)` | observability/selector-not-in-inventory | 1 | CD-HO-OBS-a |
| `alert-rule-lint §1 (observability)` | observability/page-without-for | 1 | CD-HO-OBS-b |
| **decoys (must not be reported)** | — | **28** | CD-DECOY-01 … CD-DECOY-28 |

---

## CD-PI-01a — `continue-on-error: true` on the required `image-scan` job

```defect
id:       CD-PI-01a
file:     .github/workflows/ci.yml
line:     114
severity: critical
command:  /devops-audit
class:    pipeline/masked-gate
detector: pipeline-integrity-scan §1
anchor:   continue-on-error: true # advisory until
match:    continue-on-error|mask|advisory|green|swallow
```

`image-scan` is a required context in the rules snapshot and an ancestor of `smoke` and `all-green`, yet the job is marked `continue-on-error`: a HIGH/CRITICAL CVE turns the step red and the job, the check and the aggregator stay green. Fix: drop the key; an advisory scan belongs in its own non-required job. Proof: V209 — seed `exit 1` as the scan's first line on a sandbox branch; `image-scan` must conclude `failure`.

## CD-PI-01b — GitLab `security_scan` runs with `allow_failure: true`

```defect
id:       CD-PI-01b
file:     .gitlab-ci.yml
line:     32
severity: high
command:  /devops-audit
class:    pipeline/masked-gate
detector: pipeline-integrity-scan §1
anchor:   allow_failure: true
match:    allow_failure|mask|scan|green
```

The only filesystem scan of billing-go cannot fail the pipeline, and `deploy_billing` (prod) does not wait for it anyway (see CD-PI-04c). Fix: remove `allow_failure` and make the deploy jobs `needs:` the scan. Proof: V209 on a sandbox GitLab project — the pipeline must end `failed`.

## CD-PI-01c — Jenkins `catchError(buildResult: 'SUCCESS')` around the post-deploy smoke test

```defect
id:       CD-PI-01c
file:     Jenkinsfile.groovy
line:     33
severity: high
command:  /devops-audit
class:    pipeline/masked-gate
detector: pipeline-integrity-scan §1
anchor:   catchError(buildResult: 'SUCCESS'
match:    catchError|SUCCESS|smoke|mask
```

A failed smoke of the freshly deployed worker marks only the stage, the build stays SUCCESS and nothing rolls back. Fix: let the smoke fail the build (`buildResult: 'FAILURE'`, or no `catchError`). Proof: V209 — point the smoke at a dead URL; the build must end FAILURE.

## CD-PI-01d — Azure `continueOnError: true` on the admin deploy smoke step

```defect
id:       CD-PI-01d
file:     azure-pipelines.yml
line:     28
severity: high
command:  /devops-audit
class:    pipeline/masked-gate
detector: pipeline-integrity-scan §1
anchor:   continueOnError: true
match:    continueOnError|smoke|mask|green
```

The smoke step is the only check that the new admin image serves its own SHA; with `continueOnError` the run ends `succeededWithIssues` and is treated as a success. Fix: remove it. Proof: V209 with a wrong `--expect-sha`.

## CD-PI-02a — `trivy … | tee trivy.txt` under the default `bash -e` shell

```defect
id:       CD-PI-02a
file:     .github/workflows/ci.yml
line:     120
severity: critical
command:  /devops-audit
class:    pipeline/exit-lost-in-pipe
detector: pipeline-integrity-scan §2
anchor:   | tee trivy.txt
match:    tee|pipe|pipefail|exit
```

GitHub's default `run:` shell has no pipefail (S1), so `tee`'s exit 0 wins and the scan in the required `image-scan` job can never fail, independent of CD-PI-01a. `ci-graph.py --shell-of` prints `pipefail=no source=default`. Fix: `shell: bash` on the step. Proof: V210 four-line probe, then V209.

## CD-PI-02b — Bitbucket `kubectl apply … | tee apply.log` (no pipefail)

```defect
id:       CD-PI-02b
file:     bitbucket-pipelines.yml
line:     21
severity: high
command:  /devops-audit
class:    pipeline/exit-lost-in-pipe
detector: pipeline-integrity-scan §2
anchor:   reports-deployment.yaml | tee apply.log
match:    tee|pipe|pipefail|apply
```

Bitbucket runs `set -e` without pipefail (S5): a rejected manifest leaves the step green and the next line waits on the old Deployment. Fix: `set -o pipefail` as the first script line, or drop the pipe. Proof: V210, then apply an invalid manifest in a sandbox.

## CD-PI-02c — Jenkins `sh 'kubectl apply … | tee apply.log'`

```defect
id:       CD-PI-02c
file:     Jenkinsfile.groovy
line:     26
severity: high
command:  /devops-audit
class:    pipeline/exit-lost-in-pipe
detector: pipeline-integrity-scan §2
anchor:   worker-deployment.yaml | tee apply.log
match:    tee|pipe|pipefail|apply
```

Jenkins `sh` is `sh -xe` with no pipefail (S7): a failed apply is masked by `tee`. Fix: `sh 'set -o pipefail; …'` with a bash shebang, or no pipe. Proof: V210.

## CD-PI-03a — Workflow-level `paths-ignore: ['docs/**']` on the workflow that emits the required checks

```defect
id:       CD-PI-03a
file:     .github/workflows/ci.yml
line:     4
severity: critical
command:  /devops-audit
class:    pipeline/required-check-path-filtered
detector: pipeline-integrity-scan §3
anchor:   paths-ignore: ['docs/**']
match:    paths-ignore|path|pending|docs
```

`test`, `build`, `image-scan` and `all-green` are required (rules snapshot); a docs-only PR never starts this workflow, so the contexts stay Pending forever (R3) and teach admin bypass. Graph row `REQUIRED-PATH-FILTERED`. Fix: filter inside the workflow behind the `always()` aggregator (precedents § 9). Proof: V211 docs-only PR in a sandbox.

## CD-PI-03b — Required `test` job skipped for Dependabot by a job `if:`

```defect
id:       CD-PI-03b
file:     .github/workflows/ci.yml
line:     44
severity: critical
command:  /devops-audit
class:    pipeline/required-check-skipped
detector: pipeline-integrity-scan §3
anchor:   if: github.actor != 'dependabot[bot]'
match:    actor|dependabot|skip|success
```

A skipped job reports success (R1): every Dependabot PR satisfies the required `test` context without running a test. Graph row `REQUIRED-IF-SKIP`. Fix: run the tests for bots too (or skip inside a step that still fails closed). Proof: V211 bot PR.

## CD-PI-03c — No `merge_group:` trigger while the ruleset turns the merge queue on

```defect
id:       CD-PI-03c
file:     .github/workflows/ci.yml
line:     2
severity: high
command:  /devops-audit
class:    pipeline/merge-queue-not-triggered
detector: pipeline-integrity-scan §3
anchor:   on: # CI for every
match:    merge.?group|merge.?queue
```

The rules snapshot carries a `merge_queue` rule; `ci.yml` emits required contexts but has no `merge_group` trigger, so every queue entry waits on checks that never start (R5). Graph row `NO-MERGE-GROUP` (with `--merge-queue`). `ci-web.yml` has the trigger. Proof: V211 merge-queue entry.

## CD-PI-03d — `all-green` treats a cancelled or skipped need as a pass

```defect
id:       CD-PI-03d
file:     .github/workflows/ci.yml
line:     156
severity: high
command:  /devops-audit
class:    pipeline/aggregator-weak
detector: pipeline-integrity-scan §3
anchor:   needs: [lint, test, build, image-scan, smoke]
match:    aggregator|all-green|cancel|failure
```

The aggregator runs under `always()` but only asserts `!= "failure"`: a cancelled `image-scan` or `test` (timeout, superseded run) passes the required `all-green` (precedents § 10). Graph row `AGGREGATOR-WEAK`. Fix: fail unless every result is `success` (or skipped by design). Proof: V211 — cancel a need; `all-green` must fail.

## CD-PI-04a — `deploy-prod` runs under `if: always()`

```defect
id:       CD-PI-04a
file:     .github/workflows/deploy.yml
line:     85
severity: critical
command:  /devops-audit
class:    pipeline/deploy-ungated
detector: pipeline-integrity-scan §4
anchor:   if: always()
match:    always|deploy-prod|fail|gate
```

`always()` overrides the `needs:` result: a failed staging deploy or failed tests still deploy production (R2). Graph row `DEPLOY-ALWAYS`. Fix: drop the status function. Proof: V212 — seed a failing test; `deploy-prod` must be `skipped` and the digest unchanged.

## CD-PI-04b — `npm publish` job with no `needs:` on tests

```defect
id:       CD-PI-04b
file:     .github/workflows/release.yml
line:     12
severity: critical
command:  /devops-audit
class:    pipeline/publish-ungated
detector: pipeline-integrity-scan §4
anchor:   publish-sdk:
match:    publish|needs|test|gate|ungated
```

`publish-sdk` starts on the tag push in parallel with `release-tests`; a red test run still publishes `@acme/shop-sdk` to npm, which cannot be unpublished after 72 h. Graph row `DEPLOY-UNGATED`. Fix: `needs: release-tests`. Proof: V212 against a scratch registry (Verdaccio).

## CD-PI-04c — GitLab prod deploy `deploy_billing` with `needs: []`

```defect
id:       CD-PI-04c
file:     .gitlab-ci.yml
line:     87
severity: critical
command:  /devops-audit
class:    pipeline/deploy-ungated
detector: pipeline-integrity-scan §4
anchor:   needs: []
match:    needs|stage|test|gate|before
```

An empty `needs:` starts the job at pipeline creation, before `test_billing` and the scan: the production deploy is gated on nothing. Fix: `needs: [test_billing, security_scan, build_billing]`. Proof: V212 on a sandbox project.

## CD-PI-04d — Jenkins `post { always { sh './scripts/deploy.sh worker' } }`

```defect
id:       CD-PI-04d
file:     Jenkinsfile.groovy
line:     41
severity: critical
command:  /devops-audit
class:    pipeline/deploy-ungated
detector: pipeline-integrity-scan §4
anchor:   sh './scripts/deploy.sh worker'
match:    post|always|deploy|fail
```

`post { always }` runs after any stage outcome: a failed build or a declined approval still re-applies the worker to production. Fix: move the deploy into a stage behind the approval; keep `post` for notifications. Proof: V212 — fail the Build stage; no apply may run.

## CD-PI-04e — `workflow_run` docs publish with no `conclusion == 'success'` check

```defect
id:       CD-PI-04e
file:     .github/workflows/promote.yml
line:     12
severity: high
command:  /devops-audit
class:    pipeline/workflow-run-no-conclusion
detector: pipeline-integrity-scan §4
anchor:   publish-docs:
match:    workflow_run|conclusion|success|publish
```

`types: [completed]` fires on failed and cancelled Release runs too; the job syncs the docs bucket regardless. Graph row `WORKFLOW_RUN-NO-CONCLUSION`. Fix: `if: github.event.workflow_run.conclusion == 'success'`. Proof: V212 — a failed Release run; the job must be skipped.

## CD-PI-05a — Free-text dispatch `ref` built and deployed to production

```defect
id:       CD-PI-05a
file:     .github/workflows/deploy.yml
line:     91
severity: high
command:  /devops-audit
class:    pipeline/unvalidated-ref
detector: pipeline-integrity-scan §5
anchor:   ref: ${{ inputs.ref || github.sha }}
match:    ref|input|branch|dispatch|unreviewed
```

`workflow_dispatch` takes `ref` as `type: string`; `deploy-prod` checks it out, builds it and applies it, and the production environment has `deployment_branch_policy: null` (environments snapshot). Anyone with write access ships an unreviewed branch. Fix: `type: choice` of release tags, or `git merge-base --is-ancestor` against `origin/main`. Proof: V215 settings read + a refused dispatch from a feature branch.

## CD-PI-05b — GitLab prod deploy with no default-branch rule

```defect
id:       CD-PI-05b
file:     .gitlab-ci.yml
line:     89
severity: high
command:  /devops-audit
class:    pipeline/unvalidated-ref
detector: pipeline-integrity-scan §5
anchor:   if: $CI_PIPELINE_SOURCE == "web"
match:    rule|branch|default|web|ref
```

`deploy_billing` runs for any manually started pipeline on any branch; nothing checks `$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH` and the job names no protected environment. Fix: add the branch rule and `environment: production` with a protected environment. Proof: V215 (`glab api projects/:id/protected_environments`).

## CD-PI-06a — `deploy-prod` has no `timeout-minutes`

```defect
id:       CD-PI-06a
file:     .github/workflows/deploy.yml
line:     83
severity: medium
command:  /devops-audit
class:    pipeline/no-timeout
detector: pipeline-integrity-scan §6
anchor:   deploy-prod:
match:    timeout|360|minutes
```

A hung apply holds the production deploy (and its concurrency group) for the 360-minute default. Graph row `NO-TIMEOUT`. Fix: `timeout-minutes: 20`. Proof: V213 — the row is gone after the fix.

## CD-PI-06b — `kubectl rollout status` with no `--timeout`

```defect
id:       CD-PI-06b
file:     .github/workflows/deploy.yml
line:     79
severity: medium
command:  /devops-audit
class:    pipeline/unbounded-wait
detector: pipeline-integrity-scan §6
anchor:   -n shop-staging rollout status deploy/api
match:    timeout|rollout status|wait
```

The staging wait has no bound (graph row `WAIT-NO-TIMEOUT`); a stuck rollout hangs until the job timeout. Fix: `--timeout=5m`. Proof: V213.

## CD-PI-07a — The matrix excludes Node 22, the runtime `.nvmrc` and `engines` declare

```defect
id:       CD-PI-07a
file:     .github/workflows/ci.yml
line:     68
severity: medium
command:  /devops-audit
class:    pipeline/matrix-excludes-runtime
detector: pipeline-integrity-scan §7
anchor:   - node: 22
match:    matrix|exclude|node|22
```

`compat` tests the SDK on Node 20 only: the runtime the repo declares (22) is never tested there. Graph row `MATRIX-EXCLUDES-RUNTIME`. Fix: drop the exclude (or drop 20). Proof: V214.

## CD-PI-07b — Dynamic matrix from `fromJSON(needs.lint.outputs.pkgs)` with no empty guard

```defect
id:       CD-PI-07b
file:     .github/workflows/ci.yml
line:     81
severity: medium
command:  /devops-audit
class:    pipeline/matrix-dynamic-unguarded
detector: pipeline-integrity-scan §7
anchor:   matrix: ${{ fromJSON(needs.lint.outputs.pkgs) }}
match:    fromJSON|empty|matrix|skip
```

An empty affected list yields an empty matrix, the job is skipped and a skip is success (R1). Graph row `MATRIX-DYNAMIC-UNGUARDED`. Fix: `if: needs.lint.outputs.pkgs != '[]'` plus an explicit no-op leg. Proof: V214.

## CD-PI-08a — Nightly backup verification gated on the repository's old name

```defect
id:       CD-PI-08a
file:     .github/workflows/nightly.yml
line:     13
severity: high
command:  /devops-audit
class:    pipeline/schedule-dead
detector: pipeline-integrity-scan §8
anchor:   if: github.repository == 'acme/old-name'
match:    repository|old-name|never|backup
```

After the rename to `acme/shop` the `if:` is always false: the only backup-restore check has not run since, and the run shows `skipped`, not red. Fix: drop the guard or use `github.repository_owner`. Proof: V216 — `gh run list -w nightly.yml` shows the job skipped.

## CD-PI-08b — `cron: '0 0 31 2 *'` never fires

```defect
id:       CD-PI-08b
file:     .github/workflows/nightly.yml
line:     5
severity: low
command:  /devops-audit
class:    pipeline/schedule-dead
detector: pipeline-integrity-scan §8
anchor:   cron: '0 0 31 2 *'
match:    cron|31|february|never
```

There is no 31 February; the schedule is dead. Fix: the intended cadence. Proof: V216.

## CD-PC-01a — `node_modules` cached under `${{ runner.os }}-node` (no lockfile hash)

```defect
id:       CD-PC-01a
file:     .github/workflows/ci-web.yml
line:     66
severity: medium
command:  /devops-audit
class:    cache/key-no-lockfile
detector: pipeline-cache-scan §1
anchor:   key: ${{ runner.os }}-node
match:    key|hash|lock|node_modules|stale
```

Cache keys are immutable: the first `node_modules` is restored forever, and the install runs only when `cache-hit != 'true'`, so a lockfile change never reaches `web-unit`. Graph rows `CACHE-KEY-NO-HASH`, `CACHE-NODE-MODULES`. Fix: cache the pnpm store via `setup-node cache: pnpm` and always install. Proof: V217.

## CD-PC-01b — CircleCI `restore_cache: keys: [deps-v1]` for an installed venv

```defect
id:       CD-PC-01b
file:     .circleci/config.yml
line:     31
severity: medium
command:  /devops-audit
class:    cache/key-no-lockfile
detector: pipeline-cache-scan §1
anchor:   keys: [deps-v1]
match:    key|checksum|lock|venv|stale
```

The key never changes and CircleCI keeps the first save; the venv restored is the one built from the first `requirements.txt`. Fix: `deps-v2-{{ arch }}-{{ checksum "services/reports-py/requirements.txt" }}`. Proof: V217.

## CD-PC-01c — Prefix restore of `node_modules`, install guarded on `cache-hit == 'false'`

```defect
id:       CD-PC-01c
file:     .github/workflows/_build.yml
line:     34
severity: high
command:  /devops-audit
class:    cache/prefix-restore-skips-install
detector: pipeline-cache-scan §1
anchor:   if: steps.deps.outputs.cache-hit == 'false'
match:    cache-hit|restore-keys|prefix|install|skip
```

A `restore-keys` hit restores an old tree and `cache-hit` is not `'false'`, so the install is skipped and the CI images are built from dependencies the lockfile no longer names. Graph rows `CACHE-PREFIX-SKIP-INSTALL`, `CACHE-NODE-MODULES`. Fix: `!= 'true'`, or no prefix restore for an installed tree. Proof: V217.

## CD-PC-02a — BuildKit `cache-to: type=gha` without `mode=max`

```defect
id:       CD-PC-02a
file:     .github/workflows/_build.yml
line:     50
severity: low
command:  /devops-audit
class:    cache/buildx-mode-min
detector: pipeline-cache-scan §2
anchor:   cache-to: type=gha,ignore-error=true
match:    mode|min|max|cache-to
```

`mode=min` exports only the final stage: the api's deps and build stages rebuild on every run. Fix: `mode=max`. Proof: V217 timing (A).

## CD-PC-02b — Two image builds share the default `type=gha` scope

```defect
id:       CD-PC-02b
file:     .github/workflows/_build.yml
line:     57
severity: low
command:  /devops-audit
class:    cache/buildx-shared-scope
detector: pipeline-cache-scan §2
anchor:   cache-from: type=gha,timeout=10m
match:    scope|shared|overwrite|gha
```

api and worker both read and write scope `buildkit`, so each build overwrites the other's cache. Fix: `scope=api` / `scope=worker`. Proof: V217.

## CD-PC-03a — `nx affected` on the default shallow checkout

```defect
id:       CD-PC-03a
file:     .github/workflows/ci.yml
line:     38
severity: medium
command:  /devops-audit
class:    cache/affected-shallow-clone
detector: pipeline-cache-scan §3
anchor:   run: npx nx affected -t lint --base=origin/main --head=HEAD
match:    affected|fetch-depth|shallow|history
```

`actions/checkout` fetches one commit and no `origin/main`; `nx affected` then errors or falls back, and `pkgs` feeds the matrix of CD-PI-07b. Fix: `fetch-depth: 0` plus `nrwl/nx-set-shas`. Proof: V218.

## CD-PC-03b — PR workflow with no `concurrency`

```defect
id:       CD-PC-03b
file:     .github/workflows/ci-web.yml
line:     3
severity: medium
command:  /devops-audit
class:    cache/pr-workflow-no-concurrency
detector: pipeline-cache-scan §3
anchor:   pull_request:
match:    concurrency|superseded|cancel
```

Every push to a PR starts another full Web CI run while the superseded one keeps the runners busy. Fix: `concurrency: { group: web-ci-${{ github.event.pull_request.number || github.ref }}, cancel-in-progress: true }`. Proof: V218 (A, run list).

## CD-PC-04a — Serial `web-lint → web-typecheck → web-unit` chain with no data hand-off

```defect
id:       CD-PC-04a
file:     .github/workflows/ci-web.yml
line:     43
severity: low
command:  /devops-audit
class:    cache/serial-chain
detector: pipeline-cache-scan §4
anchor:   needs: web-lint
match:    serial|chain|needs|parallel
```

Three independent checks run one after another, each re-installing; the PR waits for the sum. Fix: run them in parallel behind `changes`. Proof: run timing p50 (A).

## CD-PC-04b — GitLab lint → typecheck → test stages serialise independent jobs

```defect
id:       CD-PC-04b
file:     .gitlab-ci.yml
line:     3
severity: low
command:  /devops-audit
class:    cache/serial-stages
detector: pipeline-cache-scan §4
anchor:   stages: [lint, typecheck, test, build, release, deploy]
match:    stage|serial|needs|parallel
```

No job uses `needs:` and none passes artifacts, yet each stage waits for the previous one. Fix: `needs:` per job (a DAG). Proof: pipeline duration (A).

## CD-RI-01a — Tag-push release with no ancestry check and no tag ruleset

```defect
id:       CD-RI-01a
file:     .github/workflows/release.yml
line:     4
severity: high
command:  /devops-audit
class:    release/ref-movable
detector: release-integrity-scan §1
anchor:   tags: ['v*']
match:    tag|ruleset|ancestor|branch|any commit
```

Anyone with write access pushes `v9.9.9` from any commit and publishes the SDK and images; `rulesets.json` holds only a branch ruleset. Fix: a tag ruleset limited to the release bot, plus `git merge-base --is-ancestor "$GITHUB_SHA" origin/main`. Proof: V220.

## CD-RI-01b — GitLab release on `$CI_COMMIT_TAG` with no protected-tag check

```defect
id:       CD-RI-01b
file:     .gitlab-ci.yml
line:     56
severity: high
command:  /devops-audit
class:    release/ref-movable
detector: release-integrity-scan §1
anchor:   - if: $CI_COMMIT_TAG
match:    tag|protected|CI_COMMIT_TAG|any
```

Any developer tag re-tags and pushes the billing image; nothing reads `$CI_COMMIT_REF_PROTECTED`. Fix: `rules: - if: $CI_COMMIT_TAG && $CI_COMMIT_REF_PROTECTED == "true"` plus protected tags. Proof: V220.

## CD-RI-02a — `apps/api/package.json` 2.3.0 vs release-please manifest 2.3.1 (linked versions)

```defect
id:       CD-RI-02a
file:     apps/api/package.json
line:     3
severity: medium
command:  /devops-audit
class:    release/version-split
detector: release-integrity-scan §2
anchor:   "version": "2.3.0"
match:    version|2\.3\.0|2\.3\.1|manifest
```

The config links api, worker and web; the manifest says 2.3.1 and the api manifest still says 2.3.0, so the api reports the wrong version. Fix: let release-please write the file. Proof: V221 dry run prints one version.

## CD-RI-02b — Changesets pre-release mode left on

```defect
id:       CD-RI-02b
file:     .changeset/pre.json
line:     2
severity: medium
command:  /devops-audit
class:    release/prerelease-left-on
detector: release-integrity-scan §2
anchor:   "mode": "pre"
match:    pre|beta|mode
```

Every SDK version is published as `-beta.N` under the `beta` tag. Fix: `changeset pre exit`. Proof: V221 (`changeset status --verbose`).

## CD-RI-03a — `npm publish` with no existence guard

```defect
id:       CD-RI-03a
file:     .github/workflows/release.yml
line:     29
severity: medium
command:  /devops-audit
class:    release/non-idempotent
detector: release-integrity-scan §3
anchor:   run: npm publish --access public
match:    publish|idempot|re-?run|exist|guard
```

A re-run after a half-failure fails E403 after the images already went. Fix: `npm view "$PKG@$V" version || npm publish`. Proof: V222.

## CD-RI-03b — `docker push …:${VERSION}` overwrites a released tag on re-run

```defect
id:       CD-RI-03b
file:     .github/workflows/release.yml
line:     73
severity: high
command:  /devops-audit
class:    release/non-idempotent
detector: release-integrity-scan §3
anchor:   docker push ghcr.io/acme/shop-worker:${VERSION}
match:    push|tag|overwrite|re-?run|digest|guard
```

A re-run rebuilds the worker and pushes a new digest under the released version. Fix: `docker buildx imagetools inspect` guard, or push by digest. Proof: V222.

## CD-RI-03c — `twine upload` without `--skip-existing`

```defect
id:       CD-RI-03c
file:     .circleci/config.yml
line:     57
severity: medium
command:  /devops-audit
class:    release/non-idempotent
detector: release-integrity-scan §3
anchor:   twine upload dist/*
match:    twine|skip-existing|re-?run|exist
```

Every push to main uploads the reports client; an unchanged version fails the job, a half-run leaves the wheel without the sdist. Fix: `--skip-existing`, publish on tags only. Proof: V222 against TestPyPI.

## CD-RI-04a — `deploy-prod` rebuilds the api image with `APP_ENV=production`

```defect
id:       CD-RI-04a
file:     .github/workflows/deploy.yml
line:     100
severity: critical
command:  /devops-audit
class:    release/shipped-not-tested
detector: release-integrity-scan §4
anchor:   docker build -t ghcr.io/acme/shop-api:main --build-arg APP_ENV=production apps/api
match:    rebuild|build|deploy|tested|digest
```

Production runs an image built inside the deploy job, never tested, scanned or signed; the staging deploy used the signed digest from `build-image`. 0c flags `BUILD-IN-DEPLOY` and `NO-DIGEST-HANDOFF`. Fix: promote `needs.build-image.outputs.digest`. Proof: V223 digest continuity.

## CD-RI-04b — Scan a `load: true` build, then push a second build

```defect
id:       CD-RI-04b
file:     .github/workflows/release.yml
line:     68
severity: high
command:  /devops-audit
class:    release/rebuild-after-scan
detector: release-integrity-scan §4
anchor:   push: true
match:    rebuild|scan|load|push|digest
```

The scanned image (`shop-api:scan`) is not the pushed one; 0c flags `REBUILD-AFTER-SCAN`. Fix: build once with `push: true`, scan the digest. Proof: V223.

## CD-RI-04c — GitLab scans the release by tag, after pushing it

```defect
id:       CD-RI-04c
file:     .gitlab-ci.yml
line:     61
severity: high
command:  /devops-audit
class:    release/scan-by-tag
detector: release-integrity-scan §4
anchor:   trivy image --exit-code 1 --severity HIGH,CRITICAL "$BILLING_IMAGE:$CI_COMMIT_TAG"
match:    tag|scan|after|push|digest
```

The tag is already public when it is scanned. Fix: scan the digest before the push. Proof: V223.

## CD-RI-05a — `cosign verify --certificate-identity-regexp '.*'` by tag

```defect
id:       CD-RI-05a
file:     scripts/verify-release.sh
line:     5
severity: high
command:  /devops-audit
class:    release/verify-any-identity
detector: release-integrity-scan §5
anchor:   --certificate-identity-regexp '.*'
match:    identity|regexp|any|workflow|verify
```

Any workflow in any repository signing with GitHub's issuer passes, and the tag can move. Fix: exact identity + digest (as `scripts/promote.sh`). Proof: V224.

## CD-RI-05b — `gh attestation verify … --owner acme` only

```defect
id:       CD-RI-05b
file:     scripts/verify-release.sh
line:     6
severity: high
command:  /devops-audit
class:    release/verify-any-repo
detector: release-integrity-scan §5
anchor:   --owner acme
match:    owner|repo|signer|attestation
```

Any repository in the org satisfies it. Fix: `--repo acme/shop --signer-workflow … --source-ref refs/heads/main`. Proof: V224.

## CD-RI-05c — `cosign attach sbom` (unsigned, removed in cosign v4)

```defect
id:       CD-RI-05c
file:     .github/workflows/release.yml
line:     77
severity: medium
command:  /devops-audit
class:    release/sbom-attached-not-attested
detector: release-integrity-scan §5
anchor:   cosign attach sbom
match:    attach|sbom|attest|unsigned
```

Fix: `cosign attest --type cyclonedx` or `actions/attest-sbom`. Proof: V224.

## CD-RI-06a — release-please opens its PR with `GITHUB_TOKEN`

```defect
id:       CD-RI-06a
file:     .github/workflows/release-pr.yml
line:     17
severity: medium
command:  /devops-audit
class:    release/bot-token-no-checks
detector: release-integrity-scan §6
anchor:   token: ${{ secrets.GITHUB_TOKEN }}
match:    GITHUB_TOKEN|check|release.?please|token
```

A PR opened by `GITHUB_TOKEN` triggers no workflows, so required checks never run on it. Fix: a GitHub App token. Proof: V225.

## CD-RI-06b — changesets/action with the default token

```defect
id:       CD-RI-06b
file:     .github/workflows/release-pr.yml
line:     29
severity: medium
command:  /devops-audit
class:    release/bot-token-no-checks
detector: release-integrity-scan §6
anchor:   uses: changesets/action@
match:    changesets|token|check|GITHUB_TOKEN
```

Same trap as CD-RI-06a. Fix: an App token. Proof: V225.

## CD-RI-07a — GHCR cleanup keeps one version

```defect
id:       CD-RI-07a
file:     .github/workflows/ghcr-cleanup.yml
line:     24
severity: high
command:  /devops-audit
class:    release/rollback-target-pruned
detector: release-integrity-scan §7
anchor:   min-versions-to-keep: 1
match:    keep|retention|rollback|N-1|prune
```

The weekly prune deletes the previous release; hotfix.yml's `v2.3.0` choice then cannot pull. Fix: keep ≥ 10. Proof: V226.

## CD-RI-07b — ECR lifecycle `countNumber: 1`, `tagStatus: any`

```defect
id:       CD-RI-07b
file:     deploy/ecr-lifecycle.json
line:     9
severity: high
command:  /devops-audit
class:    release/rollback-target-pruned
detector: release-integrity-scan §7
anchor:   "countNumber": 1
match:    count|lifecycle|retention|rollback|expire
```

Fix: keep ≥ 10 tagged images. Proof: V226.

## CD-DS-01a — MikroORM `getMigrator().up()` at boot × prod replicas 3

```defect
id:       CD-DS-01a
file:     apps/api/src/main.ts
line:     10
severity: high
command:  /devops-audit
class:    deploy/migrate-on-boot-multi-replica
detector: deploy-safety-scan §1
anchor:   await app.get(MikroORM).getMigrator().up();
match:    migrat|boot|replica|concurrent|lock
```

The prod render runs 3 api replicas (and the Rollout keeps 3); MikroORM 6 takes no cross-process lock (V227, measured 6.6.16: a data migration applied 3×). Fix: one migration Job applied and waited on before the rollout. Proof: V227.

## CD-DS-01b — Worker entrypoint runs `mikro-orm migration:up` on every start (2 replicas)

```defect
id:       CD-DS-01b
file:     apps/worker/entrypoint.sh
line:     4
severity: high
command:  /devops-audit
class:    deploy/migrate-on-boot-multi-replica
detector: deploy-safety-scan §1
anchor:   npx mikro-orm migration:up
match:    migrat|entrypoint|replica|concurrent|lock
```

Every worker pod start and restart races the api boot migration on the same database. Fix: remove it; migrations run once from the Job. Proof: V227.

## CD-DS-01c — reports initContainer `alembic upgrade head` on a 2-replica Deployment

```defect
id:       CD-DS-01c
file:     deploy/k8s/base/reports-deployment.yaml
line:     18
severity: high
command:  /devops-audit
class:    deploy/migrate-in-init-container
detector: deploy-safety-scan §1
anchor:   command: ["sh", "-c", "uv run alembic upgrade head"]
match:    initContainer|alembic|replica|every pod|migrat
```

Runs once per pod, per restart and per scale-up, concurrently. Fix: a Job before the rollout. Proof: V227.

## CD-DS-01d — GitLab `deploy_billing` migrates after the Helm rollout

```defect
id:       CD-DS-01d
file:     .gitlab-ci.yml
line:     92
severity: high
command:  /devops-audit
class:    deploy/migrate-after-rollout
detector: deploy-safety-scan §1
anchor:   - goose up
match:    after|goose|migrat|order|old schema
```

UNIT row `migrate=AFTER-DEPLOY`: new pods meet the old schema. Fix: the staging Job pattern (`deploy/k8s/billing-migrate`) before the upgrade. Proof: V227.

## CD-DS-01e — Auto-rollback in the reports deploy while the release drops a column

```defect
id:       CD-DS-01e
file:     bitbucket-pipelines.yml
line:     22
severity: high
command:  /devops-audit
class:    deploy/auto-rollback-over-contract
detector: deploy-safety-scan §1
anchor:   rollout undo deploy/reports
match:    undo|rollback|drop|column|contract
```

`20261001_drop_legacy_format.py` runs `DROP COLUMN legacy_format`; an automatic `rollout undo` lands the old code, which reads it, on the new schema. Fix: expand/contract across two releases. Proof: V227 (database `migration-safety` decides the statement).

## CD-DS-02a — Workflow-level `cancel-in-progress: true` over the deploy jobs

```defect
id:       CD-DS-02a
file:     .github/workflows/deploy.yml
line:     14
severity: high
command:  /devops-audit
class:    deploy/concurrency-cancels-deploy
detector: deploy-safety-scan §2
anchor:   cancel-in-progress: true
match:    cancel|concurrency|half|apply
```

A newer push cancels a running `kubectl apply` or image push mid-flight. Graph row `DEPLOY-CANCEL scope=workflow`. Fix: job-level `concurrency: { group: deploy-production, cancel-in-progress: false }`. Proof: V228.

## CD-DS-02b — GitLab `deploy_billing_staging` is `interruptible: true` with no `resource_group`

```defect
id:       CD-DS-02b
file:     .gitlab-ci.yml
line:     77
severity: high
command:  /devops-audit
class:    deploy/concurrency-cancels-deploy
detector: deploy-safety-scan §2
anchor:   interruptible: true
match:    interruptible|cancel|helm|pending
```

A newer pipeline cancels a running `helm upgrade`, leaving `pending-upgrade`. Fix: `interruptible: false`, `resource_group: staging`. Proof: V228.

## CD-DS-02c — Production deployed under two groups (`deploy-<ref>` and `hotfix-<sha>`)

```defect
id:       CD-DS-02c
file:     .github/workflows/hotfix.yml
line:     29
severity: high
command:  /devops-audit
class:    deploy/split-concurrency-groups
detector: deploy-safety-scan §2
anchor:   group: hotfix-${{ github.sha }}
match:    group|concurrency|production|split|both
```

Graph rows `ENV-SPLIT-GROUPS env=production` and `GROUP-NOT-ENV`: a hotfix and a main deploy run at once. Fix: one `deploy-production` group in both. Proof: V228.

## CD-DS-03a — GitLab prod deploy with no `environment:`

```defect
id:       CD-DS-03a
file:     .gitlab-ci.yml
line:     84
severity: critical
command:  /devops-audit
class:    deploy/environment-unprotected
detector: deploy-safety-scan §3
anchor:   deploy_billing:
match:    environment|protect|approv|review
```

No protected environment, no approval, no deployment record. Fix: `environment: production` protected. Proof: V229.

## CD-DS-03b — Production environment with `deployment_branch_policy: null` (and admin bypass)

```defect
id:       CD-DS-03b
file:     .refract-fixture/gh-api/environments.json
line:     36
severity: critical
command:  /devops-audit
class:    deploy/environment-unprotected
detector: deploy-safety-scan §3
anchor:   "deployment_branch_policy": null
match:    branch|policy|production|any branch
```

Any branch may deploy to production (see CD-PI-05a). Fix: protected branches or tag rule. Proof: V229 settings read.

## CD-DS-04a — `kubectl apply -k …/overlays/prod` with no rollout wait and no smoke

```defect
id:       CD-DS-04a
file:     .github/workflows/deploy.yml
line:     107
severity: high
command:  /devops-audit
class:    deploy/rollout-not-waited
detector: deploy-safety-scan §4
anchor:   apply -k deploy/k8s/overlays/prod
match:    rollout status|wait|smoke|crash
```

A crash-looping image leaves the job green. Fix: `rollout status --timeout` + a version smoke. Proof: V230 kind cluster.

## CD-DS-04b — GitLab staging `helm upgrade --install` with no `--wait`

```defect
id:       CD-DS-04b
file:     .gitlab-ci.yml
line:     82
severity: high
command:  /devops-audit
class:    deploy/rollout-not-waited
detector: deploy-safety-scan §4
anchor:   helm upgrade --install billing deploy/charts/billing -n shop-staging
match:    wait|helm|timeout
```

Fix: `--wait --timeout 10m`. Proof: V230.

## CD-DS-05a — NestJS hooks never run: no `enableShutdownHooks()`

```defect
id:       CD-DS-05a
file:     apps/api/src/main.ts
line:     12
severity: high
command:  /devops-audit
class:    deploy/shutdown-hooks-inert
detector: deploy-safety-scan §5
anchor:   await app.listen(3000, '0.0.0.0');
match:    enableShutdownHooks|SIGTERM|onModuleDestroy|shutdown
```

`QueueModule.onModuleDestroy` closes the BullMQ queue, but without `app.enableShutdownHooks()` Nest never calls it on SIGTERM (5b `NEST-HOOKS-INERT`); behind `CMD npm start` the signal does not even reach node (CD-CB-02a). Fix: `app.enableShutdownHooks()`. Proof: V231.

## CD-DS-05b — BullMQ worker with no SIGTERM path to `worker.close()`

```defect
id:       CD-DS-05b
file:     apps/worker/src/main.ts
line:     10
severity: high
command:  /devops-audit
class:    deploy/no-shutdown-handler
detector: deploy-safety-scan §5
anchor:   const invoices = new Worker('invoices', renderInvoice, { connection, concurrency });
match:    SIGTERM|close|shutdown|in-flight|worker
```

Active jobs are killed mid-render and redelivered after the stall timeout. Fix: `process.on('SIGTERM', () => Promise.all([invoices.close(), emails.close()]))`. Proof: V231.

## CD-DS-05c — Go service with no `signal.NotifyContext` / `Server.Shutdown`

```defect
id:       CD-DS-05c
file:     services/billing-go/cmd/billing/main.go
line:     19
severity: high
command:  /devops-audit
class:    deploy/no-shutdown-handler
detector: deploy-safety-scan §5
anchor:   log.Fatal(http.ListenAndServe(":8080", mux))
match:    signal|Shutdown|SIGTERM|graceful
```

In-flight invoice requests are cut on every rollout. Fix: `http.Server` + `Shutdown(ctx)` on SIGTERM. Proof: V231.

## CD-DS-06a — `STRIPE_WEBHOOK_SECRET` read per request, declared nowhere

```defect
id:       CD-DS-06a
file:     apps/api/src/payments/stripe-webhook.controller.ts
line:     12
severity: high
command:  /devops-audit
class:    parity/config-undeclared
detector: deploy-safety-scan §6
anchor:   const secret = process.env.STRIPE_WEBHOOK_SECRET;
match:    STRIPE_WEBHOOK_SECRET|declar|env|example|schema
```

Absent from `.env.example`, the Joi schema, compose and every render: the first webhook in a new environment fails. Fix: declare it in the schema (required) and the overlay. Proof: V234.

## CD-DS-06b — `os.environ["REPORTS_BUCKET"]` read per request, declared nowhere

```defect
id:       CD-DS-06b
file:     services/reports-py/app/exports.py
line:     12
severity: medium
command:  /devops-audit
class:    parity/config-undeclared
detector: deploy-safety-scan §6
anchor:   bucket = os.environ["REPORTS_BUCKET"]
match:    REPORTS_BUCKET|declar|env|KeyError
```

KeyError → 500 on the first export. Fix: declare it and read at boot. Proof: V234.

## CD-DS-06c — Worker image on Node 20 while `.nvmrc` and `engines` say 22

```defect
id:       CD-DS-06c
file:     apps/worker/Dockerfile
line:     2
severity: medium
command:  /devops-audit
class:    parity/runtime-drift
detector: deploy-safety-scan §6
anchor:   FROM node:20-bookworm-slim AS base
match:    node.?20|nvmrc|22|runtime|engines
```

CI tests on 22; the worker runs 20. Fix: `node:22-bookworm-slim`. Proof: V234.

## CD-PD-01a — Flag `dead-banner` declared, read nowhere

```defect
id:       CD-PD-01a
file:     flags/flags.yaml
line:     18
severity: low
command:  /devops-audit
class:    delivery/dead-flag
detector: progressive-delivery §1
anchor:   dead-banner:
match:    dead|unused|never read|no reader|banner
```

No literal, constant or SDK call. Fix: delete the key. Proof: S.

## CD-PD-02a — Release flag hard-coded `true`

```defect
id:       CD-PD-02a
file:     apps/api/src/invoices/invoice.flags.ts
line:     2
severity: low
command:  /devops-audit
class:    delivery/stale-flag
detector: progressive-delivery §2
anchor:   export const ENABLE_NEW_INVOICE_PDF = true;
match:    hard.?coded|stale|constant|flag|remove
```

The rollout finished in 2.1.0; the flag and the v1 branch are dead. Fix: delete both. Proof: S.

## CD-PD-05a — Canary error-ratio gate `result[0] >= 0` can never fail

```defect
id:       CD-PD-05a
file:     deploy/rollouts/analysis-template.yaml
line:     14
severity: high
command:  /devops-audit
class:    delivery/canary-never-fails
detector: progressive-delivery §5
anchor:   successCondition: result[0] >= 0
match:    never fail|>= ?0|always pass|condition
```

A ratio is never negative: the step-1 gate passes every canary (`NEVER-FAILS`). Fix: `result[0] <= 0.01`. Proof: V232.

## CD-PD-05b — Canary latency query has no canary selector

```defect
id:       CD-PD-05b
file:     deploy/rollouts/analysis-template.yaml
line:     29
severity: high
command:  /devops-audit
class:    delivery/canary-unscoped
detector: progressive-delivery §5
anchor:   - name: p99-latency
match:    canary|selector|scope|pod_template_hash|dilut|stable
```

The step-2 gate measures the whole service; at 50 % weight stable pods dilute the canary (`UNSCOPED`). Fix: `rollouts_pod_template_hash="{{args.canary-hash}}"`. Proof: V232.

## CD-PD-05c — reports Rollout: canary steps with no analysis

```defect
id:       CD-PD-05c
file:     deploy/rollouts/reports-rollout.yaml
line:     2
severity: high
command:  /devops-audit
class:    delivery/canary-no-analysis
detector: progressive-delivery §5
anchor:   kind: Rollout
match:    analysis|gate|no analysis|pause
```

`NO-ANALYSIS`: the canary is promoted on a timer. Fix: an AnalysisTemplate step. Proof: V232.

## CD-PD-08a — `getBooleanValue('new-checkout', true)`: the new checkout is the outage default

```defect
id:       CD-PD-08a
file:     apps/web/src/flags.ts
line:     7
severity: medium
command:  /devops-audit
class:    delivery/unsafe-default
detector: progressive-delivery §8
anchor:   return client.getBooleanValue('new-checkout', true);
match:    default|true|outage|provider|new-checkout
```

Production has the flag off; a flag-service outage turns it on for everyone. Fix: default `false`. Proof: V233.

## CD-PD-08b — Unleash `isEnabled('bulk-refund', ctx, () => true)` on a money path

```defect
id:       CD-PD-08b
file:     apps/api/src/refunds/refund.service.ts
line:     15
severity: high
command:  /devops-audit
class:    delivery/unsafe-default
detector: progressive-delivery §8
anchor:   this.unleash.isEnabled('bulk-refund', ctx, () => true)
match:    fallback|default|true|refund|outage
```

Unleash down → bulk refunds enabled. Fix: fallback `() => false`. Proof: V233.

## CD-PD-09a — `import.meta.env.VITE_FLAG_NEW_SEARCH` used as the search switch

```defect
id:       CD-PD-09a
file:     apps/web/src/search/SearchPage.tsx
line:     5
severity: medium
command:  /devops-audit
class:    delivery/build-time-flag
detector: progressive-delivery §9
anchor:   const newSearch = import.meta.env.VITE_FLAG_NEW_SEARCH === 'true';
match:    build.?time|VITE|inline|runtime|bundle
```

Vite inlines it at build: flipping it needs a rebuild. Fix: evaluate `new-search` through the flag SDK. Proof: V233.

## CD-PD-09b — Registry promises a runtime flip for `new-search`

```defect
id:       CD-PD-09b
file:     flags/flags.yaml
line:     25
severity: medium
command:  /devops-audit
class:    delivery/build-time-flag
detector: progressive-delivery §9
anchor:   description: Flip at runtime from the flag service
match:    runtime|flip|build|VITE|registry
```

The runbook path (flip in the flag service) does nothing. Proof: V233.

## CD-GO-01a — `kubectl scale` into the Argo-managed `shop-web` namespace

```defect
id:       CD-GO-01a
file:     scripts/hotfix.sh
line:     6
severity: high
command:  /devops-audit
class:    gitops/out-of-band-mutation
detector: gitops-audit §1
anchor:   kubectl scale deploy/web -n shop-web --replicas=6
match:    argo|self.?heal|out.?of.?band|git|managed|revert
```

`web-prod` syncs `shop-web` with `selfHeal: true`: the scale-up is reverted within the reconcile interval mid-incident. Fix: change replicas/HPA in git. Proof: S + L.

## CD-GO-01b — CI `kubectl set image` into the Argo-managed namespace

```defect
id:       CD-GO-01b
file:     .github/workflows/deploy.yml
line:     122
severity: high
command:  /devops-audit
class:    gitops/out-of-band-mutation
detector: gitops-audit §1
anchor:   -n shop-web set image deployment/web
match:    argo|self.?heal|out.?of.?band|git|managed|revert
```

Argo reverts the image to the git spec; the deploy job reports success for a change that does not stick. Fix: commit the image bump. Proof: S + L.

## CD-CB-01a — Named `USER nginx` × `runAsNonRoot: true` with no `runAsUser`

```defect
id:       CD-CB-01a
file:     apps/web/Dockerfile.web
line:     28
severity: medium
command:  /devops-audit
class:    container/named-user-runasnonroot
detector: container-build-scan §1
anchor:   USER nginx
match:    runAsNonRoot|numeric|named|uid|nginx
```

The kubelet cannot verify a name: `CreateContainerConfigError`. Fix: `USER 101`. Proof: V235.

## CD-CB-01b — Named `USER node` × `runAsNonRoot: true` with no `runAsUser`

```defect
id:       CD-CB-01b
file:     apps/api/Dockerfile
line:     23
severity: medium
command:  /devops-audit
class:    container/named-user-runasnonroot
detector: container-build-scan §1
anchor:   USER node
match:    runAsNonRoot|numeric|named|uid|node
```

Fix: `USER 1000`. Proof: V235.

## CD-CB-02a — Shell-form `CMD npm start` on bookworm-slim

```defect
id:       CD-CB-02a
file:     apps/api/Dockerfile
line:     26
severity: high
command:  /devops-audit
class:    container/pid1-signal
detector: container-build-scan §2
anchor:   CMD npm start
match:    PID ?1|shell|SIGTERM|npm|signal
```

`sh` then npm are PID 1; SIGTERM never reaches node (137 after 10 s). Fix: `CMD ["node", "dist/main.js"]` + `tini`. Proof: V231.

## CD-CB-02b — Entrypoint script starts the worker without `exec`

```defect
id:       CD-CB-02b
file:     apps/worker/Dockerfile
line:     21
severity: high
command:  /devops-audit
class:    container/pid1-signal
detector: container-build-scan §2
anchor:   ENTRYPOINT ["./entrypoint.sh"]
match:    exec|entrypoint|PID ?1|SIGTERM|signal
```

2b `NO-EXEC`: sh stays PID 1. Fix: `exec node dist/main.js "$@"`. Proof: V231.

## CD-CB-02c — Shell-form `CMD gunicorn …` on python:3.12-slim (dash)

```defect
id:       CD-CB-02c
file:     services/reports-py/Dockerfile
line:     16
severity: medium
command:  /devops-audit
class:    container/pid1-signal
detector: container-build-scan §2
anchor:   CMD gunicorn app.main:app
match:    shell|PID ?1|SIGTERM|gunicorn|exec form
```

Gunicorn never gets SIGTERM, so `--graceful-timeout` never applies. Fix: exec form. Proof: V231.

## CD-CB-03a — `COPY . .` before `pnpm install` in the build stage

```defect
id:       CD-CB-03a
file:     apps/api/Dockerfile
line:     13
severity: medium
command:  /devops-audit
class:    container/layer-order
detector: container-build-scan §3
anchor:   COPY . .
match:    COPY|layer|cache|order|install
```

Every source edit reinstalls. Fix: manifests first. Proof: V236.

## CD-CB-03b — `COPY . .` before `uv sync`

```defect
id:       CD-CB-03b
file:     services/reports-py/Dockerfile
line:     8
severity: medium
command:  /devops-audit
class:    container/layer-order
detector: container-build-scan §3
anchor:   COPY . .
match:    COPY|layer|cache|order|uv sync
```

Fix: `COPY pyproject.toml uv.lock ./` first. Proof: V236.

## CD-CB-04a — `pnpm install` without `--frozen-lockfile` in the build

```defect
id:       CD-CB-04a
file:     apps/api/Dockerfile
line:     14
severity: high
command:  /devops-audit
class:    container/lockfile-not-enforced
detector: container-build-scan §4
anchor:   pnpm install --prefer-offline
match:    frozen|lockfile|pnpm install
```

A drifted lockfile is rewritten inside the image. Fix: `--frozen-lockfile`. Proof: V236.

## CD-CB-04b — `uv sync` without `--locked`

```defect
id:       CD-CB-04b
file:     services/reports-py/Dockerfile
line:     9
severity: medium
command:  /devops-audit
class:    container/lockfile-not-enforced
detector: container-build-scan §4
anchor:   RUN uv sync --no-dev
match:    locked|frozen|lockfile|uv sync
```

Fix: `uv sync --locked --no-dev`. Proof: V236.

## CD-CB-04c — `npm install` in the worker image

```defect
id:       CD-CB-04c
file:     apps/worker/Dockerfile
line:     9
severity: high
command:  /devops-audit
class:    container/lockfile-not-enforced
detector: container-build-scan §4
anchor:   RUN npm install
match:    npm install|npm ci|lockfile
```

Fix: `npm ci`. Proof: V236.

## CD-CB-05a — Heredoc `RUN` with no `set -e`

```defect
id:       CD-CB-05a
file:     services/reports-py/Dockerfile
line:     10
severity: medium
command:  /devops-audit
class:    container/heredoc-no-errexit
detector: container-build-scan §5
anchor:   RUN <<EOT
match:    heredoc|set -e|errexit|alembic
```

`HEREDOC-NO-E`: a failing `compileall` is ignored. Fix: `set -eu`. Proof: V237.

## CD-CB-05b — `RUN cd` after a relative `WORKDIR src`

```defect
id:       CD-CB-05b
file:     services/billing-go/Dockerfile
line:     9
severity: low
command:  /devops-audit
class:    container/run-cd-relative-workdir
detector: container-build-scan §5
anchor:   RUN cd cmd/billing && go vet ./...
match:    cd|WORKDIR|relative
```

`RUN-CD` + `WORKDIR-RELATIVE` (DL3003/DL3000). Fix: absolute WORKDIR. Proof: V237.

## CD-CB-05c — Global `ARG APP_VERSION` not redeclared in the stage

```defect
id:       CD-CB-05c
file:     services/billing-go/Dockerfile
line:     10
severity: medium
command:  /devops-audit
class:    container/arg-scope
detector: container-build-scan §5
anchor:   -ldflags "-X main.version=${APP_VERSION}"
match:    ARG|scope|APP_VERSION|empty|redeclar
```

`ARG-SCOPE`: the binary reports an empty version. Fix: `ARG APP_VERSION` after FROM. Proof: V237.

## CD-CB-06a — `HEALTHCHECK … curl` on node:22-bookworm-slim (no curl)

```defect
id:       CD-CB-06a
file:     apps/api/Dockerfile
line:     25
severity: medium
command:  /devops-audit
class:    container/healthcheck-binary-missing
detector: container-build-scan §6
anchor:   HEALTHCHECK --interval=30s --timeout=3s CMD curl
match:    curl|HEALTHCHECK|healthy|slim
```

Never healthy; compose gates on it. Fix: `node -e fetch(…)`. Proof: V238.

## CD-CB-06b — Worker HEALTHCHECK probes 3000 while `PORT=8081`

```defect
id:       CD-CB-06b
file:     apps/worker/Dockerfile
line:     20
severity: medium
command:  /devops-audit
class:    container/healthcheck-wrong-port
detector: container-build-scan §6
anchor:   fetch('http://localhost:3000/healthz')
match:    port|3000|8081|HEALTHCHECK
```

`HC-PORT`. Fix: probe `$PORT`. Proof: V238.

## CD-CB-07a — Build stage on Node 18 (EOL 2025-04-30)

```defect
id:       CD-CB-07a
file:     apps/web/Dockerfile.web
line:     2
severity: medium
command:  /devops-audit
class:    container/base-eol
detector: container-build-scan §7
anchor:   FROM node:18-alpine AS build
match:    18|EOL|end.?of.?life|unsupported
```

Fix: `node:22-alpine`. Proof: V239.

## CD-CB-07b — Constant `--platform=linux/amd64` builder, no `TARGETARCH`

```defect
id:       CD-CB-07b
file:     services/billing-go/Dockerfile
line:     4
severity: medium
command:  /devops-audit
class:    container/platform-constant
detector: container-build-scan §7
anchor:   FROM --platform=linux/amd64 golang:1.24-bookworm AS build
match:    platform|amd64|TARGETARCH|arm
```

`PLATFORM-CONST`: arm64 builds ship an amd64 binary. Fix: `$BUILDPLATFORM` + `GOARCH=$TARGETARCH`. Proof: V239.

## CD-CB-07c — musl-built `node_modules` (argon2) copied into a glibc runtime

```defect
id:       CD-CB-07c
file:     apps/api/Dockerfile
line:     20
severity: high
command:  /devops-audit
class:    container/libc-mismatch
detector: container-build-scan §7
anchor:   COPY --from=deps /app/node_modules ./node_modules
match:    musl|glibc|alpine|libc|argon2|native
```

`LIBC-MISMATCH`: the native addon fails to load. Fix: one libc. Proof: V239.

## CD-CB-08a — Worker runtime copies the unpruned build `node_modules`

```defect
id:       CD-CB-08a
file:     apps/worker/Dockerfile
line:     16
severity: low
command:  /devops-audit
class:    container/builder-residue
detector: container-build-scan §8
anchor:   COPY --from=build /app/node_modules ./node_modules
match:    dev|prune|residue|node_modules
```

`RESIDUE`. Fix: `npm prune --omit=dev`. Proof: V240.

## CD-CB-08b — `build-essential` installed in the shipped stage

```defect
id:       CD-CB-08b
file:     services/reports-py/Dockerfile
line:     7
severity: medium
command:  /devops-audit
class:    container/build-tools-shipped
detector: container-build-scan §8
anchor:   build-essential libpq-dev
match:    build-essential|compiler|runtime|gcc
```

`BUILD-TOOLS`. Fix: a builder stage. Proof: V240.

## CD-CB-09a — Two `CMD` instructions in the final stage

```defect
id:       CD-CB-09a
file:     services/billing-go/Dockerfile
line:     16
severity: low
command:  /devops-audit
class:    container/duplicate-cmd
detector: container-build-scan §9
anchor:   CMD ["/billing"]
match:    CMD|duplicate|two|migrate
```

`DUP-CMD` (DL4003): the `migrate` CMD is dead. Proof: V237.

## CD-CB-09b — `RUN apt-get update` alone in its own layer

```defect
id:       CD-CB-09b
file:     services/reports-py/Dockerfile
line:     6
severity: low
command:  /devops-audit
class:    container/apt-update-alone
detector: container-build-scan §9
anchor:   RUN apt-get update
match:    apt-get update|cache|stale|alone|DL3009
```

The cached update layer serves stale lists to the next install. Fix: one RUN, clean lists. Proof: V237.

## CD-CB-10a — SLSA L3 reproducibility claimed; no `SOURCE_DATE_EPOCH` anywhere

```defect
id:       CD-CB-10a
file:     SECURITY.md
line:     8
severity: high
command:  /devops-audit
class:    container/reproducibility-claimed-not-built
detector: container-build-scan §10
anchor:   reproducible build at SLSA Build L3
match:    reproducib|SLSA|SOURCE_DATE_EPOCH|timestamp
```

Fix: `SOURCE_DATE_EPOCH` + `rewrite-timestamp=true`, or drop the claim. Proof: V242.

## CD-CB-10b — reports base by tag under the reproducibility claim

```defect
id:       CD-CB-10b
file:     services/reports-py/Dockerfile
line:     3
severity: medium
command:  /devops-audit
class:    container/base-by-tag-under-claim
detector: container-build-scan §10
anchor:   FROM python:3.12-slim
match:    digest|tag|base|reproducib
```

Fix: pin by digest with a bot. Proof: V242.

## CD-CP-01a — `depends_on: [db]` (= service_started)

```defect
id:       CD-CP-01a
file:     compose.yaml
line:     37
severity: medium
command:  /devops-audit
class:    compose/depends-on-ungated
detector: compose-scan §1
anchor:   depends_on: [db]
match:    depends_on|started|healthy|ready
```

reports boots before Postgres accepts connections. Proof: V241.

## CD-CP-01b — worker → redis `condition: service_started`

```defect
id:       CD-CP-01b
file:     compose.yaml
line:     32
severity: medium
command:  /devops-audit
class:    compose/depends-on-ungated
detector: compose-scan §1
anchor:   condition: service_started
match:    service_started|redis|healthy|ready
```

Fix: a redis healthcheck + `service_healthy`. Proof: V241.

## CD-CP-02a — Postgres healthcheck runs `curl` against 5432

```defect
id:       CD-CP-02a
file:     compose.yaml
line:     58
severity: medium
command:  /devops-audit
class:    compose/healthcheck-never-healthy
detector: compose-scan §2
anchor:   test: ["CMD", "curl", "-f", "http://localhost:5432"]
match:    curl|postgres|pg_isready|healthy
```

No curl in the image and Postgres speaks no HTTP. Fix: `pg_isready`. Proof: V238.

## CD-CP-02b — api waits on `reports` `service_healthy`; reports has no healthcheck

```defect
id:       CD-CP-02b
file:     compose.yaml
line:     17
severity: medium
command:  /devops-audit
class:    compose/healthy-gate-no-healthcheck
detector: compose-scan §2
anchor:   condition: service_healthy
match:    service_healthy|no healthcheck|reports|up fails
```

`DEP-HEALTHY-NO-HC`: `up` fails. Proof: V241.

## CD-CP-03a — `image: …:${TAG}` with no default or required marker

```defect
id:       CD-CP-03a
file:     compose.yaml
line:     8
severity: medium
command:  /devops-audit
class:    compose/interpolation-no-default
detector: compose-scan §3
anchor:   image: ghcr.io/acme/shop-api:${TAG}
match:    TAG|interpolat|unset|default|empty
```

Fix: `${TAG:?TAG required}`. Proof: V241.

## CD-CP-03b — `ports: ["${API_PORT}:3000"]` with no default

```defect
id:       CD-CP-03b
file:     compose.yaml
line:     10
severity: medium
command:  /devops-audit
class:    compose/interpolation-no-default
detector: compose-scan §3
anchor:   - "${API_PORT}:3000"
match:    API_PORT|interpolat|unset|default|port
```

Unset → an ephemeral host port. Fix: `${API_PORT:-3000}`. Proof: V241.

## CD-CP-04a — Shop host `docker compose up -d` with no `-f` auto-loads `compose.override.yaml`

```defect
id:       CD-CP-04a
file:     scripts/deploy-host.sh
line:     8
severity: high
command:  /devops-audit
class:    compose/override-loaded-in-prod
detector: compose-scan §4
anchor:   docker compose up -d'
match:    override|-f|inspect|9229|bind|default
```

Production gets the inspector and the source bind mount. Fix: `-f compose.yaml -f compose.prod.yaml`. Proof: V241.

## CD-CP-04b — Override publishes the Node inspector on 9229

```defect
id:       CD-CP-04b
file:     compose.override.yaml
line:     6
severity: high
command:  /devops-audit
class:    compose/debug-port
detector: compose-scan §4
anchor:   - "9229:9229"
match:    9229|inspect|debug
```

Proof: V241 (`OVERRIDE-ADDS port`).

## CD-CP-05a — `image: redis` untagged in the prod overlay

```defect
id:       CD-CP-05a
file:     compose.prod.yaml
line:     12
severity: medium
command:  /devops-audit
class:    compose/image-untagged
detector: compose-scan §5
anchor:   image: redis
match:    untagged|latest|tag|redis
```

Fix: `redis:7.4-alpine` + a bot. Proof: V241.

## CD-CP-05b — `postgres:latest` in the prod overlay (base pins 16.4)

```defect
id:       CD-CP-05b
file:     compose.prod.yaml
line:     4
severity: medium
command:  /devops-audit
class:    compose/image-latest
detector: compose-scan §5
anchor:   image: postgres:latest
match:    latest|tag|postgres|major
```

A new host pulls a new major onto the 16 data dir. Proof: V241.

## CD-CP-06a — Top-level `version: "3.8"`

```defect
id:       CD-CP-06a
file:     compose.yaml
line:     1
severity: low
command:  /devops-audit
class:    compose/legacy-key
detector: compose-scan §6
anchor:   version: "3.8"
match:    version|obsolete|legacy
```

Obsolete. Proof: V241.

## CD-CP-06b — `container_name` on a 2-replica service

```defect
id:       CD-CP-06b
file:     compose.yaml
line:     24
severity: medium
command:  /devops-audit
class:    compose/scale-blocker
detector: compose-scan §6
anchor:   container_name: shop-worker
match:    container_name|replica|scale
```

`CN-SCALED`. Proof: V241.

## CD-CP-07a — `restart: always` on the one-shot `migrate`

```defect
id:       CD-CP-07a
file:     compose.yaml
line:     48
severity: medium
command:  /devops-audit
class:    compose/oneshot-restart-always
detector: compose-scan §7
anchor:   restart: always
match:    restart|always|migrat|loop|one.?shot
```

`RESTART-ONESHOT`. Fix: `restart: "no"`. Proof: V241.

## CD-CP-07b — `stop_grace_period: 2s` with a 25 s gunicorn drain

```defect
id:       CD-CP-07b
file:     compose.yaml
line:     40
severity: medium
command:  /devops-audit
class:    compose/stop-grace-short
detector: compose-scan §7
anchor:   stop_grace_period: 2s
match:    stop_grace|2s|drain|25|graceful
```

`GRACE-SHORT`. Proof: V231.

## CD-HO-SEC-a — `issue_comment` checks out `refs/pull/N/head` and runs a script with preview credentials

```defect
id:       CD-HO-SEC-a
file:     .github/workflows/issue-triage.yml
line:     35
severity: critical
command:  /security-audit
class:    security/privileged-trigger-untrusted-checkout
detector: ci-security-scan §1 (security)
anchor:   ref: refs/pull/${{ github.event.issue.number }}/head
match:    refs/pull|issue_comment|checkout|untrusted|pull request
```

Any commenter's PR head runs `./scripts/deploy-preview.sh` with `KUBE_CONFIG_PREVIEW`. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-b — `pull_request_target` + `gh pr checkout` + `npm test`

```defect
id:       CD-HO-SEC-b
file:     .github/workflows/pr-target.yml
line:     23
severity: critical
command:  /security-audit
class:    security/privileged-trigger-untrusted-checkout
detector: ci-security-scan §1 (security)
anchor:   gh pr checkout ${{ github.event.pull_request.number }}
match:    pull_request_target|gh pr checkout|untrusted|fork
```

Fork code runs with a write token. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-c — Issue title interpolated into `run:` beside an integer field

```defect
id:       CD-HO-SEC-c
file:     .github/workflows/issue-triage.yml
line:     21
severity: critical
command:  /security-audit
class:    security/expression-injection
detector: ci-security-scan §2 (security)
anchor:   echo "Triage #${{ github.event.issue.number }}: ${{ github.event.issue.title }}"
match:    inject|issue\.title|expression|run
```

The integer on the same line must not hide the title. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-d — Bracket-form `github.event['comment'].body` in `run:`

```defect
id:       CD-HO-SEC-d
file:     .github/workflows/issue-triage.yml
line:     45
severity: critical
command:  /security-audit
class:    security/expression-injection
detector: ci-security-scan §2 (security)
anchor:   ${{ github.event['comment'].body }}
match:    inject|comment|bracket|body
```

The bracket form evades dotted-path greps. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-e — Issue title written to `GITHUB_ENV`

```defect
id:       CD-HO-SEC-e
file:     .github/workflows/issue-triage.yml
line:     22
severity: high
command:  /security-audit
class:    security/github-env-injection
detector: ci-security-scan §2 (security)
anchor:   echo "ISSUE_TITLE=${{ github.event.issue.title }}" >> "$GITHUB_ENV"
match:    GITHUB_ENV|inject|title|environment
```

A newline in the title sets arbitrary variables for later steps. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-f — Composite action interpolates `inputs.who`, fed a PR title by `pr-target.yml`

```defect
id:       CD-HO-SEC-f
file:     .github/actions/setup/action.yml
line:     14
severity: high
command:  /security-audit
class:    security/composite-input-injection
detector: ci-security-scan §2 (security)
anchor:   run: echo "Setting up the workspace for ${{ inputs.who }}"
match:    composite|inputs\.who|inject|title
```

One unit, N call sites (precedents § 5). Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-g — AI agent fed the issue body with `contents: write` and `Bash(*)`

```defect
id:       CD-HO-SEC-g
file:     .github/workflows/issue-triage.yml
line:     62
severity: critical
command:  /security-audit
class:    security/ai-agent-untrusted-input
detector: ci-security-scan §3 (security)
anchor:   ${{ github.event.issue.body }}
match:    claude|agent|prompt|Bash|issue body
```

Prompt injection with shell and write access. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-h — Tag-pinned third-party action in the `packages: write` release job

```defect
id:       CD-HO-SEC-h
file:     .github/workflows/release.yml
line:     50
severity: high
command:  /security-audit
class:    security/pin-privilege
detector: ci-security-scan §4 (security)
anchor:   uses: docker/login-action@v3
match:    pin|sha|tag|v3|login-action|packages
```

`ci-graph.py --check=pin-priv` prints `PIN×PRIV`. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-i — `container: node:22-bookworm` with no digest in the staging deploy job

```defect
id:       CD-HO-SEC-i
file:     .github/workflows/deploy.yml
line:     63
severity: medium
command:  /security-audit
class:    security/image-no-digest
detector: ci-security-scan §4 (security)
anchor:   container: node:22-bookworm
match:    container|digest|node:22|image
```

The job holds the staging kubeconfig. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-j — Release (tag) workflow restores a setup-node cache before `npm publish`

```defect
id:       CD-HO-SEC-j
file:     .github/workflows/release.yml
line:     23
severity: high
command:  /security-audit
class:    security/cache-in-release
detector: ci-security-scan §5 (security)
anchor:   cache: pnpm
match:    cache|release|tag|poison|restore
```

A cache written by a lower-trust run feeds a publish. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-k — GitLab `eval` of `$CI_MERGE_REQUEST_TITLE`

```defect
id:       CD-HO-SEC-k
file:     .gitlab-ci.yml
line:     41
severity: critical
command:  /security-audit
class:    security/expression-injection
detector: ci-security-scan §9 (security)
anchor:   eval "echo Building merge request $CI_MERGE_REQUEST_TITLE"
match:    eval|MERGE_REQUEST_TITLE|inject
```

Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-l — Jenkins double-quoted `sh` with `${env.CHANGE_TITLE}`

```defect
id:       CD-HO-SEC-l
file:     Jenkinsfile.groovy
line:     19
severity: critical
command:  /security-audit
class:    security/expression-injection
detector: ci-security-scan §9 (security)
anchor:   sh "echo Building ${env.CHANGE_TITLE}"
match:    CHANGE_TITLE|groovy|interpolat|inject
```

Groovy interpolates before the shell. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-m — Azure `##vso[task.setvariable]` from the PR source branch

```defect
id:       CD-HO-SEC-m
file:     azure-pipelines.yml
line:     17
severity: high
command:  /security-audit
class:    security/logging-command-injection
detector: ci-security-scan §9 (security)
anchor:   $(System.PullRequest.SourceBranch)
match:    vso|setvariable|SourceBranch|inject
```

Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-n — CircleCI `<< pipeline.git.branch >>` in a `command:`

```defect
id:       CD-HO-SEC-n
file:     .circleci/config.yml
line:     50
severity: high
command:  /security-audit
class:    security/expression-injection
detector: ci-security-scan §9 (security)
anchor:   << pipeline.git.branch >>
match:    pipeline\.git\.branch|inject|branch
```

Substituted into config before the shell runs. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-o — Worker final stage inherits `USER root`

```defect
id:       CD-HO-SEC-o
file:     apps/worker/Dockerfile
line:     4
severity: high
command:  /security-audit
class:    security/container-root
detector: iac-scan §1 (security)
anchor:   USER root
match:    root|USER|inherit
```

`FROM base` carries the base stage's root user into the shipped image. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-p — `ARG NPM_TOKEN` + `ENV NPM_TOKEN` in the api build

```defect
id:       CD-HO-SEC-p
file:     apps/api/Dockerfile
line:     11
severity: high
command:  /security-audit
class:    security/secret-build-arg
detector: iac-scan §1 (security)
anchor:   ARG NPM_TOKEN
match:    NPM_TOKEN|ARG|ENV|secret|layer
```

The token lands in image metadata. Use `--mount=type=secret`. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-q — Postgres published on all interfaces with a literal password (CANARY placeholder)

```defect
id:       CD-HO-SEC-q
file:     compose.yaml
line:     53
severity: high
command:  /security-audit
class:    security/compose-exposure
detector: iac-scan §2 (security)
anchor:   - "5432:5432"
match:    5432|publish|0\.0\.0\.0|password|exposed
```

Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-r — Prod overlay deploys `shop-api:main` by mutable tag

```defect
id:       CD-HO-SEC-r
file:     deploy/k8s/overlays/prod/kustomization.yaml
line:     9
severity: high
command:  /security-audit
class:    security/deploy-by-mutable-tag
detector: iac-scan §3 grep 4j (security)
anchor:   newTag: main
match:    newTag|main|mutable|tag|digest
```

release §4/§7 corroborate. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-s — npm publish with a long-lived `NPM_TOKEN`

```defect
id:       CD-HO-SEC-s
file:     .github/workflows/release.yml
line:     31
severity: medium
command:  /security-audit
class:    security/long-lived-publish-token
detector: ci-security-scan §6 (security)
anchor:   NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
match:    NPM_TOKEN|long.?lived|trusted publish|OIDC
```

Use npm trusted publishing (OIDC). Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-SEC-t — Flow-map `permissions: { contents: write, packages: write }` at workflow level

```defect
id:       CD-HO-SEC-t
file:     .github/workflows/release.yml
line:     6
severity: medium
command:  /security-audit
class:    security/workflow-write-permissions
detector: ci-security-scan §6 (security)
anchor:   permissions: { contents: write, packages: write }
match:    permission|write|workflow|least
```

Every job, including `publish-sdk`, inherits write scopes. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-TST-a — `continue-on-error: true` on the required `test` job

```defect
id:       CD-HO-TST-a
file:     .github/workflows/ci.yml
line:     45
severity: critical
command:  /test-audit
class:    testing/required-test-job-masked
detector: suite-execution-scan §4 (testing)
anchor:   continue-on-error: true # TODO(#812)
match:    continue-on-error|test|mask|required
```

Devops supplies the required-check join only. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-TST-b — CI test script runs `jest --passWithNoTests`

```defect
id:       CD-HO-TST-b
file:     apps/api/package.json
line:     9
severity: medium
command:  /test-audit
class:    testing/zero-tests-pass
detector: suite-execution-scan §4 (testing)
anchor:   --passWithNoTests
match:    passWithNoTests|zero|no tests
```

Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-TST-c — GitLab `retry: 2` on the test job (default `when: always`)

```defect
id:       CD-HO-TST-c
file:     .gitlab-ci.yml
line:     26
severity: medium
command:  /test-audit
class:    testing/retry-no-gate
detector: suite-execution-scan §6 (testing)
anchor:   retry: 2
match:    retry|flaky|rerun
```

Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-INF-a — Grace 20 s, no `preStop`, gunicorn drains 25 s

```defect
id:       CD-HO-INF-a
file:     deploy/k8s/base/reports-deployment.yaml
line:     14
severity: medium
command:  /infra-audit
class:    infrastructure/shutdown-grace
detector: k8s-availability-scan §7 (infrastructure)
anchor:   terminationGracePeriodSeconds: 20
match:    grace|preStop|25|drain|terminat
```

deploy-safety §5 hands the drain number over. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-INF-b — `revisionHistoryLimit: 0` on the api

```defect
id:       CD-HO-INF-b
file:     deploy/k8s/base/api-deployment.yaml
line:     8
severity: medium
command:  /infra-audit
class:    infrastructure/revision-history-zero
detector: k8s-availability-scan §6 (infrastructure)
anchor:   revisionHistoryLimit: 0
match:    revisionHistoryLimit|history|rollout undo|rollback
```

`rollout undo` has nothing to return to; release §7 corroborates. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-INF-c — Argo `prune` + `selfHeal` on a Deployment with `replicas: 2` and an HPA

```defect
id:       CD-HO-INF-c
file:     deploy/argocd/app-web.yaml
line:     18
severity: high
command:  /infra-audit
class:    infrastructure/gitops-replicas-vs-hpa
detector: k8s-render-scan §4 (infrastructure)
anchor:   selfHeal: true
match:    selfHeal|HPA|replicas|ignoreDifferences
```

Argo and the HPA fight over replicas (K-GITOPS-REPLICAS). Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-OBS-a — Rollout error-budget page selects a series no code registers

```defect
id:       CD-HO-OBS-a
file:     deploy/monitoring/rollout-alerts.rules.yml
line:     6
severity: high
command:  /obs-audit
class:    observability/selector-not-in-inventory
detector: alert-rule-lint §4 (observability)
anchor:   shop_api_http_errors_total
match:    shop_api_http_errors_total|series|inventory|never fires|selector
```

`rule-inventory.py --check=selectors`: never fires. Routed: `/devops-audit` lists it as its owner's, never grades it.

## CD-HO-OBS-b — Page `WorkerQueueBacklog` has no `for:`

```defect
id:       CD-HO-OBS-b
file:     deploy/monitoring/rollout-alerts.rules.yml
line:     13
severity: medium
command:  /obs-audit
class:    observability/page-without-for
detector: alert-rule-lint §1 (observability)
anchor:   alert: WorkerQueueBacklog
match:    for|flap|WorkerQueueBacklog|page
```

Routed: `/devops-audit` lists it as its owner's, never grades it.

## Decoys — must NOT be reported

Each decoy is the correct sibling of a seeded shape, built from the eval's decoy list (§ 4.7, items 1–28 in order)
and `precedents/devops.md`. A finding that names the decoy's file, cites a line within the tolerance window and
matches every one of its `match:` patterns is **pinned** to it and reported as `DECOYS FLAGGED k/N` (`score.py`,
§ DECOYS). Every decoy sits more than 12 lines from every defect in its file (`--verify` enforces it). `CD-DECOY-20`
probes `/security-audit` (a verified `ADD` download); the rest probe `/devops-audit`.

| id | file:line | looks like | why it is safe |
|----|-----------|-----------|----------------|
| CD-DECOY-01 | `.github/workflows/ci.yml:24` | CD-DS-02a | PR CI keyed on the PR number; cancelling superseded runs is intended (precedents § 15); no job here deploys |
| CD-DECOY-02 | `.github/workflows/preview.yml:13` | CD-DS-02a | per-PR preview: may cancel, needs no reviewer or test gate (precedents § 24) |
| CD-DECOY-03 | `.github/workflows/ci.yml:140` | CD-PI-01a | idempotent cleanup (precedents § 13) |
| CD-DECOY-04 | `.github/workflows/nightly.yml:43` | CD-PI-01a | declared-experimental leg with `fail-fast: false` (precedents § 12) |
| CD-DECOY-05 | `.github/workflows/ci-web.yml:85` | CD-PI-03d | aggregator fails on failure and cancelled (precedents § 8, § 10) |
| CD-DECOY-06 | `.github/workflows/ci-web.yml:23` | CD-PI-03a | job-level filter behind the always() aggregator (precedents § 9); the filter reads the PR API, not git history |
| CD-DECOY-07 | `.github/workflows/ci.yml:99` | CD-PI-02a | step sets `shell: bash` (pipefail; precedents § 43) |
| CD-DECOY-08 | `.circleci/config.yml:16` | CD-PI-02b | CircleCI's default shell is `bash -eo pipefail` (precedents § 14) |
| CD-DECOY-09 | `.github/workflows/ci.yml:142` | CD-PI-04a | artifact upload on failure (precedents § 8) |
| CD-DECOY-10 | `deploy/k8s/billing-migrate/job.yaml:16` | CD-DS-01c | one-shot Job, applied alone and waited on by `migrate_billing_staging`, TTL'd |
| CD-DECOY-11 | `apps/admin/docker-entrypoint.sh:4` | CD-DS-01b | one replica and Prisma's advisory lock (precedents § 22) |
| CD-DECOY-12 | `apps/admin/Containerfile:15` | CD-CB-04c | `npm ci` enforces the lockfile |
| CD-DECOY-13 | `apps/admin/Containerfile:21` | CD-CB-03a | manifest-first copy then install, `COPY . .` after (precedents § 34) |
| CD-DECOY-14 | `apps/admin/Containerfile:24` | CD-HO-SEC-o | inherits `USER 10001` from `base` (the P2 false-positive shape) |
| CD-DECOY-15 | `apps/admin/Containerfile:10` | CD-CB-01b | numeric user with `runAsUser: 10001` (precedents § 37) |
| CD-DECOY-16 | `apps/admin/Containerfile:32` | CD-CB-02a | exec form behind tini, and admin calls `enableShutdownHooks()` |
| CD-DECOY-17 | `apps/web/Dockerfile.web:15` | CD-CB-02a | nginx's graceful stop signal (precedents § 36) |
| CD-DECOY-18 | `apps/admin/Containerfile:30` | CD-CB-06a | uses the app's own runtime, no curl needed |
| CD-DECOY-19 | `apps/admin/Containerfile:6` | CD-CB-09b | update and install in one RUN with apt cache mounts |
| CD-DECOY-20 | `apps/admin/Containerfile:8` | iac-scan §1 ADD URL | the download is verified by `--checksum` |
| CD-DECOY-21 | `apps/admin/src/main.ts:11` | CD-DS-06a | platform-set variables (precedents § 26) |
| CD-DECOY-22 | `apps/api/src/config/config.schema.ts:7` | CD-DS-06a | declared by the boot-validated schema with a default (precedents § 26) |
| CD-DECOY-23 | `scripts/promote.sh:8` | CD-RI-05a | exact identity + issuer, by digest |
| CD-DECOY-24 | `scripts/promote.sh:14` | CD-RI-04a | promotes by digest, no rebuild |
| CD-DECOY-25 | `compose.prod.yaml:26` | CD-CP-01a | db gated on a `pg_isready` healthcheck |
| CD-DECOY-26 | `compose.prod.yaml:28` | CD-CP-07a | `restart: "no"` + `service_completed_successfully` |
| CD-DECOY-27 | `apps/web/src/export/ExportButton.tsx:10` | CD-PD-08a | safe default `false` on a permanent flag |
| CD-DECOY-28 | `deploy/rollouts/analysis-template.yaml:54` | CD-PD-05a | can fail, scoped to the canary hash, failureLimit 1 of count 5 |

```decoy
id:       CD-DECOY-01
file:     .github/workflows/ci.yml
line:     24
command:  /devops-audit
class:    decoy/CD-DS-02a
anchor:   cancel-in-progress: true
match:    cancel|concurrency
```
```decoy
id:       CD-DECOY-02
file:     .github/workflows/preview.yml
line:     13
command:  /devops-audit
class:    decoy/CD-DS-02a
anchor:   cancel-in-progress: true
match:    cancel|concurrency|preview|ungated
```
```decoy
id:       CD-DECOY-03
file:     .github/workflows/ci.yml
line:     140
command:  /devops-audit
class:    decoy/CD-PI-01a
anchor:   run: docker rm -f smoke || true
match:    \|\| ?true|mask|docker rm
```
```decoy
id:       CD-DECOY-04
file:     .github/workflows/nightly.yml
line:     43
command:  /devops-audit
class:    decoy/CD-PI-01a
anchor:   continue-on-error: ${{ matrix.experimental == true }}
match:    continue-on-error|experimental|mask
```
```decoy
id:       CD-DECOY-05
file:     .github/workflows/ci-web.yml
line:     85
command:  /devops-audit
class:    decoy/CD-PI-03d
anchor:   contains(needs.*.result, 'cancelled')
match:    aggregator|always|web-green|cancel
```
```decoy
id:       CD-DECOY-06
file:     .github/workflows/ci-web.yml
line:     23
command:  /devops-audit
class:    decoy/CD-PI-03a
anchor:   uses: dorny/paths-filter@
match:    path|filter|pending|skip|shallow
```
```decoy
id:       CD-DECOY-07
file:     .github/workflows/ci.yml
line:     99
command:  /devops-audit
class:    decoy/CD-PI-02a
anchor:   run: pnpm build 2>&1 | tee build.log
match:    tee|pipe|pipefail
```
```decoy
id:       CD-DECOY-08
file:     .circleci/config.yml
line:     16
command:  /devops-audit
class:    decoy/CD-PI-02b
anchor:   python -m pytest -q --junitxml=junit.xml | tee pytest.log
match:    tee|pipe|pipefail
```
```decoy
id:       CD-DECOY-09
file:     .github/workflows/ci.yml
line:     142
command:  /devops-audit
class:    decoy/CD-PI-04a
anchor:   if: failure()
match:    failure\(\)|always|artifact|upload
```
```decoy
id:       CD-DECOY-10
file:     deploy/k8s/billing-migrate/job.yaml
line:     16
command:  /devops-audit
class:    decoy/CD-DS-01c
anchor:   args: ["goose up"]
match:    migrat|goose|job|replica|concurrent
```
```decoy
id:       CD-DECOY-11
file:     apps/admin/docker-entrypoint.sh
line:     4
command:  /devops-audit
class:    decoy/CD-DS-01b
anchor:   npx prisma migrate deploy
match:    migrat|prisma|replica|concurrent|lock
```
```decoy
id:       CD-DECOY-12
file:     apps/admin/Containerfile
line:     15
command:  /devops-audit
class:    decoy/CD-CB-04c
anchor:   RUN npm ci --omit=dev
match:    npm ci|lockfile|frozen
```
```decoy
id:       CD-DECOY-13
file:     apps/admin/Containerfile
line:     21
command:  /devops-audit
class:    decoy/CD-CB-03a
anchor:   COPY . .
match:    COPY|layer|order|cache
```
```decoy
id:       CD-DECOY-14
file:     apps/admin/Containerfile
line:     24
command:  /devops-audit
class:    decoy/CD-HO-SEC-o
anchor:   FROM base AS final
match:    root|USER|inherit
```
```decoy
id:       CD-DECOY-15
file:     apps/admin/Containerfile
line:     10
command:  /devops-audit
class:    decoy/CD-CB-01b
anchor:   USER 10001
match:    runAsNonRoot|numeric|named|uid
```
```decoy
id:       CD-DECOY-16
file:     apps/admin/Containerfile
line:     32
command:  /devops-audit
class:    decoy/CD-CB-02a
anchor:   CMD ["node", "dist/main.js"]
match:    PID ?1|SIGTERM|signal|shell
```
```decoy
id:       CD-DECOY-17
file:     apps/web/Dockerfile.web
line:     15
command:  /devops-audit
class:    decoy/CD-CB-02a
anchor:   STOPSIGNAL SIGQUIT
match:    STOPSIGNAL|SIGQUIT|signal
```
```decoy
id:       CD-DECOY-18
file:     apps/admin/Containerfile
line:     30
command:  /devops-audit
class:    decoy/CD-CB-06a
anchor:   HEALTHCHECK --interval=30s --start-period=20s CMD ["node", "healthcheck.js"]
match:    HEALTHCHECK|curl|binary|healthy
```
```decoy
id:       CD-DECOY-19
file:     apps/admin/Containerfile
line:     6
command:  /devops-audit
class:    decoy/CD-CB-09b
anchor:   --mount=type=cache,target=/var/cache/apt,sharing=locked
match:    apt-get update|cache|stale|lists
```
```decoy
id:       CD-DECOY-20
file:     apps/admin/Containerfile
line:     8
command:  /security-audit
class:    decoy/iac-scan §1 ADD URL
anchor:   ADD --checksum=sha256:
match:    ADD|checksum|download|unverified|integrity
```
```decoy
id:       CD-DECOY-21
file:     apps/admin/src/main.ts
line:     11
command:  /devops-audit
class:    decoy/CD-DS-06a
anchor:   const port = Number(process.env.PORT ?? 3000);
match:    PORT|HOSTNAME|declar|undeclared
```
```decoy
id:       CD-DECOY-22
file:     apps/api/src/config/config.schema.ts
line:     7
command:  /devops-audit
class:    decoy/CD-DS-06a
anchor:   REDIS_URL: Joi.string().uri().default('redis://localhost:6379'),
match:    REDIS_URL|declar|default|schema
```
```decoy
id:       CD-DECOY-23
file:     scripts/promote.sh
line:     8
command:  /devops-audit
class:    decoy/CD-RI-05a
anchor:   cosign verify \
match:    identity|verify|regexp|any workflow
```
```decoy
id:       CD-DECOY-24
file:     scripts/promote.sh
line:     14
command:  /devops-audit
class:    decoy/CD-RI-04a
anchor:   docker buildx imagetools create
match:    rebuild|tag|imagetools|digest|promot
```
```decoy
id:       CD-DECOY-25
file:     compose.prod.yaml
line:     26
command:  /devops-audit
class:    decoy/CD-CP-01a
anchor:   condition: service_healthy
match:    depends_on|healthy|pg_isready|started
```
```decoy
id:       CD-DECOY-26
file:     compose.prod.yaml
line:     28
command:  /devops-audit
class:    decoy/CD-CP-07a
anchor:   condition: service_completed_successfully
match:    restart|migrat|one.?shot|completed
```
```decoy
id:       CD-DECOY-27
file:     apps/web/src/export/ExportButton.tsx
line:     10
command:  /devops-audit
class:    decoy/CD-PD-08a
anchor:   client.getBooleanValue('legacy-export', false)
match:    default|outage|legacy-export|true
```
```decoy
id:       CD-DECOY-28
file:     deploy/rollouts/analysis-template.yaml
line:     54
command:  /devops-audit
class:    decoy/CD-PD-05a
anchor:   successCondition: result[0] < 0.01
match:    never fail|condition|scope|canary|unscoped
```

## Detector measurement — the pre-flights run on this fixture

Measured 2026-10-10 on a staged copy (answer key removed, `git init`), each `SKILL.md` pre-flight extracted verbatim and
run as one bash 3.2 script from the copy's root, `SCAN` set per detector, an empty isolated `KUBECONFIG` first.
ripgrep 15.2.0; `ci-graph.py` loader Ruby psych (no PyYAML on the machine), `--self-test` 55/55. **Docker lane
blocked**: the daemon was not reachable (the client points at a stopped colima VM, which was not started), so
`docker build --check`, hadolint and the compose model lane print `blocked` — this is the eval's run 1, "tools and
docker blocked". `kubectl kustomize` and `helm template` rendered all seven roots offline (`render-*.yaml`).

A seed is **caught** when its owner's pre-flight prints its file:line (or a line of the same unit within 6), the
file-level or key-level row that names it, or the graph row for its job. **Partial** means the unit or line is printed
but not the class-specific flag. These are grep results, not a scored `/devops-audit` run — no run is recorded in
`RESULTS.md` yet.

| detector | lines printed (stderr) | seeds it owns | caught by its pre-flight | not caught / partial | decoys hit → read |
|----------|------------------------|---------------|--------------------------|----------------------|-------------------|
| `ci-graph.py` (`--all`; `--contexts=… --merge-queue`) | 27 rows (exit 1) + 4 required-join rows; 0.2 s | — (structural facts for the rows below) | `REQUIRED-PATH-FILTERED`, `NO-MERGE-GROUP`, `REQUIRED-IF-SKIP`, `AGGREGATOR-WEAK`, `DEPLOY-ALWAYS`, `DEPLOY-UNGATED` (publish-sdk), `WORKFLOW_RUN-NO-CONCLUSION`, `NO-TIMEOUT`, `MATRIX-EXCLUDES-RUNTIME`, `MATRIX-DYNAMIC-UNGUARDED`, `DEPLOY-CANCEL`, `GROUP-NOT-ENV` + `ENV-SPLIT-GROUPS`, `CACHE-*` ×4, `PIN×PRIV` (routed) | **no `WAIT-NO-TIMEOUT`** for CD-PI-06b (IR-1) | DECOY-02 → `DEPLOY-CANCEL` + `DEPLOY-UNGATED` on the preview (§ 24) |
| `pipeline-integrity-scan` | 160 (0) · 0.5 s | 24 (§1–§8) | **21** — §1 ×4 (grep 1a), §2 ×3 (2a), §3 ×4 (grep 3 + graph), §4 ×5 (4a/4b + graph), §5 CD-PI-05a (grep 5), §6 CD-PI-06a (graph), §7 ×2 (grep 7 + graph), §8 CD-PI-08b (grep 8) | CD-PI-06b **missed** (grep 6 and the graph's wait regex need `kubectl rollout status` adjacent; the line is `kubectl --kubeconfig … -n shop-staging rollout status`, IR-1); CD-PI-05b partial (the job's `needs: []`/verb lines print, the missing default-branch rule is a read); CD-PI-08a partial (grep 8 lists the file's schedules, the `if:` is a read) | DECOY-01, -03, -04, -07, -08, -09 printed; each cleared by one precedent (§ 15, § 13, § 12, § 43, § 14, § 8) |
| `pipeline-cache-scan` | 66 (0) · 0.4 s | 9 (§1–§4) | **7** — CD-PC-01a (graph), 01b (1c `NO-LOCKFILE-IN-KEY`), 01c (graph + 1a `PREFIX-RESTORE-INSTALL-DIR`), 02a (`MODE-MIN`), 02b (`GHA-DEFAULT-SCOPE` + "2 image builds"), 03a (`deep-clone=NO`), 03b ("PR workflow without concurrency") | CD-PC-04a, 04b **not surfaced**: §4 is timing data (`UNREADABLE` without a token) and no grep looks at serial `needs:` chains or GitLab stages (IR-8). 1a printed no row for the `ci-web.yml` cache (IR-2; the graph caught it) | DECOY-06 by grep 3 (paths-filter, `deep-clone=NO`) → cleared: the filter reads the PR API |
| `release-integrity-scan` | 127 (0) · 0.6 s | 17 (§1–§7) | **16** — §1 ×2 (1a + `NO-ANCESTRY-CHECK`), §2 ×2, §3 ×3 (3a + `NO-EXISTENCE-GUARD`, 3c), §4: `BUILD-IN-DEPLOY` + `NO-DIGEST-HANDOFF` (04a), 4c `ref=TAG` (04c), §5 ×3 (`identity=REGEXP ref=TAG`, `scope=OWNER-ONLY`, `ATTACH`), §6 ×2 (`RELEASE-BOT token=GITHUB_TOKEN` / `default`), §7 ×2 | CD-RI-04b partial: 0c prints the `load: true` and the `push: true` BUILD rows but `scans=0` and no `REBUILD-AFTER-SCAN` — a scanner run as `docker run … aquasec/trivy@sha256:… image` is not a SCAN row (IR-3) | DECOY-23 → `VERIFY identity=exact issuer=yes ref=digest` (cleared); DECOY-24: 0 rows |
| `deploy-safety-scan` | 153 (0) · 0.9 s | 18 (§1–§6) | **16** — §1 ×5 (1a boot-code / entrypoint / manifest × 1c floors 3/2/2; `migrate=AFTER-DEPLOY`; 1e `rollout undo` + the `DROP COLUMN` file), §2 ×3 (graph + `interruptible=yes`), §3 CD-DS-03a (`env=no`), §4 CD-DS-04b (`unwaited=1`), §5 ×3 (5a `NO-SHUTDOWN-HANDLER` ×3 roots, 5b `NEST-HOOKS-INERT hooks=1`), §6 ×3 (6a `read, not declared: … REPORTS_BUCKET STRIPE_WEBHOOK_SECRET`, 6b `.nvmrc 22` vs `FROM node:20`) | CD-DS-04a **missed**: the 0d awk counts `kubectl[ \t]+apply`, so `kubectl --kubeconfig … apply -k …/overlays/prod` is `verbs=0` (also `deploy-web`, `hotfix-prod` and the whole Azure unit vanish; `kubectl -n … wait` is not a wait, so `migrate_billing_staging` reads `unwaited=1`; IR-1). CD-DS-03b is a settings row: no grep reads the offline snapshot (IR-6) | DECOY-10, -11 (1a) → cleared (one-shot Job applied alone; 1 replica + Prisma lock, § 22); DECOY-21 by 6a (`PORT HOSTNAME`) → § 26; DECOY-22: not printed (schema-declared) |
| `container-build-scan` | 99 (0) · 0.4 s (110 with the docker lane) | 24 (§1–§10) | **23** — every awk fact fires on its seed: `NAMED` ×2 + `NONROOT-NO-UID` ×2, `PID1-SHELL-FORM` ×2, `PID1-SCRIPT` + 2b `NO-EXEC`, `LAYER-ORDER` ×2, grep 4 ×3, `HEREDOC-NO-E`, `RUN-CD` + `WORKDIR-RELATIVE`, `ARG-SCOPE`, `HC-BINARY`, `HC-PORT`, `BASE node:18-alpine`, `PLATFORM-CONST`, `LIBC-MISMATCH`, `RESIDUE`, `BUILD-TOOLS`, `DUP-CMD`, grep 10 (`SLSA Build L3`) + `BASE python:3.12-slim pin=version` | CD-CB-09b (`RUN apt-get update` alone) **not surfaced**: no awk fact, and the §9 lane (hadolint, `--check`) is blocked here (IR-9) | DECOY-12, -14, -15, -16, -18, -19, -20 printed as facts (`npm ci`, `user=10001 [inherited]`, `PID1-INIT tini`, R lane `ADD --checksum`) → each cleared by the read the skill prescribes |
| `compose-scan` | 54 (0) · 0.3 s (59 with the model lane NOT-RUN) | 14 (§1–§7) | **13** in the static lane (model lane blocked: every row `[report-flagged]`): depends_on ×3 blocks, curl healthcheck, `${TAG}`/`${API_PORT}`, 0b `files=DEFAULT(+override)` on the shop host + 0c override + R 9229, `postgres:latest`/`redis`, `version:`, `container_name` + `replicas: 2`, `restart: always`, `stop_grace_period: 2s` | CD-CP-02b partial: the `service_healthy` block prints; "the target has no healthcheck" is the model lane's `DEP-HEALTHY-NO-HC` | DECOY-25, -26 (compose.prod depends_on block) → cleared on read (`pg_isready`, `restart: "no"`) |
| `progressive-delivery` | 46 (0) · 0.6 s | 9 (§1, §2, §5, §8, §9) | **9** — `dead-banner literal=0 snake=0`, `new-search literal=0 snake=1` (→ §9), grep 2, `NEVER-FAILS`, `UNSCOPED`, `NO-ANALYSIS`, grep 8 ×2, grep 9; harness ok (3 keys) | — ; 5g grounding `NOT-RUN (owner pack observability not installed)` as designed | DECOY-28 → `scope=hash -> ok`; DECOY-27: 0 rows |
| `gitops-audit` | 26 (0) · 0.2 s | 2 (§1) | **2** — `MANAGED ns=shop-web` ×2 (CD target `web-prod`, `selfHeal=true prune=true`) | — | 13 other imperative lines tagged `unmanaged`/`unknown` (no controller owns `shop-prod`/`shop-staging`) |

Totals: **107 of 117** devops seeds surface in their owner's verbatim pre-flight with the class-specific row, 4 more as
a partial (the unit or line printed, the class settled by the read: CD-PI-05b, CD-PI-08a, CD-RI-04b, CD-CP-02b), and
**6 are missed**: CD-PI-06b and CD-DS-04a (IR-1), CD-DS-03b (the settings snapshot, IR-6), CD-PC-04a/b (IR-8) and
CD-CB-09b (IR-9). Decoys: every decoy a pre-flight prints clears by one precedent or one printed fact; DECOY-22, -24
and -27 print nothing. Unseeded lines worth naming: `DEPLOY-UNGATED` on `_build.yml` (the caller in `ci.yml` gates it on
`all-green`), on `deploy.yml` `build-image` (a sha-tagged candidate image) and on `release-pr.yml` (changesets with no
`publish:`); `DEPLOY-NOGROUP` ×2 on the release publish jobs (IR-7); release 1a `types: [created]` under
`issue_comment:` (IR-4); container `PIPE-NO-PIPEFAIL` on a `|` inside a quoted `sed` expression (IR-5).

**Run 3 (no YAML loader)** — `env PATH=<python3 only> CI_GRAPH_NO_UV=1 ci-graph.py . --all` prints
`NOT-RUN (no YAML loader)` and exits 2: every GitHub structural row above must then read `blocked (ci-graph NOT-RUN)`,
and the verdict is GO-UNVERIFIED. **Run 2 (docker)** — a re-run on the final tree (after the file renames in the header; every other pre-flight printed
the same line counts as run 1) found the daemon reachable for a few minutes, so the §9 build-check lane ran:
`docker build --check` and hadolint v2.15.1 corroborate CD-CB-02a (`JSONArgsRecommended`, DL3025), CD-CB-02c
(`JSONArgsRecommended`), CD-CB-05b (`WorkdirRelativePath`, DL3000, DL3003), CD-CB-07b
(`FromPlatformFlagConstDisallowed`, DL3029), CD-CB-09a (`MultipleInstructionsDisallowed`, DL4003) and the routed
CD-HO-SEC-o (DL3002); DL3008 on the admin apt line hits CD-DECOY-19 and clears by precedents § 32; hadolint is
**NOT-RUN on `services/reports-py/Dockerfile`** (parse error at the heredoc, line 14: precedents § 41), and neither tool
flags the lone `RUN apt-get update` (CD-CB-09b stays missed). The B-tier delta is therefore 0 new seeds, 6
corroborations, 1 decoy hit cleared. The compose model lane printed `NOT-RUN` both times (the daemon went away before
`docker compose config` ran).

Hand-off rows, run through their owners' pre-flights on a second copy with those skills installed:
- **security** — `ci-security-scan` (207 lines) prints every CI seed CD-HO-SEC-a…n, -s, -t within 3 lines (1a, 2a,
  2b, 2c, 3, 4a `PIN×PRIV`, 4c, 5b, 6b, 6d, 9a–9e); `iac-scan` prints -o (`ROOT [inherited]`), -p (`ARG NPM_TOKEN`), -q
  (`5432:5432` + the canary password) and -r (`newTag: main`, grep 4j). checkov and trivy were absent (their lanes
  NOT-RUN). **20/20.**
- **testing** — `suite-execution-scan` prints `continue-on-error` on `ci.yml:45`, `--passWithNoTests` and
  `retry: 2`. **3/3.**
- **observability** — `rule-inventory.py` on `deploy/monitoring/rollout-alerts.rules.yml` (5-name inventory from the
  prom-client registrations): `AL-10 [H] shop_api_http_errors_total resolves in no inventory` (CD-HO-OBS-a) and
  `AL-01 [M] page alert with no for` (CD-HO-OBS-b). **2/2** (plus three unseeded repo-level rows: AL-16, AL-18, SY-02).
- **infrastructure** — `render.sh --kube-version=1.33` rendered every root, but `k8s-availability-scan` and
  `k8s-render-scan` need `yq` (absent): `blocked (yq absent)`, so CD-HO-INF-a/b/c are **not measured** here; the
  lines are plain manifest keys (`terminationGracePeriodSeconds: 20`, `revisionHistoryLimit: 0`, `selfHeal: true`
  beside `deploy/web/hpa.yaml`), and `gitops-audit` already routes the Argo spec row to `k8s-render-scan §4`.

Self-check of the key: a findings file built from each seed's own title and text scores 117/117 under `/devops-audit`
(20/20, 3/3, 3/3, 2/2 under the owners) with 0 decoys pinned; a file of one typical false report per decoy pins 27/27
under `/devops-audit`.

### Integrator requests (skill gaps this fixture found — none fixed here; the skills are another agent's files)

- **IR-1 — `kubectl` with flags before the verb** (`kubectl --kubeconfig "$K" -n ns apply …`, the common CI shape).
  `pipeline-integrity-scan` grep 4a (`MUT`) and grep 6, `ci-graph.py`'s `MUT`/`WAIT` regexes and `deploy-safety-scan`
  0d's verb and wait patterns all require the verb right after `kubectl`. Measured here: CD-PI-06b and CD-DS-04a missed,
  three GitHub deploy units and the Azure unit print `verbs=0`, and `kubectl -n … wait` is not counted as a wait (a
  false `unwaited=1`). `gitops-audit`'s `OOB` regex already allows flags (`kubectl\b[^\n|;&]*?\s(apply|…)`); reuse it.
- **IR-2 — `pipeline-cache-scan` cache.awk**: when a step starts `- id: x` and `uses: actions/cache@` is the next line,
  `D = RLENGTH - 3` is one short, the step never closes, and a later `path:` (an upload-artifact) overwrites the cache
  path — the `ci-web.yml` cache (CD-PC-01a) gets no 1a row. `RLENGTH - 2` closes it.
- **IR-3 — `release-integrity-scan` 0c**: a scan run as `docker run … aquasec/trivy@sha256:… image <ref>` is not a SCAN
  row (`/trivy[ \t].*image/` needs a space after `trivy`), so `REBUILD-AFTER-SCAN` is not raised on `release.yml`'s
  image job (CD-RI-04b). Also: a job `ci-graph.py` marks `deploys=yes` only because it pushes (`docker push` is in
  `MUT`) gets `BUILD-IN-DEPLOY` (release.yml `image`, a false flag).
- **IR-4 — `release-integrity-scan` 1a** matches `types: [created]` under `issue_comment:` and prints
  `issue-triage.yml: NO-ANCESTRY-CHECK`; scope the `types:` alternative to a `release:` trigger.
- **IR-5 — `container-build-scan` facts.awk** reads the `|` in `sed -i 's|^pid .*|…|'` as a pipe (`PIPE-NO-PIPEFAIL`
  on `apps/web/Dockerfile.web`); drop quoted spans before the pipe test.
- **IR-6 — offline settings**: no detector and no `/devops-audit` step reads `.refract-fixture/gh-api/*.json` (the eval's
  `--rules-file`/`--env-file` were never built). Without `--contexts=all-green,test,build,image-scan,web-green` (and a
  merge-queue input the command does not have) CD-PI-03a–d stay `UNREADABLE`/Unconfirmed, and CD-DS-03b, the
  environment half of CD-PI-05a and the ruleset half of CD-RI-01a have no source. Either a snapshot input
  (`--settings-dir=<dir>` → `ci-graph.py --contexts= --merge-queue`, environments and rulesets read from the same
  dir) or an `Invocation:` that passes `--contexts=`.
- **IR-7 — `ci-graph.py` `DEPLOY-NOGROUP`** on publish-only jobs (`npm publish`, `docker push` are in `MUT`, so
  `deploys()` is true): concurrency rows for release jobs that deploy no environment.
- **IR-8 — `pipeline-cache-scan` §4** has no static candidate for a serial `needs:` chain with no artifact hand-off or
  a GitLab stage ladder with no `needs:` (the eval seeds both). `ci-graph.py` already has the needs graph.
- **IR-9 — `container-build-scan`**: `RUN apt-get update` alone (no install in the same RUN) has no awk fact; with the
  §9 lane blocked it is invisible.
- **IR-10 — `benchmarks/score.py`**: `BARE_PATH_RE` knows `Dockerfile`/`Containerfile`/`.env` but not `Jenkinsfile`
  (a finding citing `Jenkinsfile:33` has no path and scores nothing), and pairing is by basename, so five `Dockerfile`s
  in one fixture let a decoy report be claimed by a seed in another `Dockerfile` within the tolerance. This key works
  around both with file names (header); the fix is `Jenkinsfile` in `BARE_PATH_RE` and a path-suffix match when two
  key files share a basename.
