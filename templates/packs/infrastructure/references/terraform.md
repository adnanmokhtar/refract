# Terraform / OpenTofu reference

> **Tool**: Terraform (1.16.5 current on 2026-10-10, per releases.hashicorp.com / checkpoint-api.hashicorp.com) OR OpenTofu (1.13.1 current on 2026-10-10, per github.com/opentofu/opentofu/releases; 1.13.x supported to 2027-08-01). Provider majors move independently of the CLI — the AWS provider was on 6.x in August 2026. **Do not pin from this line: read `required_version` / `required_providers` in the repo and the provider's release page.**
> **Official docs**: https://developer.hashicorp.com/terraform/docs • https://opentofu.org/docs/
> **Version-specific gotchas**: HashiCorp re-licensed Terraform from MPL → BUSL in v1.6 (Aug 2023) — OpenTofu is the open-source fork. `for_each` over `count` for stable resource addressing; `moved` blocks for refactors without state surgery; `import` blocks (1.5+) for declarative imports; `removed` blocks (1.7+) drop a resource from state while LEAVING the infrastructure; `lifecycle { destroy = false }` (Terraform 1.16, OpenTofu 1.12) forgets instead of destroying — and the two engines differ on it (Refactoring below). OpenTofu adds state encryption (1.7+) and `lifecycle { enabled }` (1.11). On the S3 backend, DynamoDB-based locking is deprecated in favour of `use_lockfile` — see Principles.
> **Substitution markers**: Replace cloud / region / module-source paths with the project's actual values.

Infra-as-code. Declarative. Reviewable. Versioned.

## Structure

```
infra/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── versions.tf     # required_version + required_providers (pinned)
│   │   ├── terraform.tfvars
│   │   ├── .terraform.lock.hcl   # COMMIT THIS — provider hashes
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

- **Remote state** mandatory for teams. On the S3 backend, lock with **`use_lockfile = true`** (S3-native conditional writes); HashiCorp's backend docs state that *"DynamoDB-based locking is deprecated and will be removed in a future minor version"* (https://developer.hashicorp.com/terraform/language/backend/s3). Terraform Cloud / Spacelift / GCS locking are equivalent alternatives.

```hcl
terraform {
  required_version = "~> 1.16"   # read the repo's own constraint; 1.16.5 / Tofu 1.13.1 were current on 2026-10-10
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }   # read the provider's own release page
  }
  backend "s3" {
    bucket       = "<tf-state-bucket>"
    key          = "prod/terraform.tfstate"
    region       = "<region>"
    encrypt      = true
    use_lockfile = true      # S3-native locking; dynamodb_table is deprecated
  }
}
```

- **Pin and commit the lock file.** `.terraform.lock.hcl` records provider versions AND hashes; committing it is what makes "the plan I reviewed is the plan that applies" true. It is the IaC analogue of `npm ci` / `--frozen-lockfile`, which this repo already requires of application code.
- **State per env**. Never mix dev / staging / prod state.
- **Modules** for reusable blocks. Versioned in git or registry.
- **Data sources** to reference existing resources (don't manage what you didn't create).
- **Immutability**: changes = new resources (blue/green) rather than in-place where risky.

## Workflow

```
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan -detailed-exitcode   # 0 = no changes · 2 = changes · 1 = error
terraform show -json tfplan > tfplan.json       # the reviewable artifact
terraform apply tfplan                          # apply exactly what was reviewed
```

`-detailed-exitcode` is what lets CI assert "no drift" mechanically instead of grepping prose.

CI integrations:
- Plan on PR → diff posted as comment.
- Apply on merge to main (with manual approval for prod).
- Atlantis / Spacelift / Terraform Cloud automate this.

## Variables + secrets

- Variables in `*.tfvars` (per env) — committable if non-secret.
- Secrets in a secrets backend (Vault, AWS SM), referenced via data source.
- NEVER commit secrets to `.tfvars`.
- `sensitive = true` hides a value from CLI output only: it is still in state and plan JSON. Where the engine minor and the locked provider version offer them, prefer **ephemeral resources** and **write-only `*_wo` arguments** (never persisted to state), or the provider's managed-secret switch (e.g. `manage_master_user_password`). OpenTofu can also encrypt state at rest (`encryption {}` block, 1.7+).
- `terraform validate` does not catch an output of a provider-sensitive attribute; only `plan`/`test` fail on it (precedents/infrastructure.md § 58).

## Drift

- Run `terraform plan -detailed-exitcode` on schedule in CI; exit 2 = drift.
- Drift (someone changed state outside TF) → fix by editing TF + applying, not by importing.

## Workspace vs separate state

- **Workspaces**: same TF code, different state per workspace. Good for parallel feature envs.
- **Separate state**: different `.tf` + different backend per env. Safer isolation for prod.

Rule: prod in its own state; dev/staging can share workspaces.

## Refactoring without state surgery

- **`moved`** — a resource's Terraform ADDRESS changed. State follows; nothing is destroyed.
- **`import`** (1.5+) — bring an existing real resource under management, declaratively, reviewable in the plan.
- **`removed`** (1.7+) — drop a resource from state and KEEP the real infrastructure. Reads like a removal in the plan and is not a destroy. Written by mistake where a destroy was meant, it leaves an unmanaged, still-billing resource.

- **`lifecycle { destroy = false }`** (Terraform 1.16, OpenTofu 1.12) — a destroy of the resource becomes a forget: the object stays, still billed, no longer managed. Two traps, measured 2026-10-10 on Terraform 1.16.5 and OpenTofu 1.13.1: an attribute that forces replacement plans `["forget","create"]` on both engines, so the store is orphaned and a new **empty** one is created; and deleting the resource block that carried `destroy = false` plans a real `delete` on Terraform but a `forget` on OpenTofu. Read the engine before relying on it.
- **OpenTofu `lifecycle { enabled = false }`** (1.11) — conditionally drops a resource; written where a destroy was meant it is the same orphan as `removed`.

The first three change what a plan LOOKS like without changing what it does to data; the last two can. `tf-plan-review` reads the plan's `actions` and `action_reason` (via `iac-lifecycle-scan`'s `plan-joins.jq`) before escalating — or approving — a diff.

## Module design

- Smallest useful unit. A "web-app" module pulling in "rds", "redis", "eks-service" is a composition.
- Input variables + outputs — no hidden side effects.
- Versioned: `source = "git::https://github.com/org/tf-modules.git//vpc?ref=v1.2.0"`.

## Cost control

- Tag every resource with `Owner`, `Env`, `Project`, `CostCenter`.
- Cost Explorer / Infracost (CI integration) flags expensive changes on PR.

## Destroy safety

- `terraform destroy` on prod state = disaster. Gate behind CI + manual approval + confirmation.
- Prevention: `lifecycle { prevent_destroy = true }` on critical resources (a forced replacement then fails `plan` with "Instance cannot be destroyed"), plus the provider's own guard (`deletion_protection = true` — assert `== true`; unset reads null) and a final snapshot. `destroy = false` is not a guard against a forced replacement (Refactoring above).
- Terraform 1.14+ ignores `prevent_destroy` during `terraform test` cleanup, so a test run never proves the guard.

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
