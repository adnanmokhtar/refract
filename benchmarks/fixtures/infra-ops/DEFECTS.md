# Seeded defects — `infra-ops`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: `Larder` — a delivery platform's infrastructure: Terraform 1.16 roots and modules (aws, google, cloudflare) with an OpenTofu root, CDK, Pulumi and CloudFormation; Kustomize base + 3 overlays, a Helm chart, Argo CD, KEDA; nginx and Caddy edges; SAM, Lambda and Cloud Run; cert-manager and zone files; CNPG, zalando, Velero and pgBackRest.
State, pinning, lifecycle and deletion safety, data durability and DR, serverless timing, IaC cost candidates, the
rendered Kubernetes (Helm, Kustomize, GitOps spec, availability, wiring, removed APIs), edge proxies, DNS/TLS lifecycle and
network correctness — seeded across six roots, plus decoys: correct siblings that look like a seeded defect and must NOT
be reported.

Invocation: /infra-audit --whole-repo
Invocation[/security-audit]: /security-audit
Stage with: --git — `/infra-audit` reads the history for its context map (and `k8s-render-scan` § 5 diffs the base
render), and a whole-repo run on a copy with no base branch says so with the flag instead of leaving the diff lookup to fail.

Eval source: Track A batch 4, item 31 (`eval-batch4-infrastructure.md` § 3.6). Classes follow the owning skills' own
§ numbering (`templates/packs/infrastructure/skills/*/SKILL.md`). Roots:

| Root | Stack | Holds |
|---|---|---|
| `iac/` | Terraform 1.16 (`envs/{prod,staging,shared,analytics,ci-ephemeral}`, `modules/db`), OpenTofu (`tofu/search-index`), CDK TS, Pulumi TS, CloudFormation; a committed offline plan `iac/plans/prod.plan.json` | state, pinning, lifecycle, deletion, the RDS/DynamoDB/S3/Cloud SQL stores, cost, network (VPC, NACLs, peering, VPN) |
| `k8s/` | Kustomize `base/` + `overlays/{prod,dev,trial-single-node}`, Helm chart `chart/` (values + values-prod), Argo CD Applications, KEDA, raw `platform/` manifests, `ops/runbooks/platform.md` (the `helm upgrade --install` lines) | render, availability, wiring, API versions, platform components |
| `edge/` | nginx (`nginx-edge`, `partner-gateway`), Caddy (xcaddy build with redis storage and cache plugins), raw edge manifests, the Fastify api and Node storefront the edge fronts, a local compose sandbox | timeout chain, keep-alive, retries, DNS re-resolution, streaming, silent rejection, access logs |
| `serverless/` | Terraform Lambda + SQS + API Gateway with a committed offline plan, a SAM template with two handlers, Cloud Run (Terraform) | queue timing, DLQ, partial batch, concurrency, retry storms |
| `dns/` | Route 53 and Cloudflare records (Terraform), BIND zone files, cert-manager Issuers/Certificates (Kustomize `issuers/`, `base/`, `overlays/{prod,preview}`), a PrometheusRule and a blackbox Probe | CAA, expiry signal, issuer per environment |
| `dr/` | the nightly `pg_dump` CronJob (Kustomize), Velero, CNPG and zalando clusters, pgBackRest and `postgresql.conf`, the backup-bucket Terraform, `docs/objectives.md` (RPO/RTO), restore runbooks with drill logs | backups, PITR, immutability, RPO/RTO arithmetic, operator backups, restore evidence |

Every Kustomize root renders offline with `kustomize build` (no `../` file reference crosses a root; overlays reference
their base directory only). The target Kubernetes minor is **1.36** (`kubernetes_version` in `iac/envs/prod/eks.tf`).
The two plan files are in the `terraform show -json` shape (format 1.2) and were **written by hand** to match the HCL —
no Terraform binary or credential was used; `plan-joins.jq`, `serverless.jq` and `cost.jq` read them as committed
offline plans (the plan lane copies one to `$SCAN/plan.json`). Lock files and image digests are placeholders.

Departures from the eval, stated so a reader can audit them:
- **Six roots, as the task named them:** the eval's `network/` root is folded into `iac/` (the VPC, NACL, peering and VPN
  resources live beside the stores they carry), and `serverless/` is a root of its own. CDK/Pulumi/CFN sit under `iac/`.
- **The ingress controller is Traefik, not ingress-nginx.** Any ingress-nginx install is a true `K-INGRESS-RETIRED`
  finding (retired 2026-03, precedents § 62) that the eval does not seed; Traefik keeps that class out of the key. So
  decoy 3 (Fastify `keepAliveTimeout: 72_000`) sits behind the fixture's own nginx upstream pool (`keepalive_timeout
  60s`), and decoy 18 (SSE with no buffering setting) is the Caddy form of precedent 30 instead of the ingress-nginx form.
- **Decoy 9** ("no CPU limit, ×3 workloads") is three decoy blocks, one per workload, so a false report on any of them is
  pinned: 34 decoy blocks for the eval's 32 decoys.
- **TF-08** is seeded in the committed plan (`module.orders_db` identifier rename; EFS encryption), as the eval asks.

Ownership and scoring. Every row names the detector § that owns it. Two runs, two results rows, each staged in its own
copy. **`/infra-audit --whole-repo`** scores the 126 infrastructure rows and the 12 `IO-SEC-*` rows, which it must list as
routed to security (E4 and D1 run here only as the documented fallbacks, tagged `security-class`); **`/security-audit`**
scores only the 12 `IO-SEC-*` rows (their `command:` names both) and the decoys that name it. A finding one run makes
about a row its command does not target is UNMATCHED, never credited. Lanes the scorer environment is expected to have:
static and render (kustomize, helm, yq, jq) required; plan, kind and live absent — every K-, P- and L-tier oracle prints
`blocked`/`NO-DATA` with its command, so the verdict is at best GO-UNVERIFIED. That is expected, not a failure: score the
findings, not the verdict.

Secrets. None. Passwords come from `var.*` (sensitive), `manage_master_user_password`, or a `secretKeyRef`; the
`random_password` output is a seeded defect about marking, not a value; account ids are `000000000000`.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`, which also fails if a decoy sits close enough to a defect in the
same file for their scoring windows to overlap. If you edit fixture source, re-run it.

## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| IO-ST-01a | `iac/envs/prod/versions.tf:16` | high | `/infra-audit` | state/deprecated-lock-no-encryption |
| IO-ST-01b | `iac/envs/shared/main.tf:2` | high | `/infra-audit` | state/committed-local-state |
| IO-ST-11a | `iac/modules/db/variables.tf:20` | medium | `/infra-audit` | state/secret-variable-not-sensitive |
| IO-ST-11b | `iac/envs/prod/outputs.tf:10` | medium | `/infra-audit` | state/secret-output-not-sensitive |
| IO-ST-03a | `iac/envs/prod/versions.tf:9` | medium | `/infra-audit` | pinning/provider-unconstrained |
| IO-ST-03b | `iac/tofu/search-index/main.tofu:2` | medium | `/infra-audit` | pinning/engine-unpinned |
| IO-ST-04a | `iac/envs/prod/bastion.tf:3` | medium | `/infra-audit` | pinning/module-source-mutable |
| IO-ST-04b | `iac/envs/prod/queues.tf:1` | medium | `/infra-audit` | pinning/registry-module-no-version |
| IO-ST-PHa | `k8s/ops/runbooks/platform.md:29` | medium | `/infra-audit` | pinning/helm-chart-unpinned |
| IO-ST-PHb | `k8s/argo/larder-observability.yaml:11` | medium | `/infra-audit` | pinning/argo-target-revision-wildcard |
| IO-ST-09a | `iac/scripts/oncall-db-apply.sh:6` | medium | `/infra-audit` | plan-discipline/target-in-automation |
| IO-ST-09b | `.github/workflows/terraform.yml:20` | medium | `/infra-audit` | plan-discipline/no-drift-detection |
| IO-LC-05a | `iac/envs/prod/queues.tf:16` | high | `/infra-audit` | identity/count-over-collection |
| IO-LC-05b | `iac/cdk/lib/ledger-archive-stack.ts:13` | high | `/infra-audit` | identity/cdk-logical-id-from-index |
| IO-LC-06a | `iac/envs/prod/cdn.tf:37` | medium | `/infra-audit` | lifecycle/ignore-changes-all |
| IO-LC-06b | `iac/envs/prod/compute.tf:46` | medium | `/infra-audit` | lifecycle/cbd-fixed-name |
| IO-LC-07a | `iac/envs/prod/legacy.tf:2` | medium | `/infra-audit` | refactor/removed-orphan |
| IO-LC-07b | `iac/envs/prod/cache.tf:14` | high | `/infra-audit` | refactor/destroy-false-on-store |
| IO-LC-08a | `iac/plans/prod.plan.json:6` | critical | `/infra-audit` | stateful-replace/rds-identifier |
| IO-LC-08b | `iac/plans/prod.plan.json:61` | critical | `/infra-audit` | stateful-replace/efs-encryption |
| IO-LC-10a | `iac/envs/prod/migrations.tf:7` | medium | `/infra-audit` | imperative/local-exec-migration |
| IO-LC-10b | `iac/envs/prod/release.tf:2` | medium | `/infra-audit` | imperative/external-data |
| IO-LC-13a | `iac/envs/prod/sns.tf:5` | medium | `/infra-audit` | perpetual-diff/timestamp |
| IO-LC-13b | `iac/envs/prod/compute.tf:4` | medium | `/infra-audit` | perpetual-diff/most-recent-ami |
| IO-LC-D1a | `iac/modules/db/variables.tf:25` | high | `/infra-audit` | deletion/final-snapshot-skipped |
| IO-LC-D1b | `iac/envs/prod/reporting.tf:11` | high | `/infra-audit` | deletion/final-snapshot-skipped |
| IO-LC-D2a | `iac/envs/prod/databases.tf:15` | high | `/infra-audit` | deletion/protection-absent |
| IO-LC-D2b | `iac/envs/prod/gcp.tf:6` | high | `/infra-audit` | deletion/protection-off |
| IO-LC-D3a | `iac/envs/prod/storage.tf:4` | high | `/infra-audit` | deletion/force-destroy |
| IO-LC-D3b | `iac/envs/prod/gcp.tf:21` | medium | `/infra-audit` | deletion/force-destroy |
| IO-LC-D4a | `iac/cfn/reporting-replica.yaml:13` | high | `/infra-audit` | deletion/engine-guard-cfn |
| IO-LC-D4b | `iac/pulumi/index.ts:17` | high | `/infra-audit` | deletion/engine-guard-pulumi |
| IO-LC-D5a | `iac/envs/prod/kms.tf:5` | high | `/infra-audit` | deletion/kms-window-short |
| IO-LC-D5b | `iac/envs/prod/ledger.tf:17` | high | `/infra-audit` | deletion/automated-backups-deleted |
| IO-DR-01a | `iac/modules/db/main.tf:13` | high | `/infra-audit` | durability/retention-below-floor |
| IO-DR-01b | `dr/pgbackrest/pgbackrest.conf:11` | high | `/infra-audit` | durability/retention-one-full |
| IO-DR-02a | `iac/envs/prod/databases.tf:36` | medium | `/infra-audit` | durability/pitr-off |
| IO-DR-02b | `iac/envs/prod/gcp.tf:39` | high | `/infra-audit` | durability/pitr-off |
| IO-DR-04a | `iac/envs/prod/promotions.tf:2` | medium | `/infra-audit` | durability/storage-uncapped |
| IO-DR-04b | `iac/envs/prod/ledger.tf:2` | medium | `/infra-audit` | durability/storage-uncapped |
| IO-DR-09a | `iac/envs/prod/storage.tf:30` | medium | `/infra-audit` | durability/bucket-unversioned |
| IO-DR-09b | `iac/envs/prod/storage.tf:47` | medium | `/infra-audit` | durability/bucket-unversioned |
| IO-DR-R3a | `dr/k8s/pg-dump-cronjob.yaml:28` | medium | `/infra-audit` | recoverability/backup-in-app-bucket |
| IO-DR-R3b | `dr/pgbackrest/pgbackrest.conf:4` | medium | `/infra-audit` | recoverability/backup-in-app-bucket |
| IO-DR-R4a | `dr/terraform/backups.tf:21` | medium | `/infra-audit` | recoverability/governance-not-immutable |
| IO-DR-R4b | `iac/envs/prod/backup.tf:23` | medium | `/infra-audit` | recoverability/no-copy-outside-account |
| IO-DR-R1a | `dr/databases/inventory-cluster.yaml:28` | high | `/infra-audit` | objectives/rto-arithmetic |
| IO-DR-R1b | `dr/velero/schedule-media.yaml:8` | high | `/infra-audit` | objectives/rpo-arithmetic |
| IO-DR-R6a | `dr/velero/schedule-search.yaml:11` | high | `/infra-audit` | operator/velero-no-pv-data |
| IO-DR-R6b | `dr/velero/schedule-data.yaml:11` | high | `/infra-audit` | operator/velero-no-pv-data |
| IO-DR-R7a | `dr/postgres/warehouse.postgresql.conf:7` | critical | `/infra-audit` | operator/wal-archive-lies |
| IO-DR-R7b | `dr/postgres/audit.postgresql.conf:7` | critical | `/infra-audit` | operator/wal-archive-lies |
| IO-DR-R8a | `dr/databases/catalog-cluster.yaml:3` | high | `/infra-audit` | operator/cnpg-no-backup |
| IO-DR-R8b | `dr/databases/courier-geo.yaml:15` | high | `/infra-audit` | operator/zalando-no-backup |
| IO-DR-R10a | `dr/runbooks/restore-orders.md:9` | high | `/infra-audit` | restore/drill-stale-weak |
| IO-DR-R10b | `dr/runbooks/restore-media.md:8` | high | `/infra-audit` | restore/drill-in-place |
| IO-DR-R11a | `iac/envs/prod/ledger.tf:25` | critical | `/infra-audit` | destroy/backup-in-destroyable-state |
| IO-DR-R11b | `iac/envs/prod/backup.tf:2` | critical | `/infra-audit` | destroy/backup-in-destroyable-state |
| IO-SL-02a | `serverless/terraform/main.tf:18` | high | `/infra-audit` | serverless/visibility-below-timeout |
| IO-SL-02b | `serverless/sam/template.yaml:17` | high | `/infra-audit` | serverless/visibility-below-timeout |
| IO-SL-03a | `serverless/terraform/main.tf:50` | high | `/infra-audit` | serverless/no-dlq |
| IO-SL-03b | `serverless/sam/template.yaml:41` | high | `/infra-audit` | serverless/no-dlq |
| IO-SL-04a | `serverless/terraform/main.tf:71` | high | `/infra-audit` | serverless/partial-batch-missing |
| IO-SL-04b | `serverless/sam/src/payout-retry.ts:5` | high | `/infra-audit` | serverless/partial-batch-never-returned |
| IO-SL-05a | `serverless/terraform/main.tf:93` | high | `/infra-audit` | serverless/concurrency-unbounded |
| IO-SL-05b | `serverless/cloudrun/main.tf:19` | high | `/infra-audit` | serverless/concurrency-unbounded |
| IO-SL-06a | `serverless/terraform/main.tf:141` | high | `/infra-audit` | serverless/retry-storm |
| IO-SL-06b | `serverless/sam/template.yaml:83` | medium | `/infra-audit` | serverless/retry-storm |
| IO-CO-01a | `iac/envs/staging/main.tf:36` | medium | `/infra-audit` | cost/nat-per-az-nonprod |
| IO-CO-01b | `iac/envs/prod/network.tf:83` | medium | `/infra-audit` | cost/s3-interface-not-gateway |
| IO-CO-04a | `iac/envs/prod/volumes.tf:2` | medium | `/infra-audit` | cost/gp2-default |
| IO-CO-04b | `iac/envs/prod/compute.tf:20` | medium | `/infra-audit` | cost/gp2-explicit |
| IO-CO-08a | `k8s/base/notifier.yaml:35` | medium | `/infra-audit` | cost/scale-ceiling-absent |
| IO-CO-08b | `iac/envs/prod/compute.tf:28` | medium | `/infra-audit` | cost/scale-ceiling-unreviewed |
| IO-K8-PDBa | `k8s/base/dispatch.yaml:64` | high | `/infra-audit` | k8s/pdb-blocks-drain |
| IO-K8-PDBb | `k8s/base/notifier.yaml:51` | high | `/infra-audit` | k8s/pdb-blocks-drain-keda-floor |
| IO-K8-HRa | `k8s/platform/search.yaml:9` | high | `/infra-audit` | k8s/replicas-beside-hpa |
| IO-K8-HRb | `edge/k8s/nginx-edge.yaml:9` | high | `/infra-audit` | k8s/replicas-beside-hpa |
| IO-K8-NRa | `k8s/base/web.yaml:75` | high | `/infra-audit` | k8s/hpa-no-cpu-request |
| IO-K8-NRb | `k8s/base/pricing.yaml:67` | high | `/infra-audit` | k8s/keda-cpu-no-request |
| IO-K8-PSa | `k8s/base/courier-tracker.yaml:38` | low | `/infra-audit` | k8s/probe-same |
| IO-K8-PSb | `k8s/chart/templates/deployment.yaml:36` | low | `/infra-audit` | k8s/probe-same |
| IO-K8-SGa | `k8s/base/checkout.yaml:34` | high | `/infra-audit` | k8s/shutdown-grace |
| IO-K8-SGb | `k8s/base/dispatch.yaml:17` | high | `/infra-audit` | k8s/shutdown-grace-code-constant |
| IO-K8-CRa | `edge/k8s/partner-gateway.yaml:16` | medium | `/infra-audit` | k8s/config-roll-partial |
| IO-K8-CRb | `k8s/chart/templates/deployment.yaml:33` | medium | `/infra-audit` | k8s/config-roll-none |
| IO-K8-SPa | `k8s/base/courier-tracker.yaml:63` | high | `/infra-audit` | k8s/service-target-port |
| IO-K8-SPb | `k8s/chart/templates/service.yaml:11` | high | `/infra-audit` | k8s/service-target-port |
| IO-K8-NPa | `k8s/base/netpol.yaml:19` | high | `/infra-audit` | k8s/netpol-dns |
| IO-K8-NPb | `dr/k8s/netpol.yaml:5` | high | `/infra-audit` | k8s/netpol-dns |
| IO-K8-ARa | `k8s/platform/legacy-cronjob.yaml:1` | critical | `/infra-audit` | k8s/api-removed |
| IO-K8-ARb | `edge/k8s/ingress.yaml:1` | critical | `/infra-audit` | k8s/api-removed |
| IO-K8-PNa | `k8s/overlays/prod/kustomization.yaml:17` | high | `/infra-audit` | k8s/kustomize-patch-noop |
| IO-K8-PNb | `k8s/overlays/prod/kustomization.yaml:24` | high | `/infra-audit` | k8s/kustomize-patch-noop |
| IO-K8-HVa | `k8s/chart/values-prod.yaml:3` | high | `/infra-audit` | k8s/helm-value-unused |
| IO-K8-HVb | `k8s/chart/values-prod.yaml:9` | medium | `/infra-audit` | k8s/helm-value-unused |
| IO-K8-GRa | `k8s/argo/larder-prod.yaml:18` | high | `/infra-audit` | k8s/gitops-replicas |
| IO-K8-GRb | `k8s/argo/larder-storefront.yaml:26` | high | `/infra-audit` | k8s/gitops-replicas-ignore-only |
| IO-K8-SFa | `k8s/ops/runbooks/platform.md:24` | high | `/infra-audit` | k8s/platform-spof |
| IO-K8-SFb | `k8s/ops/runbooks/platform.md:27` | medium | `/infra-audit` | k8s/platform-spof |
| IO-K8-RBa | `k8s/base/courier-tracker.yaml:17` | high | `/infra-audit` | k8s/rbac-sa-missing |
| IO-K8-RBb | `k8s/base/rbac.yaml:8` | high | `/infra-audit` | k8s/rbac-dangling-roleref |
| IO-ED-01a | `edge/nginx/nginx.conf:41` | high | `/infra-audit` | edge/timeout-chain |
| IO-ED-01b | `edge/caddy/shop.caddy:29` | high | `/infra-audit` | edge/timeout-chain |
| IO-ED-02a | `edge/nginx/nginx.conf:25` | medium | `/infra-audit` | edge/keepalive-inversion |
| IO-ED-02b | `edge/caddy/shop.caddy:35` | medium | `/infra-audit` | edge/keepalive-inversion |
| IO-ED-03a | `edge/nginx/nginx.conf:50` | high | `/infra-audit` | edge/non-idempotent-retry |
| IO-ED-03b | `edge/caddy/api.caddy:20` | high | `/infra-audit` | edge/non-idempotent-retry |
| IO-ED-07a | `edge/nginx/partner-gateway.conf:40` | high | `/infra-audit` | edge/no-resolver |
| IO-ED-07b | `edge/nginx/partner-gateway.conf:44` | high | `/infra-audit` | edge/static-dns |
| IO-ED-08a | `edge/nginx/nginx.conf:45` | high | `/infra-audit` | edge/sse-buffered |
| IO-ED-08b | `edge/nginx/partner-gateway.conf:48` | high | `/infra-audit` | edge/sse-buffered |
| IO-ED-17a | `edge/k8s/caddy.yaml:24` | high | `/infra-audit` | edge/silent-rejection |
| IO-ED-17b | `.github/workflows/edge.yml:17` | high | `/infra-audit` | edge/validation-cannot-fail |
| IO-ED-21a | `edge/nginx/nginx.conf:11` | low | `/infra-audit` | edge/access-log-no-request-id |
| IO-ED-21b | `edge/caddy/shop.caddy:19` | low | `/infra-audit` | edge/access-log-no-request-id |
| IO-DN-03a | `dns/terraform/route53.tf:11` | high | `/infra-audit` | dns/caa-ca-mismatch |
| IO-DN-03b | `dns/zones/larder-partners.example.zone:8` | high | `/infra-audit` | dns/caa-ca-mismatch |
| IO-DN-05a | `dns/monitoring/tls-rules.yaml:13` | medium | `/infra-audit` | tls/no-expiry-signal |
| IO-DN-05b | `dns/monitoring/tls-rules.yaml:21` | medium | `/infra-audit` | tls/expiry-probe-reads-cdn |
| IO-DN-06a | `dns/cert-manager/overlays/preview/preview-certificate.yaml:13` | medium | `/infra-audit` | tls/nonprod-on-prod-acme |
| IO-DN-06b | `edge/caddy/preview.caddy:4` | medium | `/infra-audit` | tls/nonprod-on-prod-acme |
| IO-NW-03a | `iac/envs/prod/nacl.tf:10` | high | `/infra-audit` | network/nacl-return-path |
| IO-NW-03b | `iac/envs/prod/nacl.tf:71` | high | `/infra-audit` | network/nacl-return-path |
| IO-NW-07a | `iac/envs/analytics/main.tf:29` | high | `/infra-audit` | network/cidr-overlap-peered |
| IO-NW-07b | `iac/envs/prod/vpn.tf:21` | high | `/infra-audit` | network/cidr-overlap-vpn |
| IO-SEC-E4a | `edge/nginx/nginx.conf:55` | high | `/security-audit` `/infra-audit` | security/shared-cache-user-response |
| IO-SEC-E4b | `edge/caddy/api.caddy:26` | high | `/security-audit` `/infra-audit` | security/shared-cache-user-response |
| IO-SEC-D1a | `dns/terraform/route53.tf:30` | high | `/security-audit` `/infra-audit` | security/dangling-dns-takeover |
| IO-SEC-D1b | `dns/terraform/cloudflare.tf:11` | high | `/security-audit` `/infra-audit` | security/dangling-dns-takeover |
| IO-SEC-NPa | `k8s/base/netpol.yaml:34` | medium | `/security-audit` `/infra-audit` | security/netpol-ipblock-wide |
| IO-SEC-NPb | `k8s/base/netpol.yaml:48` | medium | `/security-audit` `/infra-audit` | security/netpol-ipblock-wide |
| IO-SEC-RBa | `k8s/base/rbac.yaml:20` | high | `/security-audit` `/infra-audit` | security/rbac-wildcard |
| IO-SEC-RBb | `k8s/base/support-rbac.yaml:7` | high | `/security-audit` `/infra-audit` | security/rbac-wildcard |
| IO-SEC-VKa | `edge/caddy/shop.caddy:12` | high | `/security-audit` `/infra-audit` | security/shared-store-credential |
| IO-SEC-VKb | `edge/k8s/caddy.yaml:34` | high | `/security-audit` `/infra-audit` | security/shared-store-credential |
| IO-SEC-ECa | `iac/envs/prod/ecr.tf:3` | medium | `/security-audit` `/infra-audit` | security/registry-tag-mutable |
| IO-SEC-ECb | `k8s/base/checkout.yaml:27` | medium | `/security-audit` `/infra-audit` | security/deploy-by-mutable-tag |

