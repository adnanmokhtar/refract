---
description: Provision a new environment tier (dev / staging / prod / DR). IaC-driven; produces resources at right size + IAM scoped + observability wired + cost-tagged from day 1.
---

# /provision-tier

A new environment tier is high-leverage but easy to ship wrong: over-provisioned, IAM too broad, no observability, untagged for cost. This command produces a tier that's correct from day 1.

## The Premise (read this first, internalize, do not deviate)

**Existing tiers are the truth. New tier mirrors closest sibling tier (dev/staging/prod) with explicit per-resource overrides only.** If `infra/terraform/tiers/staging/` exists, it IS the convention for any new staging-class tier — module set, module call order, tag schema, naming pattern, IAM scoping idiom, observability wiring, alert routing. Do NOT compose a fresh tier from cloud-vendor reference architectures; do NOT copy prod into a new dev tier; do NOT mix idioms across siblings.

**The closure verb is `mirror-sibling-tier-with-overrides`.** Before generating, the agent MUST:
1. List `infra/terraform/tiers/*/` (or pulumi/cdk equivalent) and pick the closest sibling by tier purpose (new prod region → existing prod; new dev → existing dev; new staging → existing staging; new DR → existing prod with HA).
2. Read the sibling's `main.tf` (or root) end-to-end and record: module set called, module argument shape, tag schema (keys + value source), CIDR allocation pattern, instance-class progression by tier, multi-AZ flags by tier, backup retention by tier, IAM `ci_role` shape, observability `send_to` target, alert routing target.
3. Generate the new tier with the SAME module set and SAME argument shape; per-resource overrides MUST be explicit (`instance_class = "db.t4g.small"  # diverges from staging: tier is dev, smaller`) — silent value changes are forbidden.

**Mechanical halt — sibling-resource-shape parity (mandatory before `terraform plan`):**
1. Untagged-resources halt: any module call missing `tags = local.tags` → halt. Any resource block creating an AWS/GCP/Azure resource without tags propagation → halt.
2. Missing-labels halt: `local.tags` MUST contain every key the sibling tier sets (`Environment`, `ManagedBy`, `CostCenter`, `Owner`, plus any sibling-specific) → halt on any missing key.
3. Missing-module halt: every module the sibling tier calls MUST appear in the new tier OR carry an explicit `# omitted: <reason>` comment. Silent omission of `observability` / `alerts` / `secrets` / `iam` → halt.
4. Missing-probes-equivalent halt: every stateful resource (RDS, ElastiCache, etc.) MUST have a backup config + at least one alert wired (the infra equivalent of liveness/readiness). Missing → halt.
5. Missing-limits halt: every compute module call MUST set `min_size` AND `max_size` (or vendor equivalent); unbounded → halt.
6. IAM-scope halt: any `allowed_actions` containing `*:*` outside an explicit `break-glass` role → halt.
7. Secret-inline halt: any literal credential / API key in `.tf` files → halt; force `secrets-manager` module path.
8. OIDC halt: any CI integration creating long-lived `aws_iam_access_key` resources → halt.

If no sibling tier exists, halt and ask the user to point at a gold-standard tier OR confirm this tier is the new gold standard (then the IaC is reviewed by `infra-architect` + `tf-plan-review` before apply).

**The agent does NOT:**
- Compose a tier from scratch when a sibling exists in the same repo.
- Copy prod values into a non-prod tier silently — every value crossing tier boundary is an explicit override with a comment.
- Skip a module the sibling has — observability and alerts and backups are not optional.

## Phases applied

All 7.

## When to use

- New environment (staging / prod / DR).
- New region.
- Per-customer dedicated tenant (large enterprise SaaS contract).
- Disaster recovery setup.

## Phase 1 — Understand

- Tier purpose: dev / staging / prod / DR / per-customer / per-region.
- Cloud + region(s).
- Expected scale: requests/sec, data volume, peak users.
- Compliance: PCI / HIPAA / FedRAMP / GDPR boundaries.
- Multi-tenancy: isolated per customer or shared?
- Existing IaC pattern (Terraform / Pulumi / CloudFormation / CDK).

## Phase 2 — Organize

A tier provision touches:
1. **Network** — VPC, subnets, NAT, peering, transit.
2. **Compute** — EC2 / EKS / ECS / Lambda capacity.
3. **Data** — RDS, ElastiCache, S3 buckets, queues.
4. **IAM** — roles, policies, OIDC for CI.
5. **Secrets** — Secrets Manager / KMS / Vault.
6. **Observability** — CloudWatch / Datadog connection, log routing, metrics scrape, alerts wired.
7. **DNS + TLS** — Route53 / ACM certs / health checks.
8. **CDN + WAF** — CloudFront / WAF rules.
9. **Backup + DR** — automated backups, RPO/RTO targets, restore drill.
10. **Cost** — budgets, anomaly alerts, tags from day 1.

## Phase 3 — Retrieve

- Existing IaC modules: `infra/terraform/modules/<name>/`.
- `ai/architecture.md` — current topology + module boundaries.
- Compliance constraints in `ai/decisions/`.
- Vendor-specific guidance: AWS Well-Architected, GCP best practices.

## Phase 4 — Generate (the IaC)

For Terraform (illustrative):

