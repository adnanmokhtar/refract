# Terraform / OpenTofu reference

Infra-as-code. Declarative. Reviewable. Versioned.

## Structure

```
infra/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf      # remote state config
│   ├── staging/
│   └── prod/
├── modules/
│   ├── vpc/
│   ├── eks-cluster/
│   ├── rds-postgres/
│   └── app-service/
└── shared/
    ├── variables.tf
    └── outputs.tf
```

## Principles

- **Remote state** mandatory for teams (S3 + DynamoDB lock / Terraform Cloud / Spacelift).
- **State per env**. Never mix dev / staging / prod state.
- **Modules** for reusable blocks. Versioned in git or registry.
- **Data sources** to reference existing resources (don't manage what you didn't create).
- **Immutability**: changes = new resources (blue/green) rather than in-place where risky.

## Workflow

```
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan       # review the plan
terraform apply tfplan           # apply exactly what was reviewed
```

CI integrations:
- Plan on PR → diff posted as comment.
- Apply on merge to main (with manual approval for prod).
- Atlantis / Spacelift / Terraform Cloud automate this.

## Variables + secrets

- Variables in `*.tfvars` (per env) — committable if non-secret.
- Secrets in a secrets backend (Vault, AWS SM), referenced via data source.
- NEVER commit secrets to `.tfvars`.

## Drift

- Run `terraform plan` on schedule in CI.
- Drift (someone changed state outside TF) → fix by editing TF + applying, not by importing.

## Workspace vs separate state

- **Workspaces**: same TF code, different state per workspace. Good for parallel feature envs.
- **Separate state**: different `.tf` + different backend per env. Safer isolation for prod.

Rule: prod in its own state; dev/staging can share workspaces.

## Module design

- Smallest useful unit. A "web-app" module pulling in "rds", "redis", "eks-service" is a composition.
- Input variables + outputs — no hidden side effects.
- Versioned: `source = "git::https://github.com/org/tf-modules.git//vpc?ref=v1.2.0"`.

## Cost control

- Tag every resource with `Owner`, `Env`, `Project`, `CostCenter`.
- Cost Explorer / Infracost (CI integration) flags expensive changes on PR.

## Destroy safety

- `terraform destroy` on prod state = disaster. Gate behind CI + manual approval + confirmation.
- Prevention: `lifecycle { prevent_destroy = true }` on critical resources.

## Alternative

- **Pulumi** — infra as real code (TS / Python / Go). Better for dynamic logic.
- **CDK (AWS)** — AWS-specific, generates CloudFormation.
- **Crossplane** — K8s-native infra management.

## Forbidden

- Editing cloud resources via console while managed by TF (drift).
- Secrets in `.tfvars` / state files.
- Single state file across all envs (blast radius too big).
- Missing tags (cost / ownership / compliance unknowable).
- `terraform apply` without a reviewed plan.
- Force-unlocking state without confirming no one else is applying.