Severity split: 8 critical · 78 high · 48 medium · 4 low. Total 138 seeded defects: 126 infrastructure seeds over the eval's 63 classes (exactly 2 each, two spellings or two stacks), plus 12 security-owned rows scored by both commands. 34 decoy blocks (the eval's 32 decoys; decoy 9, "no CPU limit", is one block per workload).

### Coverage by detector §

| family | detector § | classes | seeded | ids |
|--------|------------|---------|--------|-----|
| state | `iac-state-scan §1` | state/committed-local-state, state/deprecated-lock-no-encryption | 2 | IO-ST-01a, IO-ST-01b |
| state | `iac-state-scan §2` | state/secret-output-not-sensitive, state/secret-variable-not-sensitive | 2 | IO-ST-11a, IO-ST-11b |
| state | `iac-state-scan §3` | pinning/argo-target-revision-wildcard, pinning/engine-unpinned, pinning/helm-chart-unpinned, pinning/module-source-mutable, pinning/provider-unconstrained, pinning/registry-module-no-version | 6 | IO-ST-03a, IO-ST-03b, IO-ST-04a, IO-ST-04b, IO-ST-PHa, IO-ST-PHb |
| state | `iac-state-scan §4` | plan-discipline/no-drift-detection, plan-discipline/target-in-automation | 2 | IO-ST-09a, IO-ST-09b |
| lifecycle | `iac-lifecycle-scan §1` | identity/cdk-logical-id-from-index, identity/count-over-collection | 2 | IO-LC-05a, IO-LC-05b |
| lifecycle | `iac-lifecycle-scan §2` | lifecycle/cbd-fixed-name, lifecycle/ignore-changes-all | 2 | IO-LC-06a, IO-LC-06b |
| lifecycle | `iac-lifecycle-scan §3` | refactor/destroy-false-on-store, refactor/removed-orphan | 2 | IO-LC-07a, IO-LC-07b |
| lifecycle | `iac-lifecycle-scan §4` | stateful-replace/efs-encryption, stateful-replace/rds-identifier | 2 | IO-LC-08a, IO-LC-08b |
| lifecycle | `iac-lifecycle-scan §5` | imperative/external-data, imperative/local-exec-migration | 2 | IO-LC-10a, IO-LC-10b |
| lifecycle | `iac-lifecycle-scan §6` | perpetual-diff/most-recent-ami, perpetual-diff/timestamp | 2 | IO-LC-13a, IO-LC-13b |
| lifecycle | `iac-lifecycle-scan §7` | deletion/automated-backups-deleted, deletion/engine-guard-cfn, deletion/engine-guard-pulumi, deletion/final-snapshot-skipped, deletion/force-destroy, deletion/kms-window-short, deletion/protection-absent, deletion/protection-off | 10 | IO-LC-D1a, IO-LC-D1b, IO-LC-D2a, IO-LC-D2b, IO-LC-D3a, IO-LC-D3b, IO-LC-D4a, IO-LC-D4b, IO-LC-D5a, IO-LC-D5b |
| dr | `dr-audit §1` | durability/retention-below-floor, durability/retention-one-full | 2 | IO-DR-01a, IO-DR-01b |
| dr | `dr-audit §2` | durability/pitr-off | 2 | IO-DR-02a, IO-DR-02b |
| dr | `dr-audit §4` | durability/storage-uncapped | 2 | IO-DR-04a, IO-DR-04b |
| dr | `dr-audit §7` | durability/bucket-unversioned | 2 | IO-DR-09a, IO-DR-09b |
| dr | `dr-audit §8` | recoverability/backup-in-app-bucket, recoverability/governance-not-immutable, recoverability/no-copy-outside-account | 4 | IO-DR-R3a, IO-DR-R3b, IO-DR-R4a, IO-DR-R4b |
| dr | `dr-audit §9` | objectives/rpo-arithmetic, objectives/rto-arithmetic | 2 | IO-DR-R1a, IO-DR-R1b |
| dr | `dr-audit §10` | operator/cnpg-no-backup, operator/velero-no-pv-data, operator/wal-archive-lies, operator/zalando-no-backup | 6 | IO-DR-R6a, IO-DR-R6b, IO-DR-R7a, IO-DR-R7b, IO-DR-R8a, IO-DR-R8b |
| dr | `dr-audit §11` | restore/drill-in-place, restore/drill-stale-weak | 2 | IO-DR-R10a, IO-DR-R10b |
| dr | `dr-audit §12` | destroy/backup-in-destroyable-state | 2 | IO-DR-R11a, IO-DR-R11b |
| serverless | `serverless-reliability-scan §2` | serverless/visibility-below-timeout | 2 | IO-SL-02a, IO-SL-02b |
| serverless | `serverless-reliability-scan §3` | serverless/no-dlq | 2 | IO-SL-03a, IO-SL-03b |
| serverless | `serverless-reliability-scan §4` | serverless/partial-batch-missing, serverless/partial-batch-never-returned | 2 | IO-SL-04a, IO-SL-04b |
| serverless | `serverless-reliability-scan §5` | serverless/concurrency-unbounded | 2 | IO-SL-05a, IO-SL-05b |
| serverless | `serverless-reliability-scan §6` | serverless/retry-storm | 2 | IO-SL-06a, IO-SL-06b |
| cost | `iac-cost-scan §1` | cost/nat-per-az-nonprod, cost/s3-interface-not-gateway | 2 | IO-CO-01a, IO-CO-01b |
| cost | `iac-cost-scan §4` | cost/gp2-default, cost/gp2-explicit | 2 | IO-CO-04a, IO-CO-04b |
| cost | `iac-cost-scan §8` | cost/scale-ceiling-absent, cost/scale-ceiling-unreviewed | 2 | IO-CO-08a, IO-CO-08b |
| k8s | `k8s-availability-scan §3` | k8s/pdb-blocks-drain, k8s/pdb-blocks-drain-keda-floor | 2 | IO-K8-PDBa, IO-K8-PDBb |
| k8s | `k8s-availability-scan §4` | k8s/hpa-no-cpu-request, k8s/keda-cpu-no-request, k8s/replicas-beside-hpa | 4 | IO-K8-HRa, IO-K8-HRb, IO-K8-NRa, IO-K8-NRb |
| k8s | `k8s-availability-scan §2` | k8s/probe-same | 2 | IO-K8-PSa, IO-K8-PSb |
| k8s | `k8s-availability-scan §7` | k8s/shutdown-grace, k8s/shutdown-grace-code-constant | 2 | IO-K8-SGa, IO-K8-SGb |
| k8s | `k8s-wiring-scan §1` | k8s/config-roll-none, k8s/config-roll-partial | 2 | IO-K8-CRa, IO-K8-CRb |
| k8s | `k8s-wiring-scan §2` | k8s/service-target-port | 2 | IO-K8-SPa, IO-K8-SPb |
| k8s | `k8s-wiring-scan §3` | k8s/netpol-dns | 2 | IO-K8-NPa, IO-K8-NPb |
| k8s | `k8s-api-version-scan §1` | k8s/api-removed | 2 | IO-K8-ARa, IO-K8-ARb |
| k8s | `k8s-render-scan §3` | k8s/kustomize-patch-noop | 2 | IO-K8-PNa, IO-K8-PNb |
| k8s | `k8s-render-scan §1` | k8s/helm-value-unused | 2 | IO-K8-HVa, IO-K8-HVb |
| k8s | `k8s-render-scan §4` | k8s/gitops-replicas, k8s/gitops-replicas-ignore-only | 2 | IO-K8-GRa, IO-K8-GRb |
| k8s | `k8s-availability-scan §9` | k8s/platform-spof | 2 | IO-K8-SFa, IO-K8-SFb |
| k8s | `k8s-wiring-scan §6` | k8s/rbac-dangling-roleref, k8s/rbac-sa-missing | 2 | IO-K8-RBa, IO-K8-RBb |
| edge | `edge-reliability-scan §1` | edge/timeout-chain | 2 | IO-ED-01a, IO-ED-01b |
| edge | `edge-reliability-scan §2` | edge/keepalive-inversion | 2 | IO-ED-02a, IO-ED-02b |
| edge | `edge-reliability-scan §3` | edge/non-idempotent-retry | 2 | IO-ED-03a, IO-ED-03b |
| edge | `edge-reliability-scan §5` | edge/no-resolver, edge/static-dns | 2 | IO-ED-07a, IO-ED-07b |
| edge | `edge-reliability-scan §6` | edge/sse-buffered | 2 | IO-ED-08a, IO-ED-08b |
| edge | `edge-reliability-scan §13` | edge/silent-rejection, edge/validation-cannot-fail | 2 | IO-ED-17a, IO-ED-17b |
| edge | `edge-reliability-scan §15` | edge/access-log-no-request-id | 2 | IO-ED-21a, IO-ED-21b |
| dns/tls | `dns-tls-lifecycle-scan §2` | dns/caa-ca-mismatch | 2 | IO-DN-03a, IO-DN-03b |
| dns/tls | `dns-tls-lifecycle-scan §4` | tls/expiry-probe-reads-cdn, tls/no-expiry-signal | 2 | IO-DN-05a, IO-DN-05b |
| dns/tls | `dns-tls-lifecycle-scan §5` | tls/nonprod-on-prod-acme | 2 | IO-DN-06a, IO-DN-06b |
| network | `network-exposure-audit §1` | network/nacl-return-path | 2 | IO-NW-03a, IO-NW-03b |
| network | `network-exposure-audit §2` | network/cidr-overlap-peered, network/cidr-overlap-vpn | 2 | IO-NW-07a, IO-NW-07b |
| security (routed) | `iac-scan §6 (fallback edge-reliability-scan §4)` | security/shared-cache-user-response | 2 | IO-SEC-E4a, IO-SEC-E4b |
| security (routed) | `iac-scan §4 (fallback dns-tls-lifecycle-scan §7)` | security/dangling-dns-takeover | 2 | IO-SEC-D1a, IO-SEC-D1b |
| security (routed) | `iac-scan §3 (4k)` | security/netpol-ipblock-wide | 2 | IO-SEC-NPa, IO-SEC-NPb |
| security (routed) | `iac-scan §3` | security/rbac-wildcard | 2 | IO-SEC-RBa, IO-SEC-RBb |
| security (routed) | `iac-scan §3 (7f)` | security/shared-store-credential | 2 | IO-SEC-VKa, IO-SEC-VKb |
| security (routed) | `iac-scan §4 (4j registry variant)` | security/registry-tag-mutable | 1 | IO-SEC-ECa |
| security (routed) | `iac-scan §3 (4j)` | security/deploy-by-mutable-tag | 1 | IO-SEC-ECb |
| **decoys (must not be reported)** | — | — | **34** | IO-DECOY-01 … IO-DECOY-32 |