```hcl
# tiers/staging/main.tf

module "network" {
  source = "../../modules/network"
  cidr_block = "10.10.0.0/16"
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
  tags = local.tags
}

module "kubernetes" {
  source = "../../modules/eks"
  cluster_name = "staging"
  vpc_id = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
  node_groups = {
    default = {
      desired_size = 3
      min_size = 2
      max_size = 10
      instance_types = ["m6i.large"]   # right-sized for staging; not over-provisioned
    }
  }
  tags = local.tags
}

module "rds" {
  source = "../../modules/rds"
  identifier = "staging-app"
  instance_class = "db.t4g.medium"  # smaller than prod's m6i.large
  multi_az = false                   # staging doesn't need HA; saves cost
  backup_retention_days = 7
  tags = local.tags
}

module "secrets" {
  source = "../../modules/secrets-manager"
  secrets = ["db-password", "api-keys/stripe", "api-keys/sendgrid"]
  rotation_lambda_arn = module.rotation.lambda_arn
  tags = local.tags
}

module "iam" {
  source = "../../modules/iam"
  oidc_provider = "https://token.actions.githubusercontent.com"
  ci_role = {
    name = "ci-staging-deployer"
    allowed_actions = ["eks:DescribeCluster", "ecr:GetAuthorizationToken", "s3:GetObject"]
    allowed_resources = ["arn:aws:eks:us-east-1:${data.aws_caller_identity.current.account_id}:cluster/staging"]
  }
  tags = local.tags
}

module "observability" {
  source = "../../modules/observability"
  cluster_name = "staging"
  send_to = "datadog"  # or "cloudwatch", "prometheus"
  tags = local.tags
}

module "alerts" {
  source = "../../modules/alerts"
  pagerduty_integration = "staging-low-priority"  # tickets, not pages
  slo_burn_rate_targets = local.slo_targets_staging
  tags = local.tags
}

locals {
  tags = {
    Environment = "staging"
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
    Owner       = "platform-team"
  }
}
```

Manifest checklist (every tier MUST have):

- [ ] VPC with private + public subnets.
- [ ] NAT for private-subnet egress (cost-aware: NAT instance for dev; NAT Gateway HA for prod).
- [ ] IAM scoped to least-privilege (no `*:*` outside emergency break-glass).
- [ ] Secrets in Secrets Manager / Vault, not env vars in IaC.
- [ ] OIDC federation for CI; no long-lived access keys.
- [ ] Logs shipping to centralized backend.
- [ ] Metrics shipping to centralized backend.
- [ ] At least one heartbeat alert per service.
- [ ] Cost tags on EVERY resource (Environment, ManagedBy, CostCenter, Owner).
- [ ] Backup automation for stateful resources.
- [ ] DNS + TLS automated (no manual cert renewals).
- [ ] WAF + CDN for public ingress.
- [ ] Budgets + anomaly detection.

## Phase 5 — Update

- `ai/architecture.md` — note new tier in topology.
- `ai/runbooks/tier-<name>.md` — runbook: how to deploy, common ops, escalation.
- `ai/decisions/<NNNN>-tier-<name>.md` — ADR if non-default config.
- `infra/terraform/tiers/<name>/` — IaC files.
- CI/CD pipelines — tier deploy job added.
- Observability dashboards — tier-scoped variants created.

## Phase 6 — Validate

- `terraform plan` clean.
- `terraform apply` succeeds.
- Smoke deploy a hello-world service → reaches the tier through the full stack (DNS → CDN → ALB → EKS → app → DB).
- Logs visible in centralized backend.
- Metrics visible in centralized backend.
- One alert tested (deliberately trigger; verify it fires + routes correctly).
- IAM Access Analyzer + IAM Access Advisor clean.
- Cost tags audit: 100% of resources tagged.
- Budget + anomaly alarms configured.

## Phase 7 — Improve

- Reusable patterns extracted as new modules.
- Tier-divergent design choices ADR'd.
- Runbook tested by a NON-author (do they understand it?).

## Output format

```
## /provision-tier complete

Tier: <name>
Cloud + region: <provider> / <region>
Resources: <count> across <module-count> modules
IaC: <terraform/cf/pulumi> in <path>
Compliance: <if applicable>

Validations:
- terraform apply: clean
- smoke deploy: passed
- alert test: passed
- IAM Access Analyzer: clean
- cost tagging: 100%
- budget alerts: configured

Files written:
- infra/terraform/tiers/<name>/
- ai/runbooks/tier-<name>.md
- ai/architecture.md (updated)
```

## Hard rules

- **Tagged at creation, never retro-tagged.** Tagging is required at apply, not after.
- **Secrets in a manager, never in IaC.** Even encrypted-state — secrets manager is the source of truth.
- **OIDC for CI; never long-lived IAM keys.**
- **Right-sized for the tier, not copy-pasted from prod.** Dev / staging instances are smaller.
- **Observability + at-least-one alert wired before traffic.** Operating blind = inviting an outage.
- **Backups configured for stateful resources before traffic.**

## Failure modes

- Copy-pasted prod IaC for staging → 10× over-provisioned.
- Permissions copy-pasted → too broad for the tier.
- Forgot one tag → cost-attribution gap.
- TLS cert expires in N days; no auto-renewal → outage.
- VPC CIDR overlaps with another tier → peering breaks.
- Backup configured but never restored → silent failure.
- Observability tooling configured but log volume hits free-tier ceiling silently.

## Related

- `audit-iam` — verify the IAM scoping after apply.
- `cost-audit` — verify the cost surface after first month.
- `tf-plan-review` skill — pre-apply review.
- `multi-region` pattern — when this tier needs DR / multi-region.
- `@deployment-engineer` agent — deploys to this tier.
