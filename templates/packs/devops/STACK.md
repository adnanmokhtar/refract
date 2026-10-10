# DevOps pack — stack assumption

This pack's rules, agents, skills, and patterns assume:

- **A container build toolchain** (Docker / BuildKit / Podman) producing OCI images
- **A CI platform** (GitHub Actions / GitLab CI / Buildkite / CircleCI / Jenkins) with reusable workflows + branch protection
- **A container orchestrator** OR PaaS in prod (Kubernetes / Docker Swarm / ECS / Fly.io / Render / Cloud Run)
- **A secret manager** (AWS Secrets Manager / Vault / GCP Secret Manager / Doppler / 1Password CLI)
- **An IaC tool** for cloud resources (Terraform / OpenTofu / Pulumi / CDK / Crossplane)
- **A registry** with image-pinning support (digest pinning, e.g., `image@sha256:...`)
- **A scanner** in CI (`trivy` / `grype` / `snyk container`) blocking on critical CVEs

## Inline examples in this pack

Wherever this pack's files show concrete syntax, examples lean **GitHub Actions + Docker + Kubernetes** for illustration. Substitute per stack:

| GitHub Actions + Docker + K8s (illustrated) | GitLab CI + Docker | Buildkite + ECS | Jenkins + Swarm | Cloud-native PaaS | Substitution source |
|---|---|---|---|---|---|
| `.github/workflows/ci.yml` | `.gitlab-ci.yml` | `.buildkite/pipeline.yml` | `Jenkinsfile` | provider config (`fly.toml` / `render.yaml`) | CI definition |
| `actions/cache` | GitLab cache: keys | Buildkite plugin cache | Jenkins workspace stash | provider-managed | dependency cache |
| GitHub `secrets.X` | GitLab CI variables (masked) | Buildkite Vault plugin | Jenkins Credentials | provider secrets | secret reference |
| `actions/checkout@vN` (pin SHA) | trusted images | Buildkite plugin SHA pin | Jenkins shared lib SHA | provider-managed | step-pinning convention |
| `kubectl apply` via Argo CD | same via Flux / Argo | `aws ecs deploy` via CodeDeploy | `docker stack deploy` | provider deploy | apply / deploy step |
| `helm upgrade --install` | same | task-def + service update | compose file | provider-managed | release tool |
| `hadolint` / `trivy` / `gitleaks` | same | same | same | same | lint + scan tool |

## Boundaries — what other packs own, and what devops keeps

A CI or container class goes to the pack whose **claim** it is. Devops owns delivery integrity: with
no attacker involved, the pipeline's own semantics let a red build merge, ship what was not tested,
cancel or race a mutating deploy, drop in-flight work at shutdown, or leave no rollback target. One
finding per `<file:line>`, credited to the owner with the more severe claim, the other listed as
corroboration. When the owner pack is not installed, the devops detector prints the row tagged
`<class> (owner pack <x> not installed)` at its own severity, never graded as the owner would
(`precedents/devops.md` § 1–§ 3). Class-level owners are in `ownership.json`.

| Pack | Owns (devops does not grade these) | Devops keeps, or supplies |
|---|---|---|
| **security** | Every attacker path in CI (`ci-security-scan` §1–§9): privileged triggers with untrusted code, expression injection, AI agents fed untrusted text, pinning × privilege, cache poisoning, credentials and OIDC width, bot-passable gates, runners. In images and compose (`iac-scan` §1–§3): a root final stage, secret build args and files, `curl \| sh`, TLS verification off, compose ports / privilege / socket / literal passwords, plaintext `kind: Secret`, deploy by mutable tag; values → `secret-scan` | The job graph (`ci-graph.py --check=pin-priv`) and the stage-chain user awk security grades with; signing, attestation and verify breadth stay devops' (`release-integrity-scan` §5, `release-security`) |
| **testing** | A masked **test** job (`continue-on-error`, `\|\| true`, a pipe with no pipefail, `--passWithNoTests`), zero tests, test retries (`suite-execution-scan` §4, §6) | The required-check join (`ci-graph.py --required` / `--contexts=`) those rows read for severity |
| **infrastructure** | The manifest: resources and QoS, probes present and timed, `preStop` and `terminationGracePeriodSeconds` (`THR-SHUTDOWN-GRACE`), rollout shape, PDB, HPA, `revisionHistoryLimit`, registry tag mutability in IaC, admission enforcement of signatures, the GitOps controller spec (prune, waves, `selfHeal` × HPA, `ignoreDifferences` — `k8s-render-scan` §4); the shared render | Migration topology, deploy concurrency, environments and the rollout gate (`deploy-safety-scan` §1–§4), the code side of the shutdown chain (§5, which hands infrastructure the drain number), PID 1 in the image (`container-build-scan` §2), out-of-band apply and live drift (`gitops-audit`) |
| **observability** | Readiness that lies (HC-01), telemetry flush on shutdown, the content of a rules gate, every selector a canary query names (`rule-inventory.py --check=selectors`) | The CI-level mask on the rules-gate job (`pipeline-integrity-scan` §1); the canary gate itself (`progressive-delivery` §5) |
| **database** | Whether a migration is safe to run (`migration-safety` §4, §8: contract statements, locks a statement takes) and the rehearsal (`migration-rehearsal`) | Who runs it, how many times, under which runner lock, in which order relative to the rollout (`deploy-safety-scan` §1) |
| code-quality · frontend · performance | A masked lint or typecheck job (`suppression-scan`); a neutered a11y gate (`a11y-scan` §7); a liveness handler that checks a shared dependency (`request-path-scan` §15) | The required-check join, as for testing |

## Where stack-specific names live

- The project's `_extracted-idioms.md` — actual CI provider, container registry, deploy command, secret-manager binding, IaC tool.
- The project's `_extracted-codebase.md § DevOps` — Dockerfile location, manifest directory (k8s / compose / IaC module path), branch-protection rules.
- `infrastructure/references/<tool>.md` — Docker / Swarm / Kubernetes / Terraform specifics live in the infrastructure pack's references (not duplicated here).

Universal hard rules (zero-downtime deploys, one-command rollback, backward-compatible migrations, no `:latest` in prod, no secrets in git) apply across all CI / orchestrator combos.