---

## IO-ST-01a — The prod backend locks through `dynamodb_table` only and never encrypts

```defect
id:       IO-ST-01a
file:     iac/envs/prod/versions.tf
line:     16
severity: high
command:  /infra-audit
class:    state/deprecated-lock-no-encryption
detector: iac-state-scan §1
anchor:   dynamodb_table = "larder-tf-locks"
match:    lock|dynamodb|use_lockfile|encrypt
```

The prod root's `backend "s3"` names the deprecated DynamoDB lock table with no `use_lockfile` and no `encrypt = true`. CI and the on-call `oncall-db-apply.sh` race on the prod state, and the state (endpoints, generated tokens) sits unencrypted. Fix: `use_lockfile = true`, `encrypt = true`, drop `dynamodb_table` after the migration window. Proof: V244 — two `plan -lock-timeout=0s` runs, one must fail on the lock.

## IO-ST-01b — The shared IAM root keeps its state as a committed `terraform.tfstate`

```defect
id:       IO-ST-01b
file:     iac/envs/shared/main.tf
line:     2
severity: high
command:  /infra-audit
class:    state/committed-local-state
detector: iac-state-scan §1
anchor:   terraform {
match:    tfstate|state|commit|local
```

`iac/envs/shared/` declares no backend, so its state is the committed `iac/envs/shared/terraform.tfstate`; so every engineer applies against their own checkout's copy and the CI deploy role's trust policy drifts with whoever applied last. Fix: an S3 backend with `use_lockfile`, `terraform state push` once, delete the file from git. Proof: V244.

## IO-ST-11a — `master_password` is not `sensitive`

```defect
id:       IO-ST-11a
file:     iac/modules/db/variables.tf
line:     20
severity: medium
command:  /infra-audit
class:    state/secret-variable-not-sensitive
detector: iac-state-scan §2
anchor:   variable "master_password" {
match:    sensitive|password|plan|output
```

The db module's password variable lacks `sensitive = true`; the root's `orders_db_password` is sensitive but the module drops the mark, so the value can print in plans and CI logs. Fix: `sensitive = true`, or `manage_master_user_password` like the other databases. Proof: V244 — `terraform test`.

## IO-ST-11b — The `random_password` partner token is a plain output

```defect
id:       IO-ST-11b
file:     iac/envs/prod/outputs.tf
line:     10
severity: medium
command:  /infra-audit
class:    state/secret-output-not-sensitive
detector: iac-state-scan §2
anchor:   output "queue_token" {
match:    sensitive|token|output|secret
```

`output "queue_token"` exposes `random_password.queue_token.result` with no `sensitive = true`: `terraform output` prints the partner bridge token. Fix: `sensitive = true`, or keep the token in Secrets Manager and output its ARN. Proof: V244 (precedents § 58: provider-sensitive attributes fail only at `plan`/`test`).

## IO-ST-03a — The prod root's `google` provider has no version constraint

```defect
id:       IO-ST-03a
file:     iac/envs/prod/versions.tf
line:     9
severity: medium
command:  /infra-audit
class:    pinning/provider-unconstrained
detector: iac-state-scan §3
anchor:   google = { source = "hashicorp/google" }
match:    google|version|constraint|pin|unpinned
```

