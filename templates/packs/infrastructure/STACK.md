# Infrastructure pack — stack assumption

This pack's rules, agents, skills, and patterns assume:

- **A container runtime** in production (containerd / Docker / CRI-O)
- **An orchestrator** chosen deliberately by team scale (Kubernetes / Docker Swarm / ECS / Nomad / Fly Machines / Cloud Run)
- **An IaC tool** (Terraform / OpenTofu / Pulumi / CDK / Crossplane) reviewed in PRs
- **A secret manager** (External Secrets Operator + AWS SM / Vault / GCP SM / Sealed Secrets)
- **A managed datastore** for stateful workloads (RDS / Cloud SQL / Aurora / Atlas / managed Redis), NOT container-local volumes
- **An image scanner** in CI (`trivy` / `grype`) blocking on critical CVEs
- **A registry** with digest-pinning enforcement

## Inline examples in this pack

Wherever this pack's files show concrete manifests, examples lean **Kubernetes + Terraform + AWS** for illustration. Substitute per platform:

| K8s + Terraform + AWS (illustrated) | ECS + CDK | Docker Swarm + Compose | Nomad + Consul | Cloud Run / Fly Machines | Substitution source |
|---|---|---|---|---|---|
| `Deployment` / `Service` / `Ingress` | `TaskDefinition` + `Service` + `ALB` | `docker-compose.yml` `services:` | Nomad `job` HCL | provider-native deploy | service deployment |
| `livenessProbe` / `readinessProbe` / `startupProbe` | ELB target-group health-check | Compose `healthcheck:` | Nomad `check` block | provider-native probes | health checks |
| `HorizontalPodAutoscaler` | ECS target-tracking policy | `docker service scale` (manual) | Nomad autoscaler | provider auto-scaling | autoscaling |
| `NetworkPolicy` (default-deny) | Security Group rules | overlay network isolation | Consul service intentions | provider firewall | network policy |
| `ConfigMap` + `Secret` (KMS-backed) | SSM Parameter Store / Secrets Manager | Docker secrets (`/run/secrets/`) | Vault integration | provider secrets API | config + secrets |
| `PersistentVolume` (managed CSI) | EBS / EFS via task definition | named volume on a labeled node | Nomad CSI plugin | provider persistent disk | persistence |
| Argo CD / Flux GitOps | CDK deploy via pipeline | `docker stack deploy` from CI | Nomad pack deploy | provider deploy command | release flow |
| `tfsec` / `checkov` / `kube-linter` | `cfn_nag` / `cdk-nag` | Compose linter | Nomad validate | provider validators | IaC lint |

## Where stack-specific names live

- The project's `_extracted-idioms.md` — actual orchestrator, IaC tool, registry, secret manager, ingress controller, autoscaler.
- The project's `_extracted-codebase.md § Infrastructure` — manifest directory, environment-tier separation, deployment pipeline path.
- `references/<tool>.md` — Docker / Docker Swarm / Kubernetes / Terraform per-tool conventions live here in this pack's references.

Universal hard rules (digest-pinned images, non-root containers, healthchecks + resource requests/limits, no secrets in git, tested backups) apply across all orchestrators.
