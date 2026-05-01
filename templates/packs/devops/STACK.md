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

## Where stack-specific names live

- The project's `_extracted-idioms.md` — actual CI provider, container registry, deploy command, secret-manager binding, IaC tool.
- The project's `_extracted-codebase.md § DevOps` — Dockerfile location, manifest directory (k8s / compose / IaC module path), branch-protection rules.
- `infrastructure/references/<tool>.md` — Docker / Swarm / Kubernetes / Terraform specifics live in the infrastructure pack's references (not duplicated here).

Universal hard rules (zero-downtime deploys, one-command rollback, backward-compatible migrations, no `:latest` in prod, no secrets in git) apply across all CI / orchestrator combos.