Every other provider carries `~>`; `google` has none, so the first `init -upgrade` takes the next major for the two Cloud SQL instances and the exports bucket. Fix: `version = "~> 7.4"` (the lock file's 7.4.0). Proof: V245.

## IO-ST-03b — The OpenTofu search root pins no engine version

```defect
id:       IO-ST-03b
file:     iac/tofu/search-index/main.tofu
line:     2
severity: medium
command:  /infra-audit
class:    pinning/engine-unpinned
detector: iac-state-scan §3
anchor:   terraform {
match:    required_version|engine|tofu|version
```

`iac/tofu/search-index` has a `terraform {}` block with no `required_version`; it took the search domain over from the prod root (ADR 0012) and runs on whatever `tofu` is installed. Fix: `required_version = "~> 1.13.0"`. Proof: V245.

## IO-ST-04a — The prod bastion module tracks `?ref=main`

```defect
id:       IO-ST-04a
file:     iac/envs/prod/bastion.tf
line:     3
severity: medium
command:  /infra-audit
class:    pinning/module-source-mutable
detector: iac-state-scan §3
anchor:   source = "git::https://github.com/larder-platform/tf-modules.git//bastion?ref=main"
match:    ref=main|module|source|pin|mutable|branch
```

A push to the module repo changes the next prod plan with no change in this repo. Fix: `?ref=<40-hex commit>`. Proof: V245.

## IO-ST-04b — The registry SQS module has no `version`

```defect
id:       IO-ST-04b
file:     iac/envs/prod/queues.tf
line:     1
severity: medium
command:  /infra-audit
class:    pinning/registry-module-no-version
detector: iac-state-scan §3
anchor:   module "events" {
match:    version|module|registry|pin
```

`terraform-aws-modules/sqs/aws` with no `version` installs the newest release on every fresh init, majors included. Fix: `version = "~> 5.0"`. Proof: V245.

## IO-ST-PHa — cert-manager is installed with no `--version`

```defect
id:       IO-ST-PHa
file:     k8s/ops/runbooks/platform.md
line:     29
severity: medium
command:  /infra-audit
class:    pinning/helm-chart-unpinned
detector: iac-state-scan §3
anchor:   helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace
match:    version|unpinned|pin|cert-manager|helm
```

The cluster-build runbook installs whatever the chart index holds on the day (cert-manager ≥ 1.18 changed `rotationPolicy` defaults, precedents § 62). Fix: `--version vX.Y.Z`. Proof: V245.

## IO-ST-PHb — Argo installs kube-prometheus-stack at `targetRevision: "*"`

```defect
id:       IO-ST-PHb
file:     k8s/argo/larder-observability.yaml
line:     11
severity: medium
command:  /infra-audit
class:    pinning/argo-target-revision-wildcard
detector: iac-state-scan §3
anchor:   targetRevision: "*"
match:    targetRevision|\*|pin|version|unpinned
```

With selfHeal the Application follows every new chart release, majors and CRD changes included. Fix: an exact chart version. Proof: V245.

## IO-ST-09a — On-call applies the orders database with `-target … -auto-approve`

```defect
id:       IO-ST-09a
file:     iac/scripts/oncall-db-apply.sh
line:     6
severity: medium
command:  /infra-audit
class:    plan-discipline/target-in-automation
detector: iac-state-scan §4
anchor:   apply -target=module.orders_db -auto-approve
match:    -target|target|auto-approve|partial
```

`iac/scripts/oncall-db-apply.sh` applies a partial graph with no reviewed plan: dependants (backup selection, seed resource) are skipped. Fix: drop the target; apply the reviewed `tfplan`. Proof: V244.

## IO-ST-09b — Prod is planned only on pull requests: no drift detection

```defect
id:       IO-ST-09b
file:     .github/workflows/terraform.yml
line:     20
severity: medium
command:  /infra-audit
class:    plan-discipline/no-drift-detection
detector: iac-state-scan §4
anchor:   run: terraform -chdir=iac/envs/prod plan -input=false -no-color -out=tfplan
match:    drift|detailed-exitcode|refresh-only|schedule|plan
```

No `-detailed-exitcode`, no scheduled `-refresh-only` job, so console edits (the CloudFront distribution is edited by hand) are never seen. Fix: a scheduled `plan -refresh-only -detailed-exitcode` failing on exit 2. Proof: V244.

## IO-LC-05a — Partner queues are keyed by `count` over a list

```defect
id:       IO-LC-05a
file:     iac/envs/prod/queues.tf
line:     16
severity: high
command:  /infra-audit
class:    identity/count-over-collection
detector: iac-lifecycle-scan §1
anchor:   count                      = length(var.partner_queues)
match:    count|index|for_each|re-?index|churn
```

Removing a partner from the middle of `partner_queues` shifts later indexes: those queues are destroyed and recreated with their in-flight messages. Fix: `for_each = toset(...)` plus `moved` blocks. Proof: V246 churn plan.

## IO-LC-05b — CDK archive buckets take their logical id from the array index

```defect
id:       IO-LC-05b
file:     iac/cdk/lib/ledger-archive-stack.ts
line:     13
severity: high
command:  /infra-audit
class:    identity/cdk-logical-id-from-index
detector: iac-lifecycle-scan §1
anchor:   new s3.Bucket(this, `ArchiveBucket${i}`, {
match:    logical|id|index|bucket|replace
```

Removing a region renames the later buckets' logical ids, so CloudFormation replaces buckets that hold finance exports (and fails on the fixed `bucketName`). Fix: derive the id from the region. Proof: V246 — `cdk diff`.

## IO-LC-06a — `ignore_changes = all` on the storefront CloudFront distribution

```defect
id:       IO-LC-06a
file:     iac/envs/prod/cdn.tf
line:     37
severity: medium
command:  /infra-audit
class:    lifecycle/ignore-changes-all
detector: iac-lifecycle-scan §2
anchor:   ignore_changes = all
match:    ignore_changes|all|drift
```

Terraform never reconciles it again: console edits stay and code changes are silently ignored. Fix: list the console-owned attributes. Proof: V247.

## IO-LC-06b — `create_before_destroy` on a target group with a fixed `name`

```defect
id:       IO-LC-06b
file:     iac/envs/prod/compute.tf
line:     46
severity: medium
command:  /infra-audit
class:    lifecycle/cbd-fixed-name
detector: iac-lifecycle-scan §2
anchor:   create_before_destroy = true
match:    create_before_destroy|name|replace|conflict
```

Any replacement creates the new `orders-api` group first under the same name, which AWS rejects: the apply fails mid-change. Fix: `name_prefix`. Proof: V247.

## IO-LC-07a — The legacy exports bucket is `removed` with `destroy = false` and no new owner

```defect
id:       IO-LC-07a
file:     iac/envs/prod/legacy.tf
line:     2
severity: medium
command:  /infra-audit
class:    refactor/removed-orphan
detector: iac-lifecycle-scan §3
anchor:   removed {
match:    removed|orphan|destroy = false|forget|billing
```

Nothing imports `aws_s3_bucket.legacy_exports` and no ADR names an owner: the bucket keeps its data and bill and leaves every inventory (TF-07). Fix: delete it on purpose or hand it to a named state. Proof: V247.

## IO-LC-07b — `lifecycle { destroy = false }` on the sessions and idempotency store

```defect
id:       IO-LC-07b
file:     iac/envs/prod/cache.tf
line:     14
severity: high
command:  /infra-audit
class:    refactor/destroy-false-on-store
detector: iac-lifecycle-scan §3
anchor:   destroy = false
match:    destroy = false|forget|replace|orphan|empty
```

A forced replacement plans `forget,create`: the old group is orphaned and an empty one takes the name, so every idempotency key disappears (precedents § 28 flip). Fix: `prevent_destroy = true` and a migration plan. Proof: V247/V248.

## IO-LC-08a — The committed prod plan replaces the orders database

```defect
id:       IO-LC-08a
file:     iac/plans/prod.plan.json
line:     6
severity: critical
command:  /infra-audit
class:    stateful-replace/rds-identifier
detector: iac-lifecycle-scan §4
anchor:   "address": "module.orders_db.aws_db_instance.this",
match:    replace|identifier|orders|delete|recreate
```

Renaming `identifier` to `larder-orders-v2` plans `delete,create` (`replace_because_cannot_update`); with the module's `skip_final_snapshot` default the old instance goes without a final snapshot. Fix: keep the identifier, or snapshot → restore → cut-over with an ADR. Proof: V248 — STATEFUL-REPLACE row.

## IO-LC-08b — Turning on EFS encryption replaces the media library file system

```defect
id:       IO-LC-08b
file:     iac/plans/prod.plan.json
line:     61
severity: critical
command:  /infra-audit
class:    stateful-replace/efs-encryption
detector: iac-lifecycle-scan §4
anchor:   "address": "aws_efs_file_system.media",
match:    replace|efs|encrypt|media|delete
```

`encrypted`/`kms_key_id` force a new file system: the plan deletes the EFS behind the `media-library` claim (merchant originals). Fix: new encrypted EFS + DataSync, then switch. Proof: V248.

## IO-LC-10a — Catalog seed data is loaded by a `local-exec` psql

```defect
id:       IO-LC-10a
file:     iac/envs/prod/migrations.tf
line:     7
severity: medium
command:  /infra-audit
class:    imperative/local-exec-migration
detector: iac-lifecycle-scan §5
anchor:   provisioner "local-exec" {
match:    provisioner|local-exec|null_resource|seed|psql
```

Runs once on create from whoever applies, invisible to the plan. Fix: the app's migrate Job. Proof: V247.

## IO-LC-10b — Every plan curls a release service through `data "external"`

```defect
id:       IO-LC-10b
file:     iac/envs/prod/release.tf
line:     2
severity: medium
command:  /infra-audit
class:    imperative/external-data
detector: iac-lifecycle-scan §5
anchor:   data "external" "release" {
match:    external|data source|curl|release
```

Offline or credential-less plans fail, and the tag rewrites every resource that carries it. Fix: pass the release as a variable from CI. Proof: V247.

## IO-LC-13a — `timestamp()` in a tag makes every plan non-empty

```defect
id:       IO-LC-13a
file:     iac/envs/prod/sns.tf
line:     5
severity: medium
command:  /infra-audit
class:    perpetual-diff/timestamp
detector: iac-lifecycle-scan §6
anchor:   LastApplied = timestamp()
match:    timestamp|perpetual|diff
```

Drift detection can never be clean. Fix: drop it. Proof: V247 — second plan exits 2.

## IO-LC-13b — The batch launch template follows `most_recent` AMI

```defect
id:       IO-LC-13b
file:     iac/envs/prod/compute.tf
line:     4
severity: medium
command:  /infra-audit
class:    perpetual-diff/most-recent-ami
detector: iac-lifecycle-scan §6
anchor:   most_recent = true
match:    most_recent|ami|perpetual|diff|replace
```

Each new AMI changes the template with no code change. Fix: pin the AMI. Proof: V247.

## IO-LC-D1a — The db module defaults `skip_final_snapshot` to true and prod does not override it

```defect
id:       IO-LC-D1a
file:     iac/modules/db/variables.tf
line:     25
severity: high
command:  /infra-audit
class:    deletion/final-snapshot-skipped
detector: iac-lifecycle-scan §7
anchor:   variable "skip_final_snapshot" {
match:    final.?snapshot|skip|default
```

The module default reaches prod (precedents § 18 flip): a destroy or replacement (IO-LC-08a) deletes orders with no final snapshot. Fix: default `false`. Proof: V249.

## IO-LC-D1b — The reporting Aurora cluster skips its final snapshot

```defect
id:       IO-LC-D1b
file:     iac/envs/prod/reporting.tf
line:     11
severity: high
command:  /infra-audit
class:    deletion/final-snapshot-skipped
detector: iac-lifecycle-scan §7
anchor:   skip_final_snapshot         = true
match:    final.?snapshot|skip
```

Fix: `false` with a `final_snapshot_identifier`. Proof: V249.

## IO-LC-D2a — The orders DynamoDB table has no deletion protection

```defect
id:       IO-LC-D2a
file:     iac/envs/prod/databases.tf
line:     15
severity: high
command:  /infra-audit
class:    deletion/protection-absent
detector: iac-lifecycle-scan §7
anchor:   resource "aws_dynamodb_table" "orders" {
match:    deletion.?protection|delete
```

`deletion_protection_enabled` is unset (null, precedents § 59); `prevent_destroy` stops Terraform, not a console or CLI delete. Fix: `true`. Proof: V249.

## IO-LC-D2b — Both deletion guards are off on the analytics Cloud SQL instance

```defect
id:       IO-LC-D2b
file:     iac/envs/prod/gcp.tf
line:     6
severity: high
command:  /infra-audit
class:    deletion/protection-off
detector: iac-lifecycle-scan §7
anchor:   deletion_protection = false
match:    deletion.?protection|delete
```

`deletion_protection` and `deletion_protection_enabled` are false. Fix: both `true`. Proof: V249.

## IO-LC-D3a — `force_destroy = true` on the customer uploads bucket

```defect
id:       IO-LC-D3a
file:     iac/envs/prod/storage.tf
line:     4
severity: high
command:  /infra-audit
class:    deletion/force-destroy
detector: iac-lifecycle-scan §7
anchor:   force_destroy = true
match:    force_destroy|destroy|delete|contents
```

A destroy empties `larder-uploads-prod` (proof-of-delivery photos, and today the nightly order dumps, IO-DR-R3a). Fix: remove it, add `prevent_destroy`. Proof: V249.

## IO-LC-D3b — `force_destroy = true` on the analytics exports bucket

```defect
id:       IO-LC-D3b
file:     iac/envs/prod/gcp.tf
line:     21
severity: medium
command:  /infra-audit
class:    deletion/force-destroy
detector: iac-lifecycle-scan §7
anchor:     force_destroy = true
match:    force_destroy|destroy|delete|exports
```

Fix: remove the flag. Proof: V249.

## IO-LC-D4a — CloudFormation deletes the finance reporting DB with no snapshot

```defect
id:       IO-LC-D4a
file:     iac/cfn/reporting-replica.yaml
line:     13
severity: high
command:  /infra-audit
class:    deletion/engine-guard-cfn
detector: iac-lifecycle-scan §7
anchor:   DeletionPolicy: Delete
match:    DeletionPolicy|Delete|Snapshot|Retain
```

`DeletionPolicy: Delete` and no `UpdateReplacePolicy` on `AWS::RDS::DBInstance`. Fix: `Snapshot`/`Retain` on both. Proof: V249 — cfn-lint I3011.

## IO-LC-D4b — Pulumi `protect: false` on the partner statements database

```defect
id:       IO-LC-D4b
file:     iac/pulumi/index.ts
line:     17
severity: high
command:  /infra-audit
class:    deletion/engine-guard-pulumi
detector: iac-lifecycle-scan §7
anchor:   }, { protect: false });
match:    protect|retainOnDelete|delete
```

Fix: `protect: true`, `retainOnDelete: true`. Proof: V249.

## IO-LC-D5a — The key that encrypts the ledger and the backup vault has a 7-day deletion window

```defect
id:       IO-LC-D5a
file:     iac/envs/prod/kms.tf
line:     5
severity: high
command:  /infra-audit
class:    deletion/kms-window-short
detector: iac-lifecycle-scan §7
anchor:   deletion_window_in_days = 7
match:    deletion_window|kms|7|window
```

Below `THR-KMS-WINDOW` (30): a deletion noticed after a week makes every backup undecryptable. Fix: 30. Proof: V249.

## IO-LC-D5b — Deleting the ledger instance deletes its automated backups

```defect
id:       IO-LC-D5b
file:     iac/envs/prod/ledger.tf
line:     17
severity: high
command:  /infra-audit
class:    deletion/automated-backups-deleted
detector: iac-lifecycle-scan §7
anchor:   delete_automated_backups    = true
match:    automated.?backups|delete
```

The PITR window goes with the instance. Fix: `false`. Proof: V249.

## IO-DR-01a — The orders database keeps one day of backups

```defect
id:       IO-DR-01a
file:     iac/modules/db/main.tf
line:     13
severity: high
command:  /infra-audit
class:    durability/retention-below-floor
detector: dr-audit §1
anchor:   backup_retention_period    = 1
match:    retention|backup|1 day|days
```

Below `THR-BACKUP-RETENTION`: an error found Monday that happened Friday is past the window (R2). Fix: ≥ 14. Proof: V250.

## IO-DR-01b — pgBackRest keeps one full backup

```defect
id:       IO-DR-01b
file:     dr/pgbackrest/pgbackrest.conf
line:     11
severity: high
command:  /infra-audit
class:    durability/retention-one-full
detector: dr-audit §1
anchor:   repo1-retention-full=1
match:    retention|full|pgbackrest|backup
```

The previous full and its WAL expire when the next completes; a corrupt full has no fallback. Fix: ≥ 2 plus time retention. Proof: V250.

## IO-DR-02a — The carts table has no point-in-time recovery

```defect
id:       IO-DR-02a
file:     iac/envs/prod/databases.tf
line:     36
severity: medium
command:  /infra-audit
class:    durability/pitr-off
detector: dr-audit §2
anchor:   resource "aws_dynamodb_table" "carts" {
match:    point.?in.?time|pitr|recovery
```

A bad deploy that overwrites carts cannot be rolled back. Fix: `point_in_time_recovery { enabled = true }`. Proof: V250.

## IO-DR-02b — PITR is off on the loyalty points database

```defect
id:       IO-DR-02b
file:     iac/envs/prod/gcp.tf
line:     39
severity: high
command:  /infra-audit
class:    durability/pitr-off
detector: dr-audit §2
anchor:   point_in_time_recovery_enabled = false
match:    point.?in.?time|pitr|recovery
```

Only daily backups: up to a day of points lost. Fix: `true`. Proof: V250.

## IO-DR-04a — The promotions database has no storage autoscaling

```defect
id:       IO-DR-04a
file:     iac/envs/prod/promotions.tf
line:     2
severity: medium
command:  /infra-audit
class:    durability/storage-uncapped
detector: dr-audit §4
anchor:   resource "aws_db_instance" "promotions" {
match:    max_allocated_storage|storage|autoscal|full
```

At 200 GB it goes `storage-full` and stops writes. Fix: `max_allocated_storage`. Proof: V250.

## IO-DR-04b — The ledger database has no storage autoscaling

```defect
id:       IO-DR-04b
file:     iac/envs/prod/ledger.tf
line:     2
severity: medium
command:  /infra-audit
class:    durability/storage-uncapped
detector: dr-audit §4
anchor:   resource "aws_db_instance" "ledger" {
match:    max_allocated_storage|storage|autoscal|full
```

Fix: `max_allocated_storage`. Proof: V250.

## IO-DR-09a — The invoices bucket is not versioned

```defect
id:       IO-DR-09a
file:     iac/envs/prod/storage.tf
line:     30
severity: medium
command:  /infra-audit
class:    durability/bucket-unversioned
detector: dr-audit §7
anchor:   resource "aws_s3_bucket" "invoices" {
match:    versioning|version|overwrite|delete
```

Finance must reproduce any invoice for 10 years; an overwrite is final. Fix: versioning + noncurrent rule. Proof: V250.

## IO-DR-09b — The receipts bucket is not versioned

```defect
id:       IO-DR-09b
file:     iac/envs/prod/storage.tf
line:     47
severity: medium
command:  /infra-audit
class:    durability/bucket-unversioned
detector: dr-audit §7
anchor:   resource "aws_s3_bucket" "receipts" {
match:    versioning|version|overwrite|delete
```

Fix: versioning. Proof: V250.

## IO-DR-R3a — The nightly orders dump lands in the app's uploads bucket

```defect
id:       IO-DR-R3a
file:     dr/k8s/pg-dump-cronjob.yaml
line:     28
severity: medium
command:  /infra-audit
class:    recoverability/backup-in-app-bucket
detector: dr-audit §8
anchor:   | aws s3 cp - "s3://larder-uploads-prod/backups/orders/$(date +%F).dump"
match:    uploads|same bucket|app bucket|blast|backups?
```

`larder-uploads-prod` is written by the api (`UPLOADS_BUCKET`) and has `force_destroy = true`: one app credential or bucket mistake reaches prod data and its only off-cluster copy (the real-repo shape). Fix: a dedicated backup bucket and writer. Proof: V251.

## IO-DR-R3b — pgBackRest's repository is the media bucket the app writes

```defect
id:       IO-DR-R3b
file:     dr/pgbackrest/pgbackrest.conf
line:     4
severity: medium
command:  /infra-audit
class:    recoverability/backup-in-app-bucket
detector: dr-audit §8
anchor:   repo1-s3-bucket=larder-media-prod
match:    media|same bucket|app bucket|repo|blast
```

media-processor writes `larder-media-prod` (`MEDIA_BUCKET`). Fix: its own bucket and key. Proof: V251.

## IO-DR-R4a — The database backup bucket's Object Lock is governance mode, the only control

```defect
id:       IO-DR-R4a
file:     dr/terraform/backups.tf
line:     21
severity: medium
command:  /infra-audit
class:    recoverability/governance-not-immutable
detector: dr-audit §8
anchor:   mode = "GOVERNANCE"
match:    governance|immutab|object lock|compliance|bypass
```

Governance yields to `s3:BypassGovernanceRetention` (precedents § 38). Fix: compliance mode or a locked vault in another account. Proof: V251.

## IO-DR-R4b — AWS Backup copies nothing out of the prod account; the vault is unlocked

```defect
id:       IO-DR-R4b
file:     iac/envs/prod/backup.tf
line:     23
severity: medium
command:  /infra-audit
class:    recoverability/no-copy-outside-account
detector: dr-audit §8
anchor:   resource "aws_backup_plan" "daily" {
match:    copy_action|copy|another account|vault lock|immutab
```

No `copy_action`, no vault lock. Fix: copy to a locked vault in a backup account. Proof: V251.

## IO-DR-R1a — Weekly base backups cannot meet inventory's 30-minute RTO

```defect
id:       IO-DR-R1a
file:     dr/databases/inventory-cluster.yaml
line:     28
severity: high
command:  /infra-audit
class:    objectives/rto-arithmetic
detector: dr-audit §9
anchor:   schedule: "0 0 4 * * 0"
match:    RTO|weekly|replay|objective|30 min
```

objectives.md: RTO 30 min; a restore is a base backup up to 7 days old plus up to 7 days of WAL replay on 400 Gi. Fix: daily base backups and a measured restore. Proof: V252.

## IO-DR-R1b — A daily file-system backup for a 1-hour RPO

```defect
id:       IO-DR-R1b
file:     dr/velero/schedule-media.yaml
line:     8
severity: high
command:  /infra-audit
class:    objectives/rpo-arithmetic
detector: dr-audit §9
anchor:   schedule: "0 3 * * *"
match:    RPO|daily|hour|objective|24
```

Up to 24 h of merchant uploads lost. Fix: hourly, or EFS replication. Proof: V252.

## IO-DR-R6a — Velero backs up the search namespace without its volume

```defect
id:       IO-DR-R6a
file:     dr/velero/schedule-search.yaml
line:     11
severity: high
command:  /infra-audit
class:    operator/velero-no-pv-data
detector: dr-audit §10
anchor:   snapshotVolumes: false
match:    snapshotVolumes|volume|PV|data|curation
```

`search-curation` holds merchandising rules that exist nowhere else. Fix: `defaultVolumesToFsBackup: true`. Proof: V254.

## IO-DR-R6b — Velero captures no Postgres volumes in larder-data

```defect
id:       IO-DR-R6b
file:     dr/velero/schedule-data.yaml
line:     11
severity: high
command:  /infra-audit
class:    operator/velero-no-pv-data
detector: dr-audit §10
anchor:   defaultVolumesToFsBackup: false
match:    defaultVolumesToFsBackup|volume|PV|snapshot|data
```

No fs backup and no `VolumeSnapshotLocation`: the catalog cluster (IO-DR-R8a) is captured by nothing. Fix: a snapshot location or fs backup. Proof: V254.

## IO-DR-R7a — `archive-push … || true` reports every WAL segment archived

```defect
id:       IO-DR-R7a
file:     dr/postgres/warehouse.postgresql.conf
line:     7
severity: critical
command:  /infra-audit
class:    operator/wal-archive-lies
detector: dr-audit §10
anchor:   archive_command = 'pgbackrest --stanza=warehouse archive-push %p || true'
match:    archive_command|\|\| true|WAL|archiv
```

Failed pushes count as success; PITR silently has holes. Fix: drop `|| true`. Proof: V254 — `pgbackrest check`.

## IO-DR-R7b — The audit database archives WAL to `/bin/true`

```defect
id:       IO-DR-R7b
file:     dr/postgres/audit.postgresql.conf
line:     7
severity: critical
command:  /infra-audit
class:    operator/wal-archive-lies
detector: dr-audit §10
anchor:   archive_command = '/bin/true'
match:    archive_command|/bin/true|WAL|archiv
```

No WAL kept; `archive-check=n` lets backups succeed anyway. Fix: the pgbackrest push. Proof: V254.

## IO-DR-R8a — The CNPG catalog cluster has no backup section

```defect
id:       IO-DR-R8a
file:     dr/databases/catalog-cluster.yaml
line:     3
severity: high
command:  /infra-audit
class:    operator/cnpg-no-backup
detector: dr-audit §10
anchor:   kind: Cluster
match:    backup|barman|stanza|catalog
```

No `backup:`/`plugins:` on the SKU system of record (RPO 1 h). Fix: `barmanObjectStore` + ScheduledBackup. Proof: V254.

## IO-DR-R8b — The zalando courier-geo cluster has backups off

```defect
id:       IO-DR-R8b
file:     dr/databases/courier-geo.yaml
line:     15
severity: high
command:  /infra-audit
class:    operator/zalando-no-backup
detector: dr-audit §10
anchor:   enableLogicalBackup: false
match:    logical.?backup|backup|wal
```

Delivery disputes are settled from it. Fix: logical backup + WAL archiving. Proof: V254.

## IO-DR-R10a — The only orders drill is seven months old and records nothing

```defect
id:       IO-DR-R10a
file:     dr/runbooks/restore-orders.md
line:     9
severity: high
command:  /infra-audit
class:    restore/drill-stale-weak
detector: dr-audit §11
anchor:   - 2026-03-02: restored orders from the latest snapshot, the app came up fine.
match:    drill|restore|2026-03|count|evidence|stale
```

Older than `THR-BACKUP-DRILL-AGE`, no new target, no counts, no time vs RTO. Fix: a real drill. Proof: V253.

## IO-DR-R10b — The media drill restored over the live claim

```defect
id:       IO-DR-R10b
file:     dr/runbooks/restore-media.md
line:     8
severity: high
command:  /infra-audit
class:    restore/drill-in-place
detector: dr-audit §11
anchor:   - 2026-09-18: restored media-library from media-daily-20260917 into larder-media over the live claim
match:    in place|live|over|spot|new target|drill
```

No new target, three images as evidence. Fix: restore to scratch and compare counts/checksums. Proof: V253.

## IO-DR-R11a — The ledger's rollback snapshot is a resource in the prod root

```defect
id:       IO-DR-R11a
file:     iac/envs/prod/ledger.tf
line:     25
severity: critical
command:  /infra-audit
class:    destroy/backup-in-destroyable-state
detector: dr-audit §12
anchor:   resource "aws_db_snapshot" "pre_migration" {
match:    snapshot|state|destroy|same root
```

A destroy of the root takes it with the instance it protects. Fix: copy it out of the state and account. Proof: V253.

## IO-DR-R11b — The backup vault lives in the prod state

```defect
id:       IO-DR-R11b
file:     iac/envs/prod/backup.tf
line:     2
severity: critical
command:  /infra-audit
class:    destroy/backup-in-destroyable-state
detector: dr-audit §12
anchor:   resource "aws_backup_vault" "primary" {
match:    vault|state|destroy|same root|account
```

One destroy or one compromised apply role reaches the stores and their backups. Fix: a separate backup account and state. Proof: V253.

## IO-SL-02a — Payout queue visibility 30 s for a 120 s function

```defect
id:       IO-SL-02a
file:     serverless/terraform/main.tf
line:     18
severity: high
command:  /infra-audit
class:    serverless/visibility-below-timeout
detector: serverless-reliability-scan §2
anchor:   visibility_timeout_seconds = 30
match:    visibility|timeout|6 ?x|duplicate
```

30 < 6 × 120: the message reappears mid-payout and is paid twice. Fix: ≥ 720 s. Proof: V255 — VIS row.

## IO-SL-02b — SAM settlements queue: visibility 60 s, function timeout 300 s

```defect
id:       IO-SL-02b
file:     serverless/sam/template.yaml
line:     17
severity: high
command:  /infra-audit
class:    serverless/visibility-below-timeout
detector: serverless-reliability-scan §2
anchor:   VisibilityTimeout: 60
match:    visibility|timeout|duplicate|6
```

Settlement files are applied twice. Fix: ≥ 1800 s. Proof: V255.

## IO-SL-03a — The refunds queue has no dead-letter queue

```defect
id:       IO-SL-03a
file:     serverless/terraform/main.tf
line:     50
severity: high
command:  /infra-audit
class:    serverless/no-dlq
detector: serverless-reliability-scan §3
anchor:   resource "aws_sqs_queue" "refunds" {
match:    dead.?letter|dlq|redrive|poison
```

A poison refund retries for 4 days and is dropped. Fix: `redrive_policy`. Proof: V256.

## IO-SL-03b — The SAM payout-retry queue has no RedrivePolicy

```defect
id:       IO-SL-03b
file:     serverless/sam/template.yaml
line:     41
severity: high
command:  /infra-audit
class:    serverless/no-dlq
detector: serverless-reliability-scan §3
anchor:     PayoutRetryQueue:
match:    dead.?letter|dlq|redrive|poison
```

Fix: `RedrivePolicy`. Proof: V256.

## IO-SL-04a — Refund batches retry whole

```defect
id:       IO-SL-04a
file:     serverless/terraform/main.tf
line:     71
severity: high
command:  /infra-audit
class:    serverless/partial-batch-missing
detector: serverless-reliability-scan §4
anchor:   resource "aws_lambda_event_source_mapping" "refunds" {
match:    batchItemFailures|ReportBatchItemFailures|partial|batch
```

No `ReportBatchItemFailures`: one failure re-delivers nine issued refunds. Fix: enable it and return failed ids. Proof: V257.

## IO-SL-04b — The payout-retry handler never returns `batchItemFailures`

```defect
id:       IO-SL-04b
file:     serverless/sam/src/payout-retry.ts
line:     5
severity: high
command:  /infra-audit
class:    serverless/partial-batch-never-returned
detector: serverless-reliability-scan §4
anchor:   export const handler = async (event: SQSEvent): Promise<void> => {
match:    batchItemFailures|partial|swallow|lost|return
```

With `ReportBatchItemFailures` on, returning nothing means all succeeded: failed retries are deleted. Fix: return `{ batchItemFailures }`. Proof: V257.

## IO-SL-05a — ledger_sync is unreserved in front of a 200-connection database

```defect
id:       IO-SL-05a
file:     serverless/terraform/main.tf
line:     93
severity: high
command:  /infra-audit
class:    serverless/concurrency-unbounded
detector: serverless-reliability-scan §5
anchor:   resource "aws_lambda_function" "ledger_sync" {
match:    reserved|concurren|connections|pool|max
```

Regional pool × `LEDGER_DB_POOL=4` far past `max_connections`. Fix: reserve ≤ 40. Proof: V258 — CONC row.

## IO-SL-05b — Cloud Run receipts has no `max_instance_count` in front of Cloud SQL

```defect
id:       IO-SL-05b
file:     serverless/cloudrun/main.tf
line:     19
severity: high
command:  /infra-audit
class:    serverless/concurrency-unbounded
detector: serverless-reliability-scan §5
anchor:   resource "google_cloud_run_v2_service" "receipts" {
match:    max_instance|scal|connections|100|concurren
```

Default 100 × pool 5 against 100 connections. Fix: `max_instance_count`. Proof: V258/V261.

## IO-SL-06a — A poison order event blocks its shard forever

```defect
id:       IO-SL-06a
file:     serverless/terraform/main.tf
line:     141
severity: high
command:  /infra-audit
class:    serverless/retry-storm
detector: serverless-reliability-scan §6
anchor:   maximum_retry_attempts  = -1
match:    retry|poison|bisect|-1|stream|iterator
```

Infinite retries, no bisect, no destination. Fix: bounded retries + bisect + destination. Proof: V259.

## IO-SL-06b — The SAM inventory stream retries a poison record forever

```defect
id:       IO-SL-06b
file:     serverless/sam/template.yaml
line:     83
severity: medium
command:  /infra-audit
class:    serverless/retry-storm
detector: serverless-reliability-scan §6
anchor:   MaximumRetryAttempts: -1
match:    retry|poison|bisect|-1|stream
```

Fix: as above. Proof: V259.

## IO-CO-01a — Staging runs a NAT gateway in every AZ

```defect
id:       IO-CO-01a
file:     iac/envs/staging/main.tf
line:     36
severity: medium
command:  /infra-audit
class:    cost/nat-per-az-nonprod
detector: iac-cost-scan §1
anchor:   resource "aws_nat_gateway" "per_az" {
match:    NAT|per.?AZ|staging|gateway
```

Precedents § 23 flip: 3 × NAT-hours × 730 h in non-prod. Fix: one NAT. Unpriced candidate.

## IO-CO-01b — S3 traffic uses an interface endpoint; no free gateway endpoint

```defect
id:       IO-CO-01b
file:     iac/envs/prod/network.tf
line:     83
severity: medium
command:  /infra-audit
class:    cost/s3-interface-not-gateway
detector: iac-cost-scan §1
anchor:   vpc_endpoint_type   = "Interface"
match:    gateway endpoint|interface|S3|endpoint|NAT|N4
```

Per-AZ-hour and per-GB where the S3 gateway endpoint is free (N4). Fix: an S3 gateway endpoint. Unpriced candidate.

## IO-CO-04a — The 500 GB scratch volume defaults to gp2

```defect
id:       IO-CO-04a
file:     iac/envs/prod/volumes.tf
line:     2
severity: medium
command:  /infra-audit
class:    cost/gp2-default
detector: iac-cost-scan §4
anchor:   resource "aws_ebs_volume" "scratch" {
match:    gp2|gp3|type|volume
```

Fix: `type = "gp3"`. Candidate.

## IO-CO-04b — Batch launch template root volumes are gp2

```defect
id:       IO-CO-04b
file:     iac/envs/prod/compute.tf
line:     20
severity: medium
command:  /infra-audit
class:    cost/gp2-explicit
detector: iac-cost-scan §4
anchor:   volume_type = "gp2"
match:    gp2|gp3|volume
```

Fix: gp3. Candidate.

## IO-CO-08a — The notifier ScaledObject has no `maxReplicaCount`

```defect
id:       IO-CO-08a
file:     k8s/base/notifier.yaml
line:     35
severity: medium
command:  /infra-audit
class:    cost/scale-ceiling-absent
detector: iac-cost-scan §8
anchor:     scaleTargetRef:
match:    maxReplicaCount|max|ceiling|100|unbounded
```

KEDA default 100 (`THR-SCALE-CEILING`). Fix: write the max. Proof: V261.

## IO-CO-08b — The batch ASG ceiling is 1000 instances

```defect
id:       IO-CO-08b
file:     iac/envs/prod/compute.tf
line:     28
severity: medium
command:  /infra-audit
class:    cost/scale-ceiling-unreviewed
detector: iac-cost-scan §8
anchor:   max_size            = 1000
match:    max_size|1000|ceiling|ASG|unbounded
```

1000 × c7g.2xlarge × 730 h with no load test behind it. Fix: a reviewed ceiling. Proof: V261.

## IO-K8-PDBa — A `minAvailable: 1` PDB on a one-replica Deployment

```defect
id:       IO-K8-PDBa
file:     k8s/base/dispatch.yaml
line:     64
severity: high
command:  /infra-audit
class:    k8s/pdb-blocks-drain
detector: k8s-availability-scan §3
anchor:     minAvailable: 1
match:    PDB|disruption|drain|minAvailable|evict
```

disruptionsAllowed 0: every node drain gets 429. Fix: 2 replicas + `maxUnavailable: 1`. Proof: V268.

## IO-K8-PDBb — The notifier PDB blocks drains at the KEDA floor of 1

```defect
id:       IO-K8-PDBb
file:     k8s/base/notifier.yaml
line:     51
severity: high
command:  /infra-audit
class:    k8s/pdb-blocks-drain-keda-floor
detector: k8s-availability-scan §3
anchor:     minAvailable: 1
match:    PDB|disruption|drain|KEDA|floor|minReplicaCount
```

KEDA `minReplicaCount: 1` is the floor (precedents § 42). Fix: floor 2 or `maxUnavailable: 1`. Proof: V268.

## IO-K8-HRa — The hand-applied search Deployment pins `replicas: 2` under an HPA

```defect
id:       IO-K8-HRa
file:     k8s/platform/search.yaml
line:     9
severity: high
command:  /infra-audit
class:    k8s/replicas-beside-hpa
detector: k8s-availability-scan §4
anchor:     replicas: 2
match:    replicas|HPA|autoscal|reset
```

Every runbook apply resets the scaled count. Fix: omit `replicas`. Proof: V269.

## IO-K8-HRb — nginx-edge pins `replicas: 3` under its HPA

```defect
id:       IO-K8-HRb
file:     edge/k8s/nginx-edge.yaml
line:     9
severity: high
command:  /infra-audit
class:    k8s/replicas-beside-hpa
detector: k8s-availability-scan §4
anchor:     replicas: 3
match:    replicas|HPA|autoscal|reset
```

Fix: omit `replicas`. Proof: V269.

## IO-K8-NRa — The web HPA scales on CPU; the container requests no CPU

```defect
id:       IO-K8-NRa
file:     k8s/base/web.yaml
line:     75
severity: high
command:  /infra-audit
class:    k8s/hpa-no-cpu-request
detector: k8s-availability-scan §4
anchor:           name: cpu
match:    request|cpu|ScalingActive|never scales|HPA
```

`ScalingActive=False`. Fix: `requests.cpu`. Proof: V269.

## IO-K8-NRb — pricing's KEDA `cpu` trigger has no CPU request

```defect
id:       IO-K8-NRb
file:     k8s/base/pricing.yaml
line:     67
severity: high
command:  /infra-audit
class:    k8s/keda-cpu-no-request
detector: k8s-availability-scan §4
anchor:   kind: ScaledObject
match:    request|cpu|trigger|never scales|KEDA
```

Fix: `requests.cpu`. Proof: V269.

## IO-K8-PSa — courier-tracker's liveness and readiness call the same `/healthz`

```defect
id:       IO-K8-PSa
file:     k8s/base/courier-tracker.yaml
line:     38
severity: low
command:  /infra-audit
class:    k8s/probe-same
detector: k8s-availability-scan §2
anchor:             livenessProbe:
match:    liveness|readiness|same|probe|healthz
```

Shallow, so low (precedents § 11). Fix: separate liveness. Proof: V267.

## IO-K8-PSb — The storefront chart wires both probes to `.Values.probes.path`

```defect
id:       IO-K8-PSb
file:     k8s/chart/templates/deployment.yaml
line:     36
severity: low
command:  /infra-audit
class:    k8s/probe-same
detector: k8s-availability-scan §2
anchor:             livenessProbe:
match:    liveness|readiness|same|probe|status
```

Fix: separate paths. Proof: V267.

## IO-K8-SGa — checkout: preStop 10 + drain 60 + 5 > grace 30

```defect
id:       IO-K8-SGa
file:     k8s/base/checkout.yaml
line:     34
severity: high
command:  /infra-audit
class:    k8s/shutdown-grace
detector: k8s-availability-scan §7
anchor:               - name: SHUTDOWN_DRAIN_SECONDS
match:    grace|terminationGracePeriod|drain|preStop|SIGKILL|75
```

SIGKILL mid-drain on payments (`THR-SHUTDOWN-GRACE`). Fix: grace 80. Proof: V272.

## IO-K8-SGb — dispatch: preStop 10 + the code's 40 s drain + 5 > grace 30

```defect
id:       IO-K8-SGb
file:     k8s/base/dispatch.yaml
line:     17
severity: high
command:  /infra-audit
class:    k8s/shutdown-grace-code-constant
detector: k8s-availability-scan §7
anchor:   terminationGracePeriodSeconds: 30
match:    grace|drain|DRAIN_TIMEOUT|40|SIGKILL|constant
```

`DRAIN_TIMEOUT_MS = 40_000` in `edge/api/dispatch-worker.ts` (precedents § 46). Fix: grace 60. Proof: V272.

## IO-K8-CRa — Partner allowlist edits never reach nginx until someone bumps a counter

```defect
id:       IO-K8-CRa
file:     edge/k8s/partner-gateway.yaml
line:     16
severity: medium
command:  /infra-audit
class:    k8s/config-roll-partial
detector: k8s-wiring-scan §1
anchor:   larder.io/config-revision: "14"
match:    config|revision|roll|reload|allowlist|ConfigMap
```

Hand-bumped revision = partial control on an operational lever (precedents § 43). Fix: Reloader or hash suffix. Proof: V274.

## IO-K8-CRb — The storefront chart's ConfigMap has no checksum annotation

```defect
id:       IO-K8-CRb
file:     k8s/chart/templates/deployment.yaml
line:     33
severity: medium
command:  /infra-audit
class:    k8s/config-roll-none
detector: k8s-wiring-scan §1
anchor:                   name: {{ .Release.Name }}-config
match:    checksum|config|roll|ConfigMap|restart
```

Flag changes never restart the pods. Fix: `checksum/config`. Proof: V274.

## IO-K8-SPa — courier-tracker's Service targets an undeclared port name

```defect
id:       IO-K8-SPa
file:     k8s/base/courier-tracker.yaml
line:     63
severity: high
command:  /infra-audit
class:    k8s/service-target-port
detector: k8s-wiring-scan §2
anchor:         targetPort: tracker-http
match:    targetPort|port|endpoint|tracker-http
```

No endpoints. Fix: `targetPort: http`. Proof: V275.

## IO-K8-SPb — The storefront Service targets port `web`; the container names it `http`

```defect
id:       IO-K8-SPb
file:     k8s/chart/templates/service.yaml
line:     11
severity: high
command:  /infra-audit
class:    k8s/service-target-port
detector: k8s-wiring-scan §2
anchor:         targetPort: web
match:    targetPort|port|endpoint|web
```

Fix: `targetPort: http`. Proof: V275.

## IO-K8-NPa — pricing's egress policy allows port 53 over TCP only

```defect
id:       IO-K8-NPa
file:     k8s/base/netpol.yaml
line:     19
severity: high
command:  /infra-audit
class:    k8s/netpol-dns
detector: k8s-wiring-scan §3
anchor:           - port: 53
match:    DNS|53|UDP|lookup
```

Protocol unset = TCP: UDP lookups fail. Fix: UDP+TCP 53. Proof: V276.

## IO-K8-NPb — The backup namespace's egress policy has no DNS rule

```defect
id:       IO-K8-NPb
file:     dr/k8s/netpol.yaml
line:     5
severity: high
command:  /infra-audit
class:    k8s/netpol-dns
detector: k8s-wiring-scan §3
anchor:     name: backup-egress
match:    DNS|53|lookup|egress
```

The dump cannot resolve the DB or S3. Fix: allow 53. Proof: V276.

## IO-K8-ARa — A `batch/v1beta1` CronJob on a 1.36 cluster

```defect
id:       IO-K8-ARa
file:     k8s/platform/legacy-cronjob.yaml
line:     1
severity: critical
command:  /infra-audit
class:    k8s/api-removed
detector: k8s-api-version-scan §1
anchor:   apiVersion: batch/v1beta1
match:    v1beta1|removed|1\.25|apiVersion
```

Removed in 1.25: the apply fails. Fix: `batch/v1`. Proof: V279.

## IO-K8-ARb — A `networking.k8s.io/v1beta1` Ingress

```defect
id:       IO-K8-ARb
file:     edge/k8s/ingress.yaml
line:     1
severity: critical
command:  /infra-audit
class:    k8s/api-removed
detector: k8s-api-version-scan §1
anchor:   apiVersion: networking.k8s.io/v1beta1
match:    v1beta1|removed|1\.22|apiVersion|Ingress
```

Removed in 1.22. Fix: `networking.k8s.io/v1`. Proof: V279.

## IO-K8-PNa — The prod patch targets `checkout-api`; the base names it `checkout`

```defect
id:       IO-K8-PNa
file:     k8s/overlays/prod/kustomization.yaml
line:     17
severity: high
command:  /infra-audit
class:    k8s/kustomize-patch-noop
detector: k8s-render-scan §3
anchor:         name: checkout-api
match:    patch|no-?op|target|checkout-api|matches nothing
```

Applies nothing, exit 0. Fix: `name: checkout`. Proof: V263.

## IO-K8-PNb — The prod HPA patch targets `web-hpa`; the HPA is `web`

```defect
id:       IO-K8-PNb
file:     k8s/overlays/prod/kustomization.yaml
line:     24
severity: high
command:  /infra-audit
class:    k8s/kustomize-patch-noop
detector: k8s-render-scan §3
anchor:         name: web-hpa
match:    patch|no-?op|target|web-hpa|matches nothing
```

Fix: `name: web`. Proof: V263.

## IO-K8-HVa — values-prod.yaml says `resource:`; the template reads `.Values.resources`

```defect
id:       IO-K8-HVa
file:     k8s/chart/values-prod.yaml
line:     3
severity: high
command:  /infra-audit
class:    k8s/helm-value-unused
detector: k8s-render-scan §1
anchor:   resource:
match:    resource|typo|unused|values|ignored
```

Prod sizing is silently dropped. Fix: the key + `values.schema.json`. Proof: V262.

## IO-K8-HVb — `pdb:` in values-prod.yaml reaches no template

```defect
id:       IO-K8-HVb
file:     k8s/chart/values-prod.yaml
line:     9
severity: medium
command:  /infra-audit
class:    k8s/helm-value-unused
detector: k8s-render-scan §1
anchor:   pdb:
match:    pdb|unused|template|PodDisruptionBudget
```

No PDB renders (K-PDB-MISSING corroborates). Fix: a PDB template. Proof: V262.

## IO-K8-GRa — Argo selfHeal resets pricing's KEDA-scaled replicas

```defect
id:       IO-K8-GRa
file:     k8s/argo/larder-prod.yaml
line:     18
severity: high
command:  /infra-audit
class:    k8s/gitops-replicas
detector: k8s-render-scan §4
anchor:         selfHeal: true
match:    selfHeal|replicas|Argo|reset|ignoreDifferences
```

The prod render carries `replicas: 2` under a ScaledObject. Fix: omit replicas. Proof: V266.

## IO-K8-GRb — `ignoreDifferences` on replicas without `RespectIgnoreDifferences=true`

```defect
id:       IO-K8-GRb
file:     k8s/argo/larder-storefront.yaml
line:     26
severity: high
command:  /infra-audit
class:    k8s/gitops-replicas-ignore-only
detector: k8s-render-scan §4
anchor:         selfHeal: true
match:    RespectIgnoreDifferences|ignoreDifferences|replicas|selfHeal
```

Hidden diff, replicas still reset (precedents § 14). Fix: add the option. Proof: V266.

## IO-K8-SFa — Traefik, the only ingress controller, runs at chart-default replicas

```defect
id:       IO-K8-SFa
file:     k8s/ops/runbooks/platform.md
line:     24
severity: high
command:  /infra-audit
class:    k8s/platform-spof
detector: k8s-availability-scan §9
anchor:   helm upgrade --install traefik traefik/traefik --version 37.1.2 -n traefik --create-namespace
match:    replica|SPOF|single|PDB|Traefik|ingress
```

Fix: 2+ replicas, a PDB, spread. Proof: V273.

## IO-K8-SFb — The KEDA operator runs at chart defaults

```defect
id:       IO-K8-SFb
file:     k8s/ops/runbooks/platform.md
line:     27
severity: medium
command:  /infra-audit
class:    k8s/platform-spof
detector: k8s-availability-scan §9
anchor:   helm upgrade --install keda kedacore/keda --version 2.18.1 -n keda --create-namespace
match:    replica|SPOF|single|PDB|KEDA|operator
```

Every ScaledObject stops scaling when its pod is evicted. Fix: 2 replicas + PDB. Proof: V273.

## IO-K8-RBa — courier-tracker runs as a ServiceAccount nothing creates

```defect
id:       IO-K8-RBa
file:     k8s/base/courier-tracker.yaml
line:     17
severity: high
command:  /infra-audit
class:    k8s/rbac-sa-missing
detector: k8s-wiring-scan §6
anchor:         serviceAccountName: courier-sync
match:    ServiceAccount|courier-sync|not found|missing
```

Pods are rejected. Fix: render it. Proof: V278.

## IO-K8-RBb — A RoleBinding points at a Role that does not exist

```defect
id:       IO-K8-RBb
file:     k8s/base/rbac.yaml
line:     8
severity: high
command:  /infra-audit
class:    k8s/rbac-dangling-roleref
detector: k8s-wiring-scan §6
anchor:     name: pod-reader
match:    roleRef|pod-reader|dangling|Role|missing
```

Fix: render `Role/pod-reader`. Proof: V278.

## IO-ED-01a — Reports get 30 s at the edge; the api allows 120 s

```defect
id:       IO-ED-01a
file:     edge/nginx/nginx.conf
line:     41
severity: high
command:  /infra-audit
class:    edge/timeout-chain
detector: edge-reliability-scan §1
anchor:   proxy_read_timeout 30s;
match:    timeout|30 ?s|report|504
```

504 on reports that finish. Fix: above the route's p99. Proof: V282.

## IO-ED-01b — Caddy waits 20 s for export headers; exports take up to 90 s

```defect
id:       IO-ED-01b
file:     edge/caddy/shop.caddy
line:     29
severity: high
command:  /infra-audit
class:    edge/timeout-chain
detector: edge-reliability-scan §1
anchor:   response_header_timeout 20s
match:    timeout|20 ?s|export|504
```

Fix: raise it. Proof: V282.

## IO-ED-02a — nginx closes idle clients at 30 s behind a 60 s ALB

```defect
id:       IO-ED-02a
file:     edge/nginx/nginx.conf
line:     25
severity: medium
command:  /infra-audit
class:    edge/keepalive-inversion
detector: edge-reliability-scan §2
anchor:           keepalive_timeout 30s;
match:    keepalive|keep-alive|idle|60|502
```

Random 502 at low traffic. Fix: > 60 s. Proof: V283.

## IO-ED-02b — Caddy keeps upstream connections 120 s; the storefront closes them at 5 s

```defect
id:       IO-ED-02b
file:     edge/caddy/shop.caddy
line:     35
severity: medium
command:  /infra-audit
class:    edge/keepalive-inversion
detector: edge-reliability-scan §2
anchor:   keepalive 120s
match:    keepalive|keep-alive|idle|5 ?s|502
```

Fix: Node above Caddy's idle. Proof: V283.

## IO-ED-03a — `non_idempotent` lets nginx re-send order POSTs

```defect
id:       IO-ED-03a
file:     edge/nginx/nginx.conf
line:     50
severity: high
command:  /infra-audit
class:    edge/non-idempotent-retry
detector: edge-reliability-scan §3
anchor:   proxy_next_upstream error timeout non_idempotent;
match:    non_idempotent|retry|POST|duplicate
```

Duplicate orders. Fix: drop it. Proof: V284.

## IO-ED-03b — Caddy retries partner order POSTs

```defect
id:       IO-ED-03b
file:     edge/caddy/api.caddy
line:     20
severity: high
command:  /infra-audit
class:    edge/non-idempotent-retry
detector: edge-reliability-scan §3
anchor:   method POST
match:    lb_retry_match|retry|POST|duplicate
```

`lb_retry_match { method POST }` (precedents § 48). Fix: remove POST. Proof: V284.

## IO-ED-07a — A variable `proxy_pass` with no `resolver`

```defect
id:       IO-ED-07a
file:     edge/nginx/partner-gateway.conf
line:     40
severity: high
command:  /infra-audit
class:    edge/no-resolver
detector: edge-reliability-scan §5
anchor:   proxy_pass https://$quotes_backend;
match:    resolver|variable|502|DNS
```

Every quote request 502s. Fix: a `resolver`. Proof: V285.

## IO-ED-07b — An NLB name resolved once at nginx start

```defect
id:       IO-ED-07b
file:     edge/nginx/partner-gateway.conf
line:     44
severity: high
command:  /infra-audit
class:    edge/static-dns
detector: edge-reliability-scan §5
anchor:   proxy_pass https://payouts-nlb-4f1c2a9e07.elb.eu-central-1.amazonaws.com;
match:    resolv|DNS|ELB|NLB|stale|once
```

NLB IPs change. Fix: resolver + variable. Proof: V285.

## IO-ED-08a — Order status SSE behind default proxy buffering

```defect
id:       IO-ED-08a
file:     edge/nginx/nginx.conf
line:     45
severity: high
command:  /infra-audit
class:    edge/sse-buffered
detector: edge-reliability-scan §6
anchor:   location /api/orders/stream {
match:    buffer|stream|SSE|event
```

Fix: `proxy_buffering off`. Proof: V286.

## IO-ED-08b — Partner events stream with buffering explicitly on

```defect
id:       IO-ED-08b
file:     edge/nginx/partner-gateway.conf
line:     48
severity: high
command:  /infra-audit
class:    edge/sse-buffered
detector: edge-reliability-scan §6
anchor:   proxy_buffering on;
match:    buffer|stream|events|SSE
```

Fix: off. Proof: V286.

## IO-ED-17a — Caddy `--watch` keeps the old config when a new one is invalid

```defect
id:       IO-ED-17a
file:     edge/k8s/caddy.yaml
line:     24
severity: high
command:  /infra-audit
class:    edge/silent-rejection
detector: edge-reliability-scan §13
anchor:   "--watch"]
match:    watch|reload|invalid|silent|keeps
```

Deploy reports success, change not live. Fix: validate with the project's image before replacing the ConfigMap. Proof: V287.

## IO-ED-17b — CI validates the Caddyfile with the stock image and `|| true`

```defect
id:       IO-ED-17b
file:     .github/workflows/edge.yml
line:     17
severity: high
command:  /infra-audit
class:    edge/validation-cannot-fail
detector: edge-reliability-scan §13
anchor:   caddy validate --config /etc/caddy/shop.caddy --adapter caddyfile || true
match:    validate|\|\| true|plugin|xcaddy|stock
```

Stock Caddy lacks the plugins (precedents § 49), so validation always fails and is ignored. Fix: the xcaddy image, no `|| true`. Proof: V287.

## IO-ED-21a — The API edge log has no request id and no upstream time

```defect
id:       IO-ED-21a
file:     edge/nginx/nginx.conf
line:     11
severity: low
command:  /infra-audit
class:    edge/access-log-no-request-id
detector: edge-reliability-scan §15
anchor:   access_log /dev/stdout main;
match:    request.?id|log|upstream_response_time
```

Fix: add `$request_id`, `$upstream_response_time`. Proof: V283.

## IO-ED-21b — Caddy's access log carries no request id

```defect
id:       IO-ED-21b
file:     edge/caddy/shop.caddy
line:     19
severity: low
command:  /infra-audit
class:    edge/access-log-no-request-id
detector: edge-reliability-scan §15
anchor:   	log {
match:    request.?id|log|uuid
```

Fix: mint/forward `{http.request.uuid}`. Proof: V283.

## IO-DN-03a — larder.example's CAA allows only DigiCert; cert-manager uses Let's Encrypt

```defect
id:       IO-DN-03a
file:     dns/terraform/route53.tf
line:     11
severity: high
command:  /infra-audit
class:    dns/caa-ca-mismatch
detector: dns-tls-lifecycle-scan §2
anchor:   records = ["0 issue \"digicert.com\""
match:    CAA|digicert|letsencrypt|issu
```

Every renewal fails CAA. Fix: add letsencrypt.org. Proof: V288.

## IO-DN-03b — The partners zone allows only Sectigo; Caddy pins Let's Encrypt

```defect
id:       IO-DN-03b
file:     dns/zones/larder-partners.example.zone
line:     8
severity: high
command:  /infra-audit
class:    dns/caa-ca-mismatch
detector: dns-tls-lifecycle-scan §2
anchor:   IN CAA   0 issue "sectigo.com"
match:    CAA|sectigo|letsencrypt|issu|acme_ca
```

`acme_ca` pins LE (precedents § 66 flip). Fix: allow letsencrypt.org. Proof: V288.

## IO-DN-05a — cert-manager certificates are watched for readiness only

```defect
id:       IO-DN-05a
file:     dns/monitoring/tls-rules.yaml
line:     13
severity: medium
command:  /infra-audit
class:    tls/no-expiry-signal
detector: dns-tls-lifecycle-scan §4
anchor:   certmanager_certificate_ready_status
match:    expir|ready|signal|alert|certmanager
```

A Certificate stays Ready while renewals fail. Fix: an expiry-timestamp alert (`THR-CERT-EXPIRY-ALERT`). Proof: V288.

## IO-DN-05b — The only expiry rule probes www through CloudFront

```defect
id:       IO-DN-05b
file:     dns/monitoring/tls-rules.yaml
line:     21
severity: medium
command:  /infra-audit
class:    tls/expiry-probe-reads-cdn
detector: dns-tls-lifecycle-scan §4
anchor:   probe_ssl_earliest_cert_expiry
match:    CDN|CloudFront|origin|probe|expir
```

Reads the CDN's cert (precedents § 65). Fix: probe the origins. Proof: V288.

## IO-DN-06a — Every preview issues a wildcard from Let's Encrypt production

```defect
id:       IO-DN-06a
file:     dns/cert-manager/overlays/preview/preview-certificate.yaml
line:     13
severity: medium
command:  /infra-audit
class:    tls/nonprod-on-prod-acme
detector: dns-tls-lifecycle-scan §5
anchor:       name: letsencrypt-prod
match:    preview|staging|letsencrypt-prod|rate limit|production
```

Spends the domain's rate limits. Fix: staging issuer. Proof: V288.

## IO-DN-06b — Per-PR preview Caddies issue from LE production

```defect
id:       IO-DN-06b
file:     edge/caddy/preview.caddy
line:     4
severity: medium
command:  /infra-audit
class:    tls/nonprod-on-prod-acme
detector: dns-tls-lifecycle-scan §5
anchor:   acme_ca https://acme-v02.api.letsencrypt.org/directory
match:    preview|staging|production|rate limit|acme
```

Fix: staging directory. Proof: V288.

## IO-NW-03a — The data NACL allows Postgres in and no replies out

```defect
id:       IO-NW-03a
file:     iac/envs/prod/nacl.tf
line:     10
severity: high
command:  /infra-audit
class:    network/nacl-return-path
detector: network-exposure-audit §1
anchor:   from_port  = 5432
match:    NACL|ephemeral|return|reply|egress
```

Egress 443 only: every app connection hangs. Fix: egress ephemeral to the app subnets. Proof: V289.

## IO-NW-03b — Outbound HTTPS from the public subnets, no inbound return rule

```defect
id:       IO-NW-03b
file:     iac/envs/prod/nacl.tf
line:     71
severity: high
command:  /infra-audit
class:    network/nacl-return-path
detector: network-exposure-audit §1
anchor:   resource "aws_network_acl_rule" "public_out_https" {
match:    NACL|ephemeral|return|reply|ingress
```

Fix: ingress 1024–65535. Proof: V289.

## IO-NW-07a — The analytics VPC reuses prod's 10.40.0.0/16 and peers with it

```defect
id:       IO-NW-07a
file:     iac/envs/analytics/main.tf
line:     29
severity: high
command:  /infra-audit
class:    network/cidr-overlap-peered
detector: network-exposure-audit §2
anchor:     cidr_block = "10.40.0.0/16"
match:    overlap|10\.40|peer|CIDR
```

AWS rejects the peering. Fix: a new range. Proof: V289.

## IO-NW-07b — The office VPN route sits inside the prod VPC range

```defect
id:       IO-NW-07b
file:     iac/envs/prod/vpn.tf
line:     21
severity: high
command:  /infra-audit
class:    network/cidr-overlap-vpn
detector: network-exposure-audit §2
anchor:   destination_cidr_block = "10.40.64.0/18"
match:    overlap|10\.40|VPN|CIDR|office
```

Fix: re-address. Proof: V289.

## IO-SEC-E4a — `/api/me` is cached with no identity in the key

```defect
id:       IO-SEC-E4a
file:     edge/nginx/nginx.conf
line:     55
severity: high
command:  /security-audit /infra-audit
class:    security/shared-cache-user-response
detector: iac-scan §6 (fallback edge-reliability-scan §4)
anchor:   proxy_cache api_cache;
match:    cache|user|identity|Authorization|another
```

One customer's profile served to the next. Fix: no cache or bypass on auth/cookie.

## IO-SEC-E4b — Partner account responses are cached by Caddy

```defect
id:       IO-SEC-E4b
file:     edge/caddy/api.caddy
line:     26
severity: high
command:  /security-audit /infra-audit
class:    security/shared-cache-user-response
detector: iac-scan §6 (fallback edge-reliability-scan §4)
anchor:   cache {
match:    cache|account|identity|Authorization|another
```

No key on the partner credential. Fix: remove it.

## IO-SEC-D1a — docs CNAME points at an S3 website bucket nothing declares

```defect
id:       IO-SEC-D1a
file:     dns/terraform/route53.tf
line:     30
severity: high
command:  /security-audit /infra-audit
class:    security/dangling-dns-takeover
detector: iac-scan §4 (fallback dns-tls-lifecycle-scan §7)
anchor:   records = ["larder-docs.s3-website.eu-central-1.amazonaws.com"]
match:    takeover|dangling|s3-website|bucket|claim
```

Claimable (D1). Fix: delete the record or own the bucket.

## IO-SEC-D1b — status CNAME points at a Heroku app name

```defect
id:       IO-SEC-D1b
file:     dns/terraform/cloudflare.tf
line:     11
severity: high
command:  /security-audit /infra-audit
class:    security/dangling-dns-takeover
detector: iac-scan §4 (fallback dns-tls-lifecycle-scan §7)
anchor:   content = "larder-status.herokuapp.com"
match:    takeover|dangling|heroku|claim
```

Claimable when the app is gone. Fix: remove or verify.

## IO-SEC-NPa — Every pod admits the whole VPC on every port

```defect
id:       IO-SEC-NPa
file:     k8s/base/netpol.yaml
line:     34
severity: medium
command:  /security-audit /infra-audit
class:    security/netpol-ipblock-wide
detector: iac-scan §3 (4k)
anchor:               cidr: 10.40.0.0/16
match:    ipBlock|10\.40|VPC|every port|wide
```

The real-repo shape. Fix: scraper selector + port.

## IO-SEC-NPb — The api admits 10.0.0.0/8

```defect
id:       IO-SEC-NPb
file:     k8s/base/netpol.yaml
line:     48
severity: medium
command:  /security-audit /infra-audit
class:    security/netpol-ipblock-wide
detector: iac-scan §3 (4k)
anchor:               cidr: 10.0.0.0/8
match:    ipBlock|10\.0\.0\.0/8|wide|VPN
```

Every VPC and the VPN bypass the edge. Fix: the edge namespace selector.

## IO-SEC-RBa — `larder-ops` grants `*` on `*` cluster-wide

```defect
id:       IO-SEC-RBa
file:     k8s/base/rbac.yaml
line:     20
severity: high
command:  /security-audit /infra-audit
class:    security/rbac-wildcard
detector: iac-scan §3
anchor:   verbs: ["*"]
match:    wildcard|\*|cluster-admin|verbs|RBAC
```

cluster-admin by another name. Fix: scoped roles.

## IO-SEC-RBb — Support can read every core resource, Secrets included

```defect
id:       IO-SEC-RBb
file:     k8s/base/support-rbac.yaml
line:     7
severity: high
command:  /security-audit /infra-audit
class:    security/rbac-wildcard
detector: iac-scan §3
anchor:   resources: ["*"]
match:    wildcard|\*|secrets|resources|RBAC
```

Fix: enumerate resources without secrets.

## IO-SEC-VKa — The internet-facing Caddy stores certificates with the app's Valkey user

```defect
id:       IO-SEC-VKa
file:     edge/caddy/shop.caddy
line:     12
severity: high
command:  /security-audit /infra-audit
class:    security/shared-store-credential
detector: iac-scan §3 (7f)
anchor:   username larder-app
match:    valkey|redis|shared|credential|larder-app|edge
```

Edge compromise writes app sessions; app compromise reads edge keys. Fix: a scoped ACL user + storage encryption.

## IO-SEC-VKb — The Caddy DaemonSet mounts the api's `valkey-app` Secret

```defect
id:       IO-SEC-VKb
file:     edge/k8s/caddy.yaml
line:     34
severity: high
command:  /security-audit /infra-audit
class:    security/shared-store-credential
detector: iac-scan §3 (7f)
anchor:                     name: valkey-app
match:    valkey|secret|shared|credential|edge
```

Same credential in two trust zones. Fix: its own Secret.

## IO-SEC-ECa — The checkout ECR repository allows tag overwrite

```defect
id:       IO-SEC-ECa
file:     iac/envs/prod/ecr.tf
line:     3
severity: medium
command:  /security-audit /infra-audit
class:    security/registry-tag-mutable
detector: iac-scan §4 (4j registry variant)
anchor:   image_tag_mutability = "MUTABLE"
match:    MUTABLE|tag|immutab|registry|ECR
```

Fix: `IMMUTABLE`.

## IO-SEC-ECb — checkout deploys by a mutable tag

```defect
id:       IO-SEC-ECb
file:     k8s/base/checkout.yaml
line:     27
severity: medium
command:  /security-audit /infra-audit
class:    security/deploy-by-mutable-tag
detector: iac-scan §3 (4j)
anchor:   image: registry.larder.example/larder/checkout:release-2026.10
match:    tag|digest|mutable|release-2026
```

Every other image is digest-pinned. Fix: a digest.

## Decoys — must NOT be reported

Each decoy is the correct sibling of a seeded defect, in the same platform, built from the eval's decoy list (§ 3.6,
items 1–32 in order: 1–8 from the real-repo shapes, 9–30 from the research, 31–32 routing decoys) and
`precedents/infrastructure.md`. How they score (`score.py`, § DECOYS): a finding that names the decoy's file, cites a line
within the tolerance window and matches every one of the decoy's `match:` patterns is **pinned** to it, removed before
defect assignment, and reported as `DECOYS FLAGGED k/N`. Every decoy sits more than 12 lines from any defect in its file
(`--verify` enforces it). `IO-DECOY-20` also probes `/security-audit` (a CloudFront CNAME is not a takeover). The routing
decoys: 31 (a devops-owned compose service) must not be graded by infra; 32 (a liveness on `/health/db`) must print only
`route → performance request-path-scan §15`.

| id | file:line | looks like | why it is safe |
|----|-----------|-----------|----------------|
| IO-DECOY-01 | `k8s/base/worker.yaml:60` | IO-K8-PDBb | KEDA `minReplicaCount: 2` is the floor: one disruption allowed (precedents § 42) |
| IO-DECOY-02 | `edge/caddy/api.caddy:6` | IO-ED-03b | `lb_try_duration` without `lb_retry_match` never re-sends a write (precedents § 48) |
| IO-DECOY-03 | `edge/api/server.ts:9` | IO-ED-02b | 72 s exceeds nginx's 60 s upstream keepalive: the proxy closes first (real-repo shape, adapted to the fixture's nginx) |
| IO-DECOY-04 | `k8s/base/api.yaml:17` | IO-K8-SGa | preStop 10 + `SHUTDOWN_DRAIN_TIMEOUT_MS` 30 + 5 = 45 = grace (precedents § 46) |
| IO-DECOY-05 | `k8s/base/migrate-job.yaml:9` | (K-JOB) | documented: Argo deletes the hook Job (BeforeHookCreation) |
| IO-DECOY-06 | `dr/runbooks/restore-ledger.md:9` | IO-DR-R10a | ≤ 90 days, new target, job id, counts, 41 min vs a 1 h RTO |
| IO-DECOY-07 | `edge/k8s/caddy.yaml:85` | IO-K8-PDBa | a PDB on a DaemonSet never blocks a drain (precedents § 4) |
| IO-DECOY-08 | `k8s/overlays/trial-single-node/kustomization.yaml:9` | (K-SPREAD) | single-node trial with a written exit condition (precedents § 8, § 47) |
| IO-DECOY-09a | `k8s/base/api.yaml:51` | (CPU limit) | no CPU limit with requests set is correct (precedents § 1) |
| IO-DECOY-09b | `k8s/base/worker.yaml:33` | (CPU limit) | precedents § 1 |
| IO-DECOY-09c | `k8s/base/media.yaml:39` | (CPU limit) | precedents § 1 |
| IO-DECOY-10 | `k8s/base/api.yaml:29` | (K-PULLPOLICY) | digest-pinned image (precedents § 9, § 50) |
| IO-DECOY-11 | `k8s/base/web.yaml:8` | IO-K8-HRa | HPA-managed, replicas omitted (precedents § 6) |
| IO-DECOY-12 | `iac/envs/prod/debug.tf:11` | IO-LC-05a | a conditional count is not index churn (precedents § 26) |
| IO-DECOY-13 | `iac/envs/ci-ephemeral/main.tf:36` | IO-LC-D1b | per-PR database with a TTL tag (precedents § 18) |
| IO-DECOY-14 | `serverless/terraform/main.tf:162` | IO-SL-03a | SQS-polled: the DLQ is on the source queue (precedents § 19) |
| IO-DECOY-15 | `iac/envs/prod/network.tf:61` | IO-CO-01a | NAT per AZ in prod is AZ isolation (precedents § 23) |
| IO-DECOY-16 | `iac/envs/prod/eks.tf:5` | (R9) | managed control plane (precedents § 37) |
| IO-DECOY-17 | `dr/velero/schedule-config.yaml:11` | IO-DR-R6a | the namespace holds no volumes (precedents § 37) |
| IO-DECOY-18 | `edge/caddy/events.caddy:2` | IO-ED-08a | Caddy flushes text/event-stream immediately (precedents § 30; the eval's ingress-nginx shape adapted) |
| IO-DECOY-19 | `edge/nginx/nginx.conf:72` | IO-ED-07b | a ClusterIP Service name is stable (precedents § 32) |
| IO-DECOY-20 | `dns/terraform/route53.tf:54` | IO-SEC-D1a | a CloudFront CNAME is not claimable (precedents § 39) |
| IO-DECOY-21 | `dns/zones/larder-mail.example.zone:4` | IO-DN-03a | no CAA on a mail-only zone is LOW (precedents § 36) |
| IO-DECOY-22 | `iac/envs/prod/ecs.tf:9` | IO-LC-06a | autoscaler-owned field (precedents § 25) |
| IO-DECOY-23 | `iac/envs/staging/main.tf:23` | IO-ST-04a | a tag pin is Hardening without a SHA policy (precedents § 27) |
| IO-DECOY-24 | `iac/envs/prod/refactor.tf:3` | IO-LC-07a | hand-off recorded in ADR 0012, imported by the search state |
| IO-DECOY-25 | `k8s/argo/larder-dev.yaml:26` | IO-K8-GRb | `ignoreDifferences` + `RespectIgnoreDifferences=true` (precedents § 14) |
| IO-DECOY-26 | `k8s/base/kustomization.yaml:21` | IO-K8-CRb | hash-suffixed generator (precedents § 13) |
| IO-DECOY-27 | `k8s/base/scheduler.yaml:10` | (K-STATEFUL-RECREATE) | leader-elected singleton (precedents § 5) |
| IO-DECOY-28 | `serverless/terraform/apigw.tf:31` | IO-ED-01a | Regional REST with the raised quota (precedents § 24, QUOTAS.md) |
| IO-DECOY-29 | `iac/envs/prod/security-groups.tf:9` | (N2) | default SG egress (precedents § 41) |
| IO-DECOY-30 | `dr/terraform/archive.tf:22` | IO-DR-R4a | the compliance-mode vault lock beside it is the control (precedents § 38) |
| IO-DECOY-31 | `edge/docker-compose.yml:6` | (devops compose) | a devops-owned local compose: infra must not grade it |
| IO-DECOY-32 | `k8s/base/loyalty.yaml:31` | (route) | routed to performance request-path-scan §15, never an infra finding |

```decoy
id:       IO-DECOY-01
file:     k8s/base/worker.yaml
line:     60
command:  /infra-audit
class:    decoy/IO-K8-PDBb
anchor:     minAvailable: 1
match:    PDB|drain|disruption
```

```decoy
id:       IO-DECOY-02
file:     edge/caddy/api.caddy
line:     6
command:  /infra-audit
class:    decoy/IO-ED-03b
anchor:   lb_try_duration 5s
match:    retry|POST|duplicate|non.?idempotent
```

```decoy
id:       IO-DECOY-03
file:     edge/api/server.ts
line:     9
command:  /infra-audit
class:    decoy/IO-ED-02b
anchor:     keepAliveTimeout: 72_000,
match:    keep.?alive|idle|502
```

```decoy
id:       IO-DECOY-04
file:     k8s/base/api.yaml
line:     17
command:  /infra-audit
class:    decoy/IO-K8-SGa
anchor:         terminationGracePeriodSeconds: 45
match:    grace|drain|SIGKILL|shutdown
```

```decoy
id:       IO-DECOY-05
file:     k8s/base/migrate-job.yaml
line:     9
command:  /infra-audit
class:    decoy/K-JOB
anchor:     # no ttlSecondsAfterFinished on purpose
match:    ttl|ttlSecondsAfterFinished|cleanup
```

```decoy
id:       IO-DECOY-06
file:     dr/runbooks/restore-ledger.md
line:     9
command:  /infra-audit
class:    decoy/IO-DR-R10a
anchor:   - 2026-09-14: restored snapshot rds:larder-ledger-2026-09-14-03-10
match:    drill|restore|evidence|stale
```

```decoy
id:       IO-DECOY-07
file:     edge/k8s/caddy.yaml
line:     85
command:  /infra-audit
class:    decoy/IO-K8-PDBa
anchor:     minAvailable: 2
match:    PDB|drain|disruption
```

```decoy
id:       IO-DECOY-08
file:     k8s/overlays/trial-single-node/kustomization.yaml
line:     9
command:  /infra-audit
class:    decoy/K-SPREAD
anchor:   # single node: a hostname spread constraint has one domain here
match:    spread|topology|single|anti.?affinity
```

```decoy
id:       IO-DECOY-09a
file:     k8s/base/api.yaml
line:     51
command:  /infra-audit
class:    decoy/CPU limit
anchor:                 cpu: 250m
match:    cpu limit|limits\.cpu|throttl
```

```decoy
id:       IO-DECOY-09b
file:     k8s/base/worker.yaml
line:     33
command:  /infra-audit
class:    decoy/CPU limit
anchor:                 cpu: 500m
match:    cpu limit|limits\.cpu|throttl
```

```decoy
id:       IO-DECOY-09c
file:     k8s/base/media.yaml
line:     39
command:  /infra-audit
class:    decoy/CPU limit
anchor:                 cpu: 300m
match:    cpu limit|limits\.cpu|throttl
```

```decoy
id:       IO-DECOY-10
file:     k8s/base/api.yaml
line:     29
command:  /infra-audit
class:    decoy/K-PULLPOLICY
anchor:             imagePullPolicy: IfNotPresent
match:    pull.?policy|Always|IfNotPresent
```

```decoy
id:       IO-DECOY-11
file:     k8s/base/web.yaml
line:     8
command:  /infra-audit
class:    decoy/IO-K8-HRa
anchor:     # replicas omitted: the HorizontalPodAutoscaler below owns the count
match:    replicas|single|one replica
```

```decoy
id:       IO-DECOY-12
file:     iac/envs/prod/debug.tf
line:     11
command:  /infra-audit
class:    decoy/IO-LC-05a
anchor:     count         = var.enable_debug_host ? 1 : 0
match:    count|index|for_each
```

```decoy
id:       IO-DECOY-13
file:     iac/envs/ci-ephemeral/main.tf
line:     36
command:  /infra-audit
class:    decoy/IO-LC-D1b
anchor:     skip_final_snapshot      = true
match:    final.?snapshot|deletion|backup|retention
```

```decoy
id:       IO-DECOY-14
file:     serverless/terraform/main.tf
line:     162
command:  /infra-audit
class:    decoy/IO-SL-03a
anchor:     function_name                  = "larder-ingest"
match:    dead.?letter|dlq
```

```decoy
id:       IO-DECOY-15
file:     iac/envs/prod/network.tf
line:     61
command:  /infra-audit
class:    decoy/IO-CO-01a
anchor:   resource "aws_nat_gateway" "az" {
match:    NAT|per.?AZ
```

```decoy
id:       IO-DECOY-16
file:     iac/envs/prod/eks.tf
line:     5
command:  /infra-audit
class:    decoy/R9
anchor:   resource "aws_eks_cluster" "main" {
match:    etcd|snapshot
```

```decoy
id:       IO-DECOY-17
file:     dr/velero/schedule-config.yaml
line:     11
command:  /infra-audit
class:    decoy/IO-DR-R6a
anchor:       snapshotVolumes: false
match:    snapshotVolumes|volume|PV
```

```decoy
id:       IO-DECOY-18
file:     edge/caddy/events.caddy
line:     2
command:  /infra-audit
class:    decoy/IO-ED-08a
anchor:   reverse_proxy /events/* storefront-events.larder.svc.cluster.local:80
match:    buffer|flush|SSE|stream
```

```decoy
id:       IO-DECOY-19
file:     edge/nginx/nginx.conf
line:     72
command:  /infra-audit
class:    decoy/IO-ED-07b
anchor:   proxy_pass http://catalog.larder.svc.cluster.local:8080;
match:    resolv|DNS|stale|once
```

```decoy
id:       IO-DECOY-20
file:     dns/terraform/route53.tf
line:     54
command:  /infra-audit /security-audit
class:    decoy/IO-SEC-D1a
anchor:   records = ["d2x7k4m9q1w3e5.cloudfront.net"]
match:    takeover|dangling|claim
```

```decoy
id:       IO-DECOY-21
file:     dns/zones/larder-mail.example.zone
line:     4
command:  /infra-audit
class:    decoy/IO-DN-03a
anchor:   @        IN SOA   ns1.larder.example.
match:    CAA
```

```decoy
id:       IO-DECOY-22
file:     iac/envs/prod/ecs.tf
line:     9
command:  /infra-audit
class:    decoy/IO-LC-06a
anchor:   ignore_changes = [desired_count]
match:    ignore_changes|drift
```

```decoy
id:       IO-DECOY-23
file:     iac/envs/staging/main.tf
line:     23
command:  /infra-audit
class:    decoy/IO-ST-04a
anchor:   source = "git::https://github.com/larder-platform/tf-modules.git//vpc?ref=v1.4.0"
match:    ref=|tag|pin|mutable
```

```decoy
id:       IO-DECOY-24
file:     iac/envs/prod/refactor.tf
line:     3
command:  /infra-audit
class:    decoy/IO-LC-07a
anchor:   removed {
match:    removed|orphan|destroy = false
```

```decoy
id:       IO-DECOY-25
file:     k8s/argo/larder-dev.yaml
line:     26
command:  /infra-audit
class:    decoy/IO-K8-GRb
anchor:         - RespectIgnoreDifferences=true
match:    selfHeal|replicas|ignoreDifferences
```

```decoy
id:       IO-DECOY-26
file:     k8s/base/kustomization.yaml
line:     21
command:  /infra-audit
class:    decoy/IO-K8-CRb
anchor:     - name: api-config
match:    config|roll|restart|checksum
```

```decoy
id:       IO-DECOY-27
file:     k8s/base/scheduler.yaml
line:     10
command:  /infra-audit
class:    decoy/K-STATEFUL-RECREATE
anchor:       type: Recreate
match:    single|replica|Recreate|PDB|spof
```

```decoy
id:       IO-DECOY-28
file:     serverless/terraform/apigw.tf
line:     31
command:  /infra-audit
class:    decoy/IO-ED-01a
anchor:     timeout_milliseconds    = 45000
match:    29|timeout|integration
```

```decoy
id:       IO-DECOY-29
file:     iac/envs/prod/security-groups.tf
line:     9
command:  /infra-audit
class:    decoy/N2
anchor:       cidr_blocks = ["0.0.0.0/0"]
match:    0\.0\.0\.0|egress
```

```decoy
id:       IO-DECOY-30
file:     dr/terraform/archive.tf
line:     22
command:  /infra-audit
class:    decoy/IO-DR-R4a
anchor:         mode = "GOVERNANCE"
match:    governance|immutab|object lock
```

```decoy
id:       IO-DECOY-31
file:     edge/docker-compose.yml
line:     6
command:  /infra-audit
class:    decoy/devops compose
anchor:       restart: always
match:    healthcheck|restart
```

```decoy
id:       IO-DECOY-32
file:     k8s/base/loyalty.yaml
line:     31
command:  /infra-audit
class:    decoy/route
anchor:                 path: /health/db
match:    liveness|health/db|dependency
```

## Detector measurement — the pre-flights run on this fixture

Measured 2026-10-10 with ripgrep 15.2.0, `/bin/bash` 3.2.57 (stdin `/dev/null`), jq 1.7.1, yq 4.54.1, kustomize 5.8.3,
helm 4.2.4, kubeconform 0.8.0, pluto 5.24.4 and Python 3, in a staged copy (this key removed, `git init` + one commit, as
`Stage with: --git` does) with the eight script directories copied to `.claude/skills/<skill>/scripts/`. Each skill's
pre-flight block was copied verbatim from its `SKILL.md` as of that date. The only edits: `k8s-render-scan` § 0's
`SCAN="$(mktemp …)"` line pointed at the harness's scan dir (so every detector reads the same render), the placeholder
`<target minor>` filled with `1.36.0` (`kubernetes_version` in `iac/envs/prod/eks.tf`), `apiversion.sh`'s
`TARGET="<oldest>,<newest>"` set to `1.36`, and `--fetch-schemas` replaced by `--schemas=<local dir>` (16 core v1.36 schemas
fetched once before the run; no CRD schemas). The plan joins (`plan-joins.jq`, `serverless.jq`, `cost.jq`) ran on each
committed plan copied to `$SCAN/plan.json`. `KUBECONFIG` pointed at an empty scratch file in every shell; no cloud
credential was set; no cluster, kind, docker or Terraform binary was used. Every script exited without a stderr error
line, the scripts wrote nothing in the copy (`git status`: only the installed `.claude/`), and the whole set ran in ~8 s.

Render (`render.sh`): 18 envs, 251 objects, 0 failed, 0 stderr lines — `k8s/base` and its three overlays, the
cert-manager `issuers`/`base`/`overlays/{prod,preview}` roots and `dr/k8s` all build offline with `kustomize build`;
2 chart envs + 1 Argo env (`argo__larder-storefront`, values-prod); 6 raw envs. Inventory: 7 `helm` lines (1 UNPINNED),
9 `kubectl apply` lines. CD targets: 4 (3 mapped to an env). kubeconform read **253 / 253** (251 + 2 canaries): 209 valid;
the removed-API canary `statusError`, the `n` canary read as `false` (YAML 1.1); 42 objects `K-SCHEMA-MISSING`
(every CRD kind — Argo, cert-manager, KEDA, Velero, CNPG, zalando, Probe — plus Namespace/RBAC/ServiceAccount: no local
schema), i.e. NOT-RUN for those kinds. pluto: the two removed APIs + the canary.

A seed is **caught** when its owner's output prints its file at a line within 6 of the anchor, prints the object or plan
address the row names (Kustomize rows cite the document's first line; plan rows cite the address), or — for an absence —
prints the inventory the prescribed read diffs. A decoy is **hit** when an output prints it for the class it imitates;
every hit is refuted by the precedent its decoy row names, so it produces **0 findings**. These are pre-flight results,
not a scored `/infra-audit` run — no run is recorded in `RESULTS.md` yet.

| detector | lines | seeds owned | caught by its pre-flight | decoys hit → findings | other printed lines |
|----------|-------|-------------|--------------------------|-----------------------|---------------------|
| `iac-state-scan` | 85 | 12 (§1–§4) | **12 / 12** — 1a backend (01a), committed `*.tfstate` (01b), 2a/2b (11a/11b), 3a (03a, 04a), `blocks.awk` terraform/module (03b, 04b), inventory + 3b (PHa), 3b `targetRevision` (PHb), 4 `-target` (09a), 4 `terraform -chdir=… plan` (09b; missed before IR-3 — grep 4 needed the subcommand right after the binary) | DECOY-23 (`?ref=v1.4.0`) by 3a → 0 (§ 27) | the Makefile's `-chdir` `plan`/`apply` lines (4, context); backend/key/default_tags context. The 2 false PIN-HELM lines from the installed `render.sh` self-test are gone (IR-4: `--hidden` greps skip AI-tool trees) |
| `iac-lifecycle-scan` | 118 + plan rows | 22 (§1–§7) | **22 / 22** — 1a/1c, 2a + `blocks.awk` CBD, 3 ×2, plan `STATEFUL-REPLACE` ×2 (08a, 08b; plus `DEL-01`/`DEL-02`/`DEL-03`/`DEL-05` rows corroborating D1a/D1b/D2a/D3a/D5a/D5b), 5 ×2, 6 ×2, 7a/7b/7c/7d/7e for every DEL seed | DECOY-22 (2a), DECOY-24 (3), DECOY-13 (7a ×3, 7b) → 0 (§ 25, ADR 0012, § 18); DECOY-12 quiet | 7b `prevent_destroy` absent on 5 resources, every one a seeded resource (the module's `aws_db_instance.this` = 08a's fix site, EFS = 08b, uploads = D3a, exports = D3b, analytics = D2b) |
| `dr-audit` | 117 | 24 (§1–§12) | **24 / 24**, with one caveat — R8a prints as `catalog-cluster.yaml:3` (under the next file's name, `inventory-cluster.yaml:3`, before IR-5); R11a/R11b surface at directory level (`./iac/envs/prod`, grep 12) and R4b by the absent `copy_action`/vault lock plus the plan's `cron(…)` line; 8j prints `larder-uploads-prod` (R3a) | DECOY-06 (11), DECOY-17 (10), DECOY-30 (8d), DECOY-13 (1–6, 12) → 0 | inventory, schedules, objectives header lines (context) |
| `serverless-reliability-scan` | 101 + joins | 10 (§2–§6) | **10 / 10** — `vis.jq` VIS (02a), grep 2 (02b), `lacks`/`cfnlacks` + `serverless.jq` DLQ (03a, 03b), `lacks` + PARTIAL (04a), grep 4's switch with no `batchItemFailures` in `payout-retry.ts` (04b, set difference), `lacks` + CONC (05a), Cloud Run `lacks` (05b), grep 6 + RETRY (06a, 06b) | DECOY-28 (grep 1) → 0 (§ 24); DECOY-14 quiet | timeouts, memory, reserved context |
| `iac-cost-scan` | 57 + joins | 6 (§1, §4, §8) | **6 / 6** — grep 1 + `cost.jq` "gateway endpoints: 0 (N4)" (01a, 01b), `lacks` + `cost.jq` (04a), grep 4 (04b), `ceiling.jq` "max 100 (KEDA default)" (08a), grep 8 + `cost.jq` (08b) | DECOY-15 (grep 1) → 0 (§ 23) | 1 × load balancer (COST-11 candidate, low); `K-HPA-COST` quantity rows per env |
| `k8s-render-scan` | 17 | 8 (§1, §3, §4) | **8 / 8** — 1a ×2, 3d ×2 (`.patches[1]`, `.patches[2]`), 4a ×2 | DECOY-25 quiet (`RespectIgnoreDifferences=true`) | 2d/3f rows for the same objects as GRa/GRb (one root cause each). Chart rows cite `k8s/chart/templates/…` (`k8s/storefront/templates/…`, a path that does not exist, before IR-6) |
| `k8s-availability-scan` | 19 + 54 rows | 12 (§2–§4, §7, §9) | **12 / 12** — K-PDB-BLOCK / K-HPA-PDB, K-HPA-REPLICAS (raw ×2), K-HPA-NOREQ ×2, K-PROBE-SAME ×2, K-SHUTDOWN-GRACE (SGa), `ctx:SHUTDOWN` + grep 7 `DRAIN_TIMEOUT_MS = 40_000` (SGb), K-PLATFORM-SPOF ×2 | DECOY-08 (K-SPREAD, trial env) → 0 (§ 8, § 47); DECOY-32 prints only `route:K-PROBE-DEEP`; DECOY-01, -04 (ctx row: 10 + 30 + 5 = 45), -07, -09a/b/c, -10, -11, -27 quiet | K-RES-MISSING on the NRa/NRb containers (same root cause); K-PDB-MISSING on the chart (corroborates HVb); K-HPA-MINMAX on notifier (corroborates CO-08a) |
| `k8s-wiring-scan` | 41 + 29 rows | 8 (§1–§3, §6) | **8 / 8** — K-CONFIG-ROLL (partial `config-revision`, CRa; chart, CRb), K-SVC-PORT ×2, K-NP-DNS ×2 (the row cites the workload and each policy's `file:line`: `netpol.yaml:1`, `dr/k8s/netpol.yaml:2` — IR-7), K-SA-MISSING, K-RBAC-DANGLING | DECOY-26 quiet (hash suffix) | `read:NP-DEPENDENCY` ×5 (context) |
| `k8s-api-version-scan` | 9 + 51 rows | 2 (§1) | **2 / 2** — static table + pluto, both objects | — | 42 K-SCHEMA-MISSING (no local CRD schemas: NOT-RUN for those kinds); 5 `read:CONTROLLER-PIN` |
| `edge-reliability-scan` | 83 | 14 (§1–§3, §5, §6, §13, §15) | **14 / 14** — `edge-locs.py` E1-SHORT, E2-CLIENT-KA, E3, E7 ×2, E8 ×2, E21; greps 1a (01b), 2 (02b + 1b `keepAliveTimeout = 5_000`), 3 (03b), 15 (21b), 13b `"--watch"]` (17a; missed before IR-2 — `\b--watch\b` cannot match), 13a `caddy validate … \|\| true` in `.github/workflows/edge.yml` (17b; missed before IR-1 — 13a ran without `--hidden`) | DECOY-02 (1a), DECOY-03 (1b), DECOY-19 (E7-STATIC-NAME) → 0 (§ 48, keep-alive read, § 32); DECOY-18 quiet (6a prints the app's `text/event-stream`, § 30) | HOP rows; `sec:E4-CACHE-NO-IDENTITY` (IO-SEC-E4a, routed); 13a's `nginx -t` steps in `edge.yml` (context) |
| `dns-tls-lifecycle-scan` | 52 + `certs.jq` | 6 (§2, §4, §5) | **6 / 6** — 2a ×2, 4a ×2, `certs.jq` D6-PROD-ACME-NONPROD (06a), 2b (06b) | DECOY-20 (7) → 0 (§ 39); DECOY-21 quiet | 5 CERT inventory rows; grep 7 prints IO-SEC-D1a/D1b (fallback, routed) |
| `network-exposure-audit` | 34 + `cidr-overlap.py` | 4 (§1, §2) | **4 / 4** — N3-NACL-RETURN ×2, N7-OVERLAP (analytics = prod; VPN inside both) | — | a third N7 row (analytics VPC vs the VPN range): the same two root causes |

Totals: **126 of 126** infrastructure seeds print in their owner's verbatim pre-flight (IO-SL-04b by the set difference grep
4 prescribes: the switch prints, and the handler grep finds `batchItemFailures` in the other handler only). Re-measured
2026-10-10 after IR-1–IR-7 landed (infrastructure 2.0.2); before them **123 of 126**, 3 missed by grep defects (IO-ST-09b,
IO-ED-17a, IO-ED-17b) and IO-DR-R8a printed under the wrong file. **0 decoys** survive the precedent their row names (17
hits above). Unseeded false lines: **0** (3 before: 2 from the installed skill's own `render.sh`, 1 misattributed CNPG row).
Excluded trees: the fixture has no test, vendor or i18n tree.

Security-owned rows, through `iac-scan`'s verbatim pre-flight (security pack, same staged copy): **12 / 12** print
(re-measured 2026-10-10 after IR-8 landed in `iac-scan`; 4 / 12 before) — IO-SEC-NPa (4k "peers but no ports", and 4n
`10.40.0.0/16`), IO-SEC-NPb (4n: an ipBlock of /20 or wider, with or without `ports:`), IO-SEC-RBa, IO-SEC-RBb
(wildcards), IO-SEC-ECb (4j mutable tag), IO-SEC-ECa (5g `image_tag_mutability = "MUTABLE"`), IO-SEC-D1a/D1b (5h records
grep; DECOY-20's CloudFront CNAME is not printed), IO-SEC-VKa (7f, now that the edge globs read `*.caddy`), IO-SEC-VKb
(7f's join: `valkey-app` read by `caddy-edge` and `api`), IO-SEC-E4a/E4b (7h: the `/api/me` `proxy_cache` in a file with no
bypass, the Caddy `cache` handler). One unseeded line: 7h's CloudFront `cache_policy_id` (context to read). The
infrastructure fallbacks print E4a (`edge-locs.py` `sec:` row), E4b (edge grep 4), D1a/D1b (dns grep 7) and VKa (dns
grep 5), each tagged security-class.

Self-check of the key: a findings file built from each seed's own title and text scores **138 / 138** under
`/infra-audit` (**12 / 12** under `/security-audit`) with 0 decoys pinned; a file of one typical false report per decoy
pins **34 / 34**.

### Integrator requests (skill gaps this fixture found — the skills are not edited here)

Status 2026-10-10: IR-1–IR-7 **done** in infrastructure 2.0.2, IR-8 **done** in security `iac-scan` (both re-measured in
§ Detector measurement above); IR-9 is `benchmarks/score.py`'s, tracked there.

- **IR-1 — `edge-reliability-scan` grep 13a:** **[done]** add `--hidden` (with `-g '!**/.git/**' -g '!.claude/**'`) — CI lives in
  `.github/`, so the deploy-validation step is never read (IO-ED-17b).
- **IR-2 — `edge-reliability-scan` grep 13b:** **[done]** `\b--watch\b` never matches (`\b` needs a word character before `-`);
  use `(?:^|[\s"'\[,])--watch\b` (IO-ED-17a; measured: 0 matches on `- --watch`, `"--watch"]` and `run --watch`).
- **IR-3 — `iac-state-scan` grep 4:** **[done]** allow global options between the binary and the subcommand,
  `\b(terraform|tofu|terragrunt)\b(?:\s+-chdir=\S+)?\s+(plan|apply|destroy)\b` — `terraform -chdir=… plan` is the usual CI
  form (IO-ST-09b; the Makefile's `plan`/`apply` lines are missed the same way).
- **IR-4 — `iac-state-scan` grep 3b (and every `--hidden` grep in the pack):** **[done]** exclude `.claude/**` and the other agent
  dirs — on an installed repo the `render.sh` self-test prints 2 false `helm upgrade --install` lines.
- **IR-5 — `dr-audit` grep 10 CNPG awk:** **[done]** the `FNR == 1 { f() }` flush runs after `FILENAME` has moved to the next file,
  so the previous file's row prints under the wrong name (catalog → `inventory-cluster.yaml:3`). Keep the file name with
  `st` (`fn = FILENAME` where `c = 1` is set).
- **IR-6 — `k8s-render-scan/scripts/render.sh`:** **[done]** Helm `__src.file` is built from the `# Source: <chart name>/…` header
  joined to the chart directory's parent; a chart directory not named after its chart (`k8s/chart`, `name: storefront`)
  makes every chart row cite `k8s/storefront/templates/…`, which does not exist. Join the source path to the chart
  directory instead.
- **IR-7 — `k8s-wiring-scan` K-NP-DNS:** **[done]** the row cites the workload; add the policy's `file:line` (the fix site).
- **IR-8 — security `iac-scan`** **[done]** (eval IR-1, re-measured): add `-g '*.caddy' -g '*.caddyfile'` to the edge globs
  (`N=`, used by 7a–7f) — Caddy configs split into imported `*.caddy` files are never read (IO-SEC-VKa); 7h for E4, the D1 records grep, ipBlock width with ports
  (IO-SEC-NPb `10.0.0.0/8`), `image_tag_mutability = "MUTABLE"` as the 4j registry variant (IO-SEC-ECa), and a 7f
  join on a `secretKeyRef` shared between an edge and an app workload (IO-SEC-VKb).
- **IR-9 — `benchmarks/score.py` `PATH_RE` / `BARE_PATH_RE`:** a finding that cites `Caddyfile`, `Makefile`, `Justfile`
  or a file with an extension longer than six characters (`terraform.tfstate`, `Caddyfile.preview`) has no path token,
  so it can never match. This key avoids it (the Caddy files are `shop.caddy`/`preview.caddy`, the `-target` seed is a
  script, IO-ST-01b is anchored on the root's `terraform {}` block, not the committed `.tfstate`); accept bare
  `Caddyfile|Makefile|Justfile|Jenkinsfile` and extensions up to 10 characters so future keys need not.
