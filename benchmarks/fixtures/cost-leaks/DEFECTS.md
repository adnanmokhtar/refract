# Seeded defects — `cost-leaks`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the agent scans. If you stage
the fixture by hand, delete this file from the copy first — an agent that reads it will score 100% and the number will
mean nothing.

Fixture shape: `Quaywise` — a parcel and courier SaaS: a NestJS 11 / Fastify / MikroORM API (BullMQ, S3 + lib-storage, an OpenAI-compatible model gateway by base URL, Twilio), a Python 3.12 worker (boto3 SQS, SQLAlchemy), Terraform (aws prod/preview/analytics, digitalocean dev) with hand-made offline plans, a CloudFormation stack, kustomize base + prod/dev overlays, self-hosted Prometheus and Alertmanager, a Terraform workflow, two runbooks, ADRs, an allocation policy and a synthetic FOCUS export; 52 finops seeds over 26 classes, 8 bill seeds, 4 routed, 27 decoys.

The API runs NestJS 11 on Fastify, MikroORM 6, BullMQ, `@aws-sdk/client-s3` + `lib-storage` + the presigner,
`@aws-sdk/client-sqs`, prom-client, winston and the `twilio` SDK; the model gateway has no SDK (`fetch` to
`LLM_GATEWAY_URL`), and ParcelNet, MapGrid and Addressly are reached by configured base URLs. The worker runs boto3,
SQLAlchemy 2, requests, APScheduler and prometheus-client. `ai/finops/attribution.md` declares the allocation policy
(`team` ∈ dispatch | growth | platform | data, `env` ∈ prod | preview | dev); `docs/compliance/retention.md` the
retention floors; ADR-0003 where member-account guardrails live; ADR-0007 the availability and DR objectives.

Invocation: /cost-review --whole-repo --export=billing/focus-sample.csv
Invocation[/infra-audit]: /infra-audit --whole-repo
Invocation[/obs-audit]: /obs-audit --whole-repo
Invocation[/perf-audit]: /perf-audit
Invocation[/ai-audit]: /ai-audit
Stage with: --git — the routed `/infra-audit` and `/obs-audit` runs read the history for their context map, and a
whole-repo run on a copy with no base branch says so with the flag; `/cost-review --whole-repo` itself needs no diff.

Eval source: Track A batch 8, `eval-batch8-finops.md` § 3.7 (fixture design), § 3.2 (the six detectors), § 3.5
(V570–V589); classes are `research-finops.md` § 1's ids, shipped as `FIN-<id>`; precedents are
`templates/snippets/precedents/finops.md` § n. Roots:
- `apps/api/src` — NestJS on Fastify: the model gateway client and the public tracking assistant, Twilio SMS, the
  ParcelNet client, its 15 s poller and the label-job wait loop, two SQS consumers, the outbox relay, the geocoder,
  the object-store area table, exports, bulk imports, proof-of-delivery photos, carrier manifests, brand assets, the
  label archive and renderer clients, three append-only entities and their retention jobs, the logger, the widget;
- `services/worker` — Python 3.12: the carrier-events consumer, the rate-card client and sync, address verification
  and its CronJob entry point, manifests and the label archive;
- `infra/terraform/envs/{prod,preview,analytics,do}`, `infra/terraform/plans/` (hand-made `terraform show -json`
  plans for prod and preview, format 1.2 — no Terraform binary or credential was used), `infra/cloudformation/`,
  `infra/do/bootstrap.sh`, `.github/workflows/terraform.yml`;
- `k8s/base`, `k8s/overlays/{prod,dev}` (both render offline with `kubectl kustomize`), `k8s/monitoring`, `k8s/platform`;
- `ai/finops/attribution.md`, `ai/runbooks/{platform-do,providers}.md`, `docs/adr/`, `docs/architecture/`,
  `docs/compliance/`, `.env.example`; `billing/focus-sample.csv` (150 synthetic FOCUS rows, July–September 2026, four
  accounts) and `billing/commitments.csv` (the commitment end dates FOCUS does not carry).

Departures from the eval, stated so a reader can audit them:
- **`--export=billing/focus-sample.csv` is on the `Invocation:` line.** The eval's § 3.3 gives `/cost-review` an
  `--export` flag; the 8 bill seeds are read only through it. Without the flag they are expected misses and the 52
  static seeds do not depend on it.
- **Bill seeds are 8 rows over UE-1, UE-3 and UE-4** (4 attribution, 2 commitment, 2 movement), anchored on rows of
  `billing/focus-sample.csv` and `billing/commitments.csv` (FOCUS has no commitment end date, so `bill-lane.py
  commitments --expiry` reads it from the inventory). UE-2 (cost per declared unit) needs a denominator metric the
  fixture does not ship.
- **The DigitalOcean BG-1 seed is anchored on the provider line** (`envs/do/main.tf`), the scope, because the evidence
  is an absence across the runbooks; it is `report-flagged` (precedents § 10). PS-3's two seeds are `report-flagged`
  for the same reason (precedents § 15).
- **BG-2, BG-3 and BG-4 have no Python, kustomize or runbook lane**: their second seed is in the data account's
  CloudFormation template (the YAML lane of `guardrail-scan` 0b/1a/2/3/4). BG-5's second seed is the preview job of
  the same workflow (the house has one Terraform workflow). TG-1 and TG-2's second seeds are the DigitalOcean root and
  the kustomize labels transformer; EG-2's second seed is a second TypeScript handler (the worker serves no HTTP).
- **27 decoys, not 12–13**: the eval's thirteen plus the grep traps the detectors' `Measured` paragraphs name (DNS and
  Velero `ttl`, a "latency budget alert", a container `env:` list, a commented region, a link origin) and the correct
  siblings (the long-poll queue attribute, the dev CDN host, a capped scratch volume, the record-holding photo prefix,
  the prod node floor, the blocking receive loop).
- **The fixture's generator is not committed** (the eval named `build-notes/cost-leaks/`): the plans and the FOCUS
  rows were generated once and are reviewed as files; line numbers here are computed from anchors.

Ownership and scoring. Five runs, five results rows, each staged in its own copy. **`/cost-review --whole-repo
--export=billing/focus-sample.csv`** scores the 52 finops rows and the 8 bill rows. The 4 routed rows score **only under
their owner** — `/infra-audit` (a KEDA ScaledObject with no `maxReplicaCount`), `/obs-audit` (a `user_id` metric
label), `/perf-audit` (a content-hashed bundle served `no-store`) and `/ai-audit` (a gateway call with no
`max_tokens`) — and `/cost-review` must list each as a routed row with its owner and at most a price, never grade it; a
`/cost-review` finding on them is UNMATCHED, not credited. `bucket:` is the row's expected disposition:
`report-with-fix` (the V-oracle can fail first against the fixture's own files and the fix is local),
`report-flagged` (console-only evidence or a person's decision: the DigitalOcean Spend Alert, a provider spend limit,
a commitment renewal, a bill movement to confirm against a change log), `routed` (owner line only).

Secrets. None. Keys come from the `quaywise-secrets` Secret or the environment and are never present; account ids,
hosts and addresses are fabricated (`quaywise.example`, `*.models.example`, `parcelnet.example`, `mapgrid.example`,
`addressly.example`; bucket names under fictional prefixes).

Line numbers are exact against the files in this directory and are re-checked by `benchmarks/run.sh --verify`, which also
fails if a decoy sits within 12 lines of a defect in the same file. Every line was computed from its anchor.

## Summary

| id | file:line | severity | command | class | bucket |
|----|-----------|----------|---------|-------|--------|
| CL-BG1-a | `infra/terraform/envs/preview/main.tf:21` | medium | `/cost-review` | FIN-BG-1 | report-with-fix |
| CL-BG1-b | `infra/terraform/envs/do/main.tf:21` | medium | `/cost-review` | FIN-BG-1 | report-flagged |
| CL-BG2-a | `infra/terraform/envs/prod/budgets.tf:13` | medium | `/cost-review` | FIN-BG-2 | report-with-fix |
| CL-BG2-b | `infra/cloudformation/data-account.yaml:34` | medium | `/cost-review` | FIN-BG-2 | report-with-fix |
| CL-BG3-a | `infra/terraform/envs/prod/budgets.tf:14` | medium | `/cost-review` | FIN-BG-3 | report-with-fix |
| CL-BG3-b | `infra/cloudformation/data-account.yaml:40` | medium | `/cost-review` | FIN-BG-3 | report-with-fix |
| CL-BG4-a | `infra/terraform/envs/prod/budgets.tf:27` | medium | `/cost-review` | FIN-BG-4 | report-with-fix |
| CL-BG4-b | `infra/cloudformation/data-account.yaml:59` | medium | `/cost-review` | FIN-BG-4 | report-with-fix |
| CL-BG5-a | `.github/workflows/terraform.yml:36` | medium | `/cost-review` | FIN-BG-5 | report-with-fix |
| CL-BG5-b | `.github/workflows/terraform.yml:56` | medium | `/cost-review` | FIN-BG-5 | report-with-fix |
| CL-BG6-a | `infra/terraform/envs/preview/main.tf:55` | medium | `/cost-review` | FIN-BG-6 | report-with-fix |
| CL-BG6-b | `k8s/overlays/dev/hpa.yaml:10` | medium | `/cost-review` | FIN-BG-6 | report-with-fix |
| CL-BG7-a | `infra/terraform/envs/prod/budgets.tf:64` | medium | `/cost-review` | FIN-BG-7 | report-with-fix |
| CL-BG7-b | `k8s/monitoring/cost-rules.yaml:21` | medium | `/cost-review` | FIN-BG-7 | report-with-fix |
| CL-TG1-a | `infra/terraform/envs/preview/main.tf:61` | medium | `/cost-review` | FIN-TG-1 | report-with-fix |
| CL-TG1-b | `infra/terraform/envs/do/main.tf:23` | low | `/cost-review` | FIN-TG-1 | report-with-fix |
| CL-TG2-a | `infra/terraform/envs/prod/storage.tf:35` | low | `/cost-review` | FIN-TG-2 | report-with-fix |
| CL-TG2-b | `k8s/overlays/prod/kustomization.yaml:13` | low | `/cost-review` | FIN-TG-2 | report-with-fix |
| CL-TG3-a | `k8s/base/api.yaml:7` | low | `/cost-review` | FIN-TG-3 | report-with-fix |
| CL-TG3-b | `k8s/overlays/dev/namespace.yaml:4` | low | `/cost-review` | FIN-TG-3 | report-with-fix |
| CL-TG4-a | `ai/runbooks/platform-do.md:11` | low | `/cost-review` | FIN-TG-4 | report-with-fix |
| CL-TG4-b | `infra/do/bootstrap.sh:10` | low | `/cost-review` | FIN-TG-4 | report-with-fix |
| CL-PS1-a | `apps/api/src/llm/gateway.client.ts:31` | high | `/cost-review` | FIN-PS-1 | report-with-fix |
| CL-PS1-b | `services/worker/worker/address_client.py:13` | medium | `/cost-review` | FIN-PS-1 | report-with-fix |
| CL-PS2-a | `apps/api/src/notifications/sms.service.ts:23` | low | `/cost-review` | FIN-PS-2 | report-with-fix |
| CL-PS2-b | `services/worker/worker/rates_client.py:14` | low | `/cost-review` | FIN-PS-2 | report-with-fix |
| CL-PS3-a | `ai/runbooks/providers.md:10` | low | `/cost-review` | FIN-PS-3 | report-flagged |
| CL-PS3-b | `docs/adr/0005-sms-provider.md:18` | low | `/cost-review` | FIN-PS-3 | report-flagged |
| CL-FQ1-a | `apps/api/src/tracking/carrier-poll.scheduler.ts:23` | medium | `/cost-review` | FIN-FQ-1 | report-with-fix |
| CL-FQ1-b | `k8s/base/address-revalidate-cronjob.yaml:10` | medium | `/cost-review` | FIN-FQ-1 | report-with-fix |
| CL-FQ2-a | `apps/api/src/queue/label-requests.consumer.ts:24` | medium | `/cost-review` | FIN-FQ-2 | report-with-fix |
| CL-FQ2-b | `services/worker/worker/sqs_consumer.py:32` | medium | `/cost-review` | FIN-FQ-2 | report-with-fix |
| CL-FQ3-a | `apps/api/src/labels/label-job.poller.ts:16` | medium | `/cost-review` | FIN-FQ-3 | report-with-fix |
| CL-FQ3-b | `services/worker/worker/rate_sync.py:26` | medium | `/cost-review` | FIN-FQ-3 | report-with-fix |
| CL-ST1-a | `apps/api/src/exports/export-runner.ts:22` | medium | `/cost-review` | FIN-ST-1 | report-with-fix |
| CL-ST1-b | `services/worker/worker/report_export.py:40` | medium | `/cost-review` | FIN-ST-1 | report-with-fix |
| CL-ST2-a | `apps/api/src/imports/bulk-import.service.ts:22` | low | `/cost-review` | FIN-ST-2 | report-with-fix |
| CL-ST2-b | `services/worker/worker/report_export.py:47` | low | `/cost-review` | FIN-ST-2 | report-with-fix |
| CL-ST3-a | `apps/api/src/tracking/tracking-event.entity.ts:5` | medium | `/cost-review` | FIN-ST-3 | report-with-fix |
| CL-ST3-b | `services/worker/worker/models.py:28` | medium | `/cost-review` | FIN-ST-3 | report-with-fix |
| CL-ST4-a | `apps/api/src/logging/logger.ts:10` | low | `/cost-review` | FIN-ST-4 | report-with-fix |
| CL-ST4-b | `k8s/base/worker.yaml:46` | low | `/cost-review` | FIN-ST-4 | report-with-fix |
| CL-EG1-a | `apps/api/src/branding/brand-assets.ts:2` | medium | `/cost-review` | FIN-EG-1 | report-with-fix |
| CL-EG1-b | `k8s/overlays/prod/config.yaml:8` | medium | `/cost-review` | FIN-EG-1 | report-with-fix |
| CL-EG2-a | `apps/api/src/media/pod-photos.controller.ts:28` | low | `/cost-review` | FIN-EG-2 | report-with-fix |
| CL-EG2-b | `apps/api/src/manifests/manifests.controller.ts:23` | low | `/cost-review` | FIN-EG-2 | report-with-fix |
| CL-EG3-a | `apps/api/src/labels/label-archive.client.ts:8` | medium | `/cost-review` | FIN-EG-3 | report-with-fix |
| CL-EG3-b | `services/worker/worker/manifest_archive.py:10` | medium | `/cost-review` | FIN-EG-3 | report-with-fix |
| CL-EG4-a | `apps/api/src/config/env.schema.ts:43` | low | `/cost-review` | FIN-EG-4 | report-with-fix |
| CL-EG4-b | `services/worker/worker/settings.py:22` | low | `/cost-review` | FIN-EG-4 | report-with-fix |
| CL-PX1-a | `ai/runbooks/platform-do.md:27` | low | `/cost-review` | FIN-PX-1 | report-with-fix |
| CL-PX1-b | `docs/architecture/notifications.md:17` | low | `/cost-review` | FIN-PX-1 | report-with-fix |
| CL-UE1-a | `billing/focus-sample.csv:147` | medium | `/cost-review` | FIN-UE-1 | report-with-fix |
| CL-UE1-b | `billing/focus-sample.csv:139` | medium | `/cost-review` | FIN-UE-1 | report-with-fix |
| CL-UE1-c | `billing/focus-sample.csv:137` | medium | `/cost-review` | FIN-UE-1 | report-with-fix |
| CL-UE1-d | `billing/focus-sample.csv:149` | medium | `/cost-review` | FIN-UE-1 | report-with-fix |
| CL-UE3-a | `billing/commitments.csv:2` | medium | `/cost-review` | FIN-UE-3 | report-flagged |
| CL-UE3-b | `billing/focus-sample.csv:134` | medium | `/cost-review` | FIN-UE-3 | report-flagged |
| CL-UE4-a | `billing/focus-sample.csv:140` | medium | `/cost-review` | FIN-UE-4 | report-flagged |
| CL-UE4-b | `billing/focus-sample.csv:141` | medium | `/cost-review` | FIN-UE-4 | report-flagged |
| CL-HO-INF | `k8s/overlays/prod/keda-worker.yaml:2` | medium | `/infra-audit` | INF §8 K-HPA-COST (scale ceiling) | routed |
| CL-HO-OBS | `apps/api/src/metrics/metrics.ts:18` | medium | `/obs-audit` | OBS §1 unbounded label | routed |
| CL-HO-PERF | `apps/api/src/widget/widget.controller.ts:18` | medium | `/perf-audit` | PERF §6 HTTP caching headers | routed |
| CL-HO-AI | `apps/api/src/llm/gateway.client.ts:37` | medium | `/ai-audit` | AI §B2 output cap | routed |

52 finops seeds (two per class over the 26 static classes, one TypeScript or Terraform and one Python, kustomize, YAML, runbook or script wherever the class has that lane), 8 bill seeds in the FOCUS export, 4 routed rows, 27 decoys.

## CL-BG1-a — The preview account has no budget at all

```defect
id:       CL-BG1-a
file:     infra/terraform/envs/preview/main.tf
line:     21
severity: medium
command:  /cost-review
class:    FIN-BG-1
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §1
anchor:   provider "aws" {
match:    preview|222222222222|scope|account|root
match:    budget|aws_budgets_budget|billing alert|spend alert|BG-1
```

The preview root deploys an always-on EKS cluster and a Postgres instance into account 222222222222 and declares no `aws_budgets_budget`; ADR-0003 puts analytics' budget in the org-billing repository and names none for preview. Nothing notices a forgotten preview stack before the invoice. Proof V570 (plan assertion: ≥ 1 budget per scope). Fix: a budget for the preview account with a FORECASTED rule below 100 % and a live recipient.

## CL-BG1-b — The DigitalOcean dev account names no Spend Alert anywhere

```defect
id:       CL-BG1-b
file:     infra/terraform/envs/do/main.tf
line:     21
severity: medium
command:  /cost-review
class:    FIN-BG-1
owner:    finops
bucket:   report-flagged
detector: guardrail-scan §1 (documentary, precedents § 10)
anchor:   provider "digitalocean" {}
match:    digitalocean|DOKS|dev account|envs/do|qw-dev
match:    budget|spend alert|billing alert|console|unconfirmed|documentary
```

The dev environment runs on DigitalOcean (a DOKS cluster, a managed Postgres from the runbook, Valkey from `bootstrap.sh`). DigitalOcean Spend Alerts are control-panel only, so the only static evidence can be a runbook line naming the alert, its threshold and its read-back; neither runbook nor ADR-0009 has one. **Unconfirmed** at most (precedents § 10): the settling probe is the control panel's billing alert. Proof V570, documentary. Fix: set the alert and write it, with its read-back, into `ai/runbooks/platform-do.md`.

## CL-BG2-a — The prod budget notifies only on ACTUAL spend at 100 %

```defect
id:       CL-BG2-a
file:     infra/terraform/envs/prod/budgets.tf
line:     13
severity: medium
command:  /cost-review
class:    FIN-BG-2
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §2
anchor:   notification_type         = "ACTUAL"
match:    prod_monthly|budget|notification
match:    ACTUAL|FORECAST|100 ?%|after the (money|spend)|threshold
```

`qw-prod-monthly` has one notification: ACTUAL, at 100 %. It fires after the month's money is spent. Proof V570 (a FORECASTED rule below 100 % exists — fails). Fix: a FORECASTED notification at a derived percentage beside the ACTUAL one.

## CL-BG2-b — The data account's budget is ACTUAL-only at 100 %

```defect
id:       CL-BG2-b
file:     infra/cloudformation/data-account.yaml
line:     34
severity: medium
command:  /cost-review
class:    FIN-BG-2
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §2
anchor:   NotificationType: ACTUAL
match:    DataAccountBudget|qw-data-monthly|budget|data account
match:    ACTUAL|FORECAST|100 ?%|threshold
```

The CloudFormation budget for the data account (Athena scans, usage-billed, not a fixed-cost account) notifies on ACTUAL at 100 % only. Proof V570. Fix: a FORECASTED notification below 100 %.

## CL-BG3-a — The prod budget notifies an SNS topic nobody subscribes to

```defect
id:       CL-BG3-a
file:     infra/terraform/envs/prod/budgets.tf
line:     14
severity: medium
command:  /cost-review
class:    FIN-BG-3
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §3
anchor:   subscriber_sns_topic_arns = [aws_sns_topic.billing_alerts.arn]
match:    billing_alerts|sns|topic|subscriber
match:    subscription|no (live )?recipient|nobody|unheard|no one|reads
```

Both the budget and the anomaly subscription publish to `aws_sns_topic.billing_alerts`, and no `aws_sns_topic_subscription` exists in any root: the alerts reach no one. Proof V570 (plan join topic → subscription). Fix: a subscription on the team's alert route (or an e-mail subscriber someone reads).

## CL-BG3-b — The data account's budget e-mails a no-reply address

```defect
id:       CL-BG3-b
file:     infra/cloudformation/data-account.yaml
line:     40
severity: medium
command:  /cost-review
class:    FIN-BG-3
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §3
anchor:   Address: no-reply@quaywise.example
match:    no-?reply|Address|subscriber|recipient
match:    no-?reply|nobody|no (live )?recipient|unread|unheard|no one
```

The only subscriber of the data account's budget is `no-reply@quaywise.example`, an address nobody reads. Proof V570. Fix: the data team's alias or the shared cost alert route.

## CL-BG4-a — Prod anomaly detection watches the account total with an absolute threshold

```defect
id:       CL-BG4-a
file:     infra/terraform/envs/prod/budgets.tf
line:     27
severity: medium
command:  /cost-review
class:    FIN-BG-4
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §4
anchor:   resource "aws_ce_anomaly_monitor" "account_total" {
match:    anomaly|account_total|monitor
match:    total|CUSTOM|per.?service|DIMENSIONAL|absolute|2,?500|relative
```

The only monitor is a CUSTOM monitor over the linked account's total, and its subscription fires on an absolute impact of USD 2,500: a service tripling inside a flat total is invisible. The per-service monitor is commented out (CL-BG7-a). Proof V571. Fix: a DIMENSIONAL monitor over SERVICE with a relative (percentage) threshold.

## CL-BG4-b — The data account's anomaly subscription fires above USD 10,000 on a USD 1,800 account

```defect
id:       CL-BG4-b
file:     infra/cloudformation/data-account.yaml
line:     59
severity: medium
command:  /cost-review
class:    FIN-BG-4
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §4
anchor:   ThresholdExpression:
match:    anomaly|ThresholdExpression|subscription|threshold
match:    absolute|10,?000|never|relative|above|budget|1,?800
```

The monitor is per-service, but the subscription's threshold is an absolute impact of 10,000 on an account whose whole monthly limit is 1,800: no anomaly can reach it. Proof V571. Fix: a relative threshold (`ANOMALY_TOTAL_IMPACT_PERCENTAGE`) or an absolute one derived from the account's spend.

## CL-BG5-a — Prod Terraform is planned and applied from CI with no cost estimate

```defect
id:       CL-BG5-a
file:     .github/workflows/terraform.yml
line:     36
severity: medium
command:  /cost-review
class:    FIN-BG-5
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §5
anchor:   run: terraform plan -input=false -out=tfplan
match:    terraform (plan|apply)|workflow|prod
match:    infracost|estimate|cost delta|pre-?merge|no cost
```

The prod job plans every PR and applies on merge to main; no step shows the cost delta of the plan. Proof V572 (workflow lint finds no estimate step on the IaC paths). Fix: an estimate step on the plan (Infracost or an equivalent, advisory or blocking by the team's choice; AWS is supported).

## CL-BG5-b — The preview root is applied on every PR with no estimate

```defect
id:       CL-BG5-b
file:     .github/workflows/terraform.yml
line:     56
severity: medium
command:  /cost-review
class:    FIN-BG-5
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §5
anchor:   run: terraform apply -input=false -auto-approve
match:    preview|apply|auto-approve|workflow
match:    infracost|estimate|cost delta|pre-?merge|no cost
```

The preview job applies `-auto-approve` on pull requests; a PR that adds a node or an instance size goes live with nobody seeing the price. Proof V572. Fix: the same estimate step before the apply.

## CL-BG6-a — The preview node group keeps two nodes up around the clock, with no TTL or schedule

```defect
id:       CL-BG6-a
file:     infra/terraform/envs/preview/main.tf
line:     55
severity: medium
command:  /cost-review
class:    FIN-BG-6
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §6
anchor:   min_size     = 2
match:    preview|node.?group|min_size
match:    always.?on|off.?hours|TTL|destroy|schedule|non.?prod|bound|scale.?to.?zero
```

The long-lived preview cluster's node group never goes below two `t3.large` nodes; the root has no TTL tag, no destroy job and no off-hours schedule. Proof V573 (offline policy test rejects a TTL-less, floor-above-zero non-prod root). Fix: a scheduled scale-to-zero outside demo hours, or a TTL tag with a destroy job.

## CL-BG6-b — The dev namespace has no quota and a two-replica floor on an always-on cluster

```defect
id:       CL-BG6-b
file:     k8s/overlays/dev/hpa.yaml
line:     10
severity: medium
command:  /cost-review
class:    FIN-BG-6
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §6
anchor:   minReplicas: 2
match:    dev|quaywise-dev|minReplicas|namespace
match:    ResourceQuota|LimitRange|quota|always.?on|off.?hours|bound|downscal|non.?prod
```

The dev overlay runs on the billed DOKS cluster (ADR-0009) with an API floor of two replicas, no ResourceQuota or LimitRange in the namespace and no downscaler or KEDA cron. Proof V573 (a quota-present assertion over the dev render fails). Fix: a ResourceQuota + LimitRange in the dev overlay and an off-hours schedule.

## CL-BG7-a — The per-service anomaly monitor is commented out with no end

```defect
id:       CL-BG7-a
file:     infra/terraform/envs/prod/budgets.tf
line:     64
severity: medium
command:  /cost-review
class:    FIN-BG-7
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §7
anchor:   # resource "aws_ce_anomaly_monitor" "per_service" {
match:    per_service|anomaly|commented|monitor
match:    comment|disabled|switched off|muted|suppress|expiry|no end|re-?enable
```

"Switched off until the thresholds are reworked": a cost guardrail removed with no date or owner to restore it. Proof V574 (config assertion: every suppression carries an end). Fix: restore it with a relative threshold, or record an expiry and an owner.

## CL-BG7-b — The carrier spend alert is muted by comment since August

```defect
id:       CL-BG7-b
file:     k8s/monitoring/cost-rules.yaml
line:     21
severity: medium
command:  /cost-review
class:    FIN-BG-7
owner:    finops
bucket:   report-with-fix
detector: guardrail-scan §7
anchor:   # - alert: CarrierApiSpendSpike
match:    CarrierApiSpendSpike|alert|carrier
match:    comment|muted|disabled|suppress|expiry|no end|re-?enable
```

The only alert on the carrier API's billed calls was commented out "during the carrier migration" and never restored; CL-FQ1-a's poller now runs unwatched. Proof V574. Fix: restore the rule (or an Alertmanager silence with `endsAt` while a migration runs).

## CL-TG1-a — The preview root has no default_tags and no tags on any resource

```defect
id:       CL-TG1-a
file:     infra/terraform/envs/preview/main.tf
line:     61
severity: medium
command:  /cost-review
class:    FIN-TG-1
owner:    finops
bucket:   report-with-fix
detector: allocation-scan §1
anchor:   resource "aws_db_instance" "preview" {
match:    preview|qw-preview|aws_db_instance|default_tags|tags
match:    team|env|untagged|missing|tags_all|allocation|default_tags
```

The policy requires `team` and `env` on every taggable resource and `env` from `default_tags` in every root; the preview provider has no `default_tags` and its cluster, node group and database carry no tags (systemic: the whole root). The bill shows it as CL-UE1-a. Proof V575 (plan walk `tags_all ⊇ {team, env}`). Fix: `default_tags { env = "preview", team = "platform" }` in the provider.

## CL-TG1-b — The DOKS dev cluster carries no team or env tag

```defect
id:       CL-TG1-b
file:     infra/terraform/envs/do/main.tf
line:     23
severity: low
command:  /cost-review
class:    FIN-TG-1
owner:    finops
bucket:   report-with-fix
detector: allocation-scan §1
anchor:   resource "digitalocean_kubernetes_cluster" "dev" {
match:    digitalocean_kubernetes_cluster|qw-dev|DOKS|cluster
match:    tag|team|env|untagged|missing|allocation
```

The policy's DigitalOcean rule is `team:<team>` and `env:<env>` tags on every cluster; `qw-dev` has no `tags`. Proof V575 on the DO plan (`tags ⊇` the policy keys). Fix: `tags = ["team:platform", "env:dev"]`.

## CL-TG2-a — The media bucket is tagged `Team`, not `team`

```defect
id:       CL-TG2-a
file:     infra/terraform/envs/prod/storage.tf
line:     35
severity: low
command:  /cost-review
class:    FIN-TG-2
owner:    finops
bucket:   report-with-fix
detector: allocation-scan §2
anchor:   tags = { Team = "growth" }
match:    media|qw-prod-media|Team
match:    case|Team|spelling|drift|mis-?tag|variant
```

Every other prod resource spells the key `team`; `qw-prod-media` spells it `Team`, so the bill puts its storage under no team (CL-UE1-c). Proof V575 (case-folded key walk). Fix: `team = "growth"`.

## CL-TG2-b — The prod overlay stamps `env: production`; the policy allows `prod`

```defect
id:       CL-TG2-b
file:     k8s/overlays/prod/kustomization.yaml
line:     13
severity: low
command:  /cost-review
class:    FIN-TG-2
owner:    finops
bucket:   report-with-fix
detector: allocation-scan §2
anchor:   env: production
match:    env|production|labels|kustomization|overlay
match:    production|allowed|(?:not|n.t) in|value|prod\b|policy|mis-?tag
```

The labels transformer writes `env: production` onto every prod resource and pod template; the policy's set is `prod | preview | dev`, so every prod pod's cost lands outside the allowed value. Proof V575/V576 with the allowed-value set over the prod render. Fix: `env: prod`.

## CL-TG3-a — The API's team label is on the Deployment, not on its pods

```defect
id:       CL-TG3-a
file:     k8s/base/api.yaml
line:     7
severity: low
command:  /cost-review
class:    FIN-TG-3
owner:    finops
bucket:   report-with-fix
detector: allocation-scan §3
anchor:   team: dispatch
match:    quaywise-api|api\.yaml|Deployment|team
match:    pod template|template|metadata only|label|OpenCost|Kubecost
```

`team: dispatch` sits on the Deployment's metadata; the pod template has only `app.kubernetes.io/name`. Cost tools read pod labels, and the prod cluster is shared by two teams (the policy), so the API's pods are unallocated in every env. Proof V576 (render walk). Fix: the label on `spec.template.metadata.labels`.

## CL-TG3-b — The dev namespace has no team label

```defect
id:       CL-TG3-b
file:     k8s/overlays/dev/namespace.yaml
line:     4
severity: low
command:  /cost-review
class:    FIN-TG-3
owner:    finops
bucket:   report-with-fix
detector: allocation-scan §3
anchor:   name: quaywise-dev
match:    quaywise-dev|namespace
match:    team|owner|label|missing
```

The policy says every namespace carries `team`; `quaywise-dev` carries only `part-of` (the overlay adds `env`). Proof V576. Fix: `team: platform` on the namespace.

## CL-TG4-a — The runbook creates the dev Postgres with no tag

```defect
id:       CL-TG4-a
file:     ai/runbooks/platform-do.md
line:     11
severity: low
command:  /cost-review
class:    FIN-TG-4
owner:    finops
bucket:   report-with-fix
detector: allocation-scan §4
anchor:   doctl databases create qw-dev-pg \
match:    doctl|qw-dev-pg|databases create|runbook
match:    tag-names?|tag|team|env|project|allocation
```

A multi-line `doctl databases create` with no `--tag-names`: the managed Postgres is outside every allocation key the policy names. Proof V577 (runbook lint over every create line). Fix: `--tag-names team:platform,env:dev`.

## CL-TG4-b — The bootstrap script creates the dev Valkey with no tag

```defect
id:       CL-TG4-b
file:     infra/do/bootstrap.sh
line:     10
severity: low
command:  /cost-review
class:    FIN-TG-4
owner:    finops
bucket:   report-with-fix
detector: allocation-scan §4
anchor:   doctl databases create qw-dev-valkey
match:    doctl|qw-dev-valkey|valkey|bootstrap
match:    tag-names?|tag|team|env|project|allocation
```

Same shape in a script: the Valkey cluster carries no `--tag-names`. Proof V577. Fix: the policy's tags on the line.

## CL-PS1-a — The public tracking assistant reaches the model gateway with no org-level cap

```defect
id:       CL-PS1-a
file:     apps/api/src/llm/gateway.client.ts
line:     31
severity: high
command:  /cost-review
class:    FIN-PS-1
owner:    finops
bucket:   report-with-fix
detector: spend-path-scan §1
anchor:   fetch(`${this.config.llmGatewayUrl}/v1/chat/completions`
match:    gateway|LLM|model|completions|assistant
match:    cap|budget|kill.?switch|aggregate|month|denial of wallet|SpendGuard
```

Every other paid client reserves units from `SpendGuard` (org-wide monthly caps); `GatewayClient.complete` calls the per-token gateway with no cap, and its caller is the unauthenticated tracking-page assistant. Nothing bounds the month (OWASP LLM10 "denial of wallet"). Proof V578 (stub provider: at the cap, zero further calls and one alert). Fix: `guard.reserve('llm', …)` before the call on every entry point, with an `LLM_MONTHLY_CAP`.

## CL-PS1-b — Address verification calls are not capped

```defect
id:       CL-PS1-b
file:     services/worker/worker/address_client.py
line:     13
severity: medium
command:  /cost-review
class:    FIN-PS-1
owner:    finops
bucket:   report-with-fix
detector: spend-path-scan §1
anchor:   resp = _session.post(f"{settings.ADDRESS_API_BASE_URL}/v1/verify"
match:    address|Addressly|verify|validate
match:    cap|budget|kill.?switch|aggregate|month|SpendGuard
```

The worker's rate client reserves from the Python `SpendGuard`; the per-lookup Addressly client has no cap, and the every-minute CronJob (CL-FQ1-b) calls it per open shipment. Proof V578. Fix: a `SpendGuard("address", …)` reserve before the call.

## CL-PS2-a — SMS sends are not counted

```defect
id:       CL-PS2-a
file:     apps/api/src/notifications/sms.service.ts
line:     23
severity: low
command:  /cost-review
class:    FIN-PS-2
owner:    finops
bucket:   report-with-fix
detector: spend-path-scan §2
anchor:   const message = await this.client.messages.create({
match:    sms|twilio|messages\.create
match:    counter|count|metric|segment|billed unit|tenant|usage
```

The cap counts segments in Redis, but nothing exports the billed unit: no counter of messages or segments per tenant, and the debug log carries only the SID. Anomaly detection and showback on SMS are impossible. Proof V579 (registry scrape after N sends shows N segments with a tenant label). Fix: `sms_segments_total{tenant,status}`.

## CL-PS2-b — The rate-card client measures latency, not billed calls

```defect
id:       CL-PS2-b
file:     services/worker/worker/rates_client.py
line:     14
severity: low
command:  /cost-review
class:    FIN-PS-2
owner:    finops
bucket:   report-with-fix
detector: spend-path-scan §2
anchor:   RATES_LATENCY = Histogram(
match:    rates|RATES_LATENCY|Histogram|rate.?card
match:    counter|billed|latency only|count|unit
```

The only metric on the per-request rate-card API is a latency histogram labelled by carrier; billed calls (and the billed retries of CL-FQ3-b) are not counted. Proof V579. Fix: a counter of calls per carrier and outcome.

## CL-PS3-a — The gateway runbook states a usage tier, not a spend limit

```defect
id:       CL-PS3-a
file:     ai/runbooks/providers.md
line:     10
severity: low
command:  /cost-review
class:    FIN-PS-3
owner:    finops
bucket:   report-flagged
detector: spend-path-scan §3 (precedents § 15)
anchor:   The account is on usage tier 4 since 2026-06
match:    gateway|usage tier|runbook|providers
match:    spend limit|hard limit|cap|provider|console|unconfirmed
```

The runbook names the gateway's usage tier (a rate ceiling) and no provider-side spend limit or how to read it back. **Unconfirmed** from files (precedents § 15): the probe is the gateway console's limits page. Proof V580, documentary. Fix: set the limit, write its value and read-back here, and handle the cap error without retry.

## CL-PS3-b — Twilio's spend limit is "reviewed in the console"

```defect
id:       CL-PS3-b
file:     docs/adr/0005-sms-provider.md
line:     18
severity: low
command:  /cost-review
class:    FIN-PS-3
owner:    finops
bucket:   report-flagged
detector: spend-path-scan §3 (precedents § 15)
anchor:   The monthly SMS spend is reviewed in the Twilio console
match:    twilio|sms|ADR-0005|console
match:    limit|usage trigger|cap|alert|provider|unconfirmed
```

The ADR leaves Twilio's spend to a person looking at the console; no usage trigger or limit is named and nothing says how to read one back. Unconfirmed; probe: the Twilio console's usage triggers. Proof V580. Fix: a usage trigger with its value written into the providers runbook.

## CL-FQ1-a — Every API replica polls the per-call carrier API every 15 s

```defect
id:       CL-FQ1-a
file:     apps/api/src/tracking/carrier-poll.scheduler.ts
line:     23
severity: medium
command:  /cost-review
class:    FIN-FQ-1
owner:    finops
bucket:   report-with-fix
detector: spend-path-scan §4
anchor:   @Interval(15_000)
match:    Interval|carrier|poll|refreshInTransit
match:    replica|webhook|per.?call|billed|calls/day|5,?760|frequency|every 15
```

5,760 runs a day × 2–6 API replicas (prod HPA) × up to 10 billed `trackBatch` calls per run, whether or not any parcel moved; ParcelNet offers push webhooks that are not enabled (`providers.md`). Proof V581 (fake timers: billed calls per simulated hour × prod replicas ≤ the declared budget). Fix: the webhook, or once per fleet at the rate scans change.

## CL-FQ1-b — The address re-check CronJob runs every minute against a per-lookup API

```defect
id:       CL-FQ1-b
file:     k8s/base/address-revalidate-cronjob.yaml
line:     10
severity: medium
command:  /cost-review
class:    FIN-FQ-1
owner:    finops
bucket:   report-with-fix
detector: spend-path-scan §4
anchor:   schedule: "* * * * *"
match:    address-revalidate|CronJob|schedule|\* \* \* \* \*
match:    every minute|1,?440|per.?lookup|billed|frequency|calls/day
```

1,440 runs a day × every unpicked shipment of the last three days × one billed Addressly lookup, even when no address changed. Proof V581. Fix: verify on address change (the edit is an event) or at most hourly.

## CL-FQ2-a — The label-requests consumer short-polls SQS every second

```defect
id:       CL-FQ2-a
file:     apps/api/src/queue/label-requests.consumer.ts
line:     24
severity: medium
command:  /cost-review
class:    FIN-FQ-2
owner:    finops
bucket:   report-with-fix
detector: spend-path-scan §5
anchor:   new ReceiveMessageCommand({ QueueUrl: this.config.labelQueueUrl, MaxNumberOfMessages: 10 })
match:    ReceiveMessage|label.?requests|SQS
match:    WaitTimeSeconds|short poll|long poll|empty receive|billed
```

No `WaitTimeSeconds`, and the queue attribute `receive_wait_time_seconds` is unset (0): each replica makes 86,400 billed receives a day, mostly empty. The bill's September SQS jump is this consumer (CL-UE4-a). Proof V582 (mocked client asserts `WaitTimeSeconds ≥ 1`). Fix: `WaitTimeSeconds: 20` in a blocking loop, or the queue attribute.

## CL-FQ2-b — The Python carrier-events consumer receives with `WaitTimeSeconds=0`

```defect
id:       CL-FQ2-b
file:     services/worker/worker/sqs_consumer.py
line:     32
severity: medium
command:  /cost-review
class:    FIN-FQ-2
owner:    finops
bucket:   report-with-fix
detector: spend-path-scan §5
anchor:   WaitTimeSeconds=0,
match:    receive_message|WaitTimeSeconds|sqs_consumer|carrier.?events
match:    WaitTimeSeconds|short poll|long poll|empty receive|0\b|billed
```

Explicit short polling with a one-second sleep on empty: 86,400 billed empty receives a day per worker replica (KEDA keeps at least one). Proof V582. Fix: `WaitTimeSeconds=20` and drop the sleep.

## CL-FQ3-a — The label-job wait loop re-polls ParcelNet with no delay

```defect
id:       CL-FQ3-a
file:     apps/api/src/labels/label-job.poller.ts
line:     16
severity: medium
command:  /cost-review
class:    FIN-FQ-3
owner:    finops
bucket:   report-with-fix
detector: spend-path-scan §6
anchor:   while (true) {
match:    while|label.?job|waitForLabel|getLabelJob
match:    delay|sleep|backoff|busy|tight loop|no wait|billed
```

`waitForLabel` calls the billed `getLabelJob` back to back until the job is done: a label that takes 20 s to render costs hundreds of calls (each also reserves from the carrier cap). Proof V581 (fake timers: calls per simulated second). Fix: a delay with backoff and a ceiling, or ParcelNet's label webhook.

## CL-FQ3-b — The rate-card sync spins on `building` pages

```defect
id:       CL-FQ3-b
file:     services/worker/worker/rate_sync.py
line:     26
severity: medium
command:  /cost-review
class:    FIN-FQ-3
owner:    finops
bucket:   report-with-fix
detector: spend-path-scan §6
anchor:   while True:
match:    while|rate.?sync|building|fetch_page
match:    delay|sleep|backoff|busy|continue|no wait|billed
```

When ParcelNet answers `building`, the loop `continue`s straight into the next billed request — no sleep, no backoff, no ceiling. Proof V581. Fix: sleep with backoff and a maximum number of tries.

## CL-ST1-a — Merchant exports pile up under `exports/` forever

```defect
id:       CL-ST1-a
file:     apps/api/src/exports/export-runner.ts
line:     22
severity: medium
command:  /cost-review
class:    FIN-ST-1
owner:    finops
bucket:   report-with-fix
detector: storage-growth-scan §1
anchor:   new PutObjectCommand({ Bucket: bucketFor(this.config, 'exports')
match:    exports/|export|PutObject
match:    lifecycle|expir|delete|retention|forever|tmp-uploads|no rule
```

An export per merchant per night plus on demand; the bucket's only lifecycle rule covers `tmp-uploads/`, nothing deletes an export, and the retention page says exports are kept "until downloaded". Shipment exports hold recipients' postcodes (retention half → security). Proof V583. Fix: an Expiration rule on `exports/` (e.g. the download window) in `storage.tf`.

## CL-ST1-b — Carrier manifests accumulate under `reports/` with no rule

```defect
id:       CL-ST1-b
file:     services/worker/worker/report_export.py
line:     40
severity: medium
command:  /cost-review
class:    FIN-ST-1
owner:    finops
bucket:   report-with-fix
detector: storage-growth-scan §1
anchor:   s3.put_object(Bucket=settings.REPORTS_BUCKET, Key=summary_key
match:    reports/|manifest|put_object|REPORTS_BUCKET
match:    lifecycle|expir|delete|retention|no rule|forever
```

A CSV and a 40–400 MB ZIP per carrier per day under `reports/`; `qw-prod-reports` has no lifecycle configuration and nothing deletes them (the archive copy is the record). Proof V583. Fix: an Expiration rule on `reports/`.

## CL-ST2-a — Bulk imports upload in parts to a bucket with no abort rule

```defect
id:       CL-ST2-a
file:     apps/api/src/imports/bulk-import.service.ts
line:     22
severity: low
command:  /cost-review
class:    FIN-ST-2
owner:    finops
bucket:   report-with-fix
detector: storage-growth-scan §2
anchor:   const upload = new Upload({
match:    Upload|imports|multipart|lib-storage
match:    abort|incomplete|multipart|AbortIncompleteMultipartUpload
```

Uploads of up to 2 GB in 8 MB parts; an interrupted upload leaves its parts billed in `qw-prod-imports`, which has no lifecycle configuration (the only abort rule is on the media bucket). Proof V584. Fix: `abort_incomplete_multipart_upload { days_after_initiation = 7 }` on the imports bucket.

## CL-ST2-b — Manifest ZIPs go up with `upload_file` to a bucket with no abort rule

```defect
id:       CL-ST2-b
file:     services/worker/worker/report_export.py
line:     47
severity: low
command:  /cost-review
class:    FIN-ST-2
owner:    finops
bucket:   report-with-fix
detector: storage-growth-scan §2
anchor:   s3.upload_file(zip_path, settings.REPORTS_BUCKET
match:    upload_file|manifest|zip|REPORTS_BUCKET
match:    abort|incomplete|multipart
```

boto3 switches to multipart above 8 MB; the ZIPs are 40–400 MB and `qw-prod-reports` has no abort rule. Proof V584. Fix: the abort rule on the reports bucket.

## CL-ST3-a — `tracking_events` gets a row per poll result and is never pruned

```defect
id:       CL-ST3-a
file:     apps/api/src/tracking/tracking-event.entity.ts
line:     5
severity: medium
command:  /cost-review
class:    FIN-ST-3
owner:    finops
bucket:   report-with-fix
detector: storage-growth-scan §3
anchor:   @Entity({ tableName: 'tracking_events' })
match:    tracking_events|TrackingEvent
match:    retention|purge|prune|delete|partition|grow|append
```

2–6 KB of raw carrier JSON per scan per poll (CL-FQ1-a writes them every 15 s); no job deletes, partitions or expires them, and the retention page does not list the table. RDS storage never shrinks. Proof V585 (scratch DB: old rows deleted, young kept, schedule registered). Fix: a retention job (e.g. 90 days after delivery) or monthly partitions dropped by pg_partman.

## CL-ST3-b — `carrier_poll_attempts` grows by one row per billed call

```defect
id:       CL-ST3-b
file:     services/worker/worker/models.py
line:     28
severity: medium
command:  /cost-review
class:    FIN-ST-3
owner:    finops
bucket:   report-with-fix
detector: storage-growth-scan §3
anchor:   __tablename__ = "carrier_poll_attempts"
match:    carrier_poll_attempts|CarrierPollAttempt
match:    retention|purge|prune|delete|partition|grow
```

Inserted on every rate-card call (including CL-FQ3-b's spins) for an SLA review; nothing deletes it. Proof V585. Fix: a retention job sized to the SLA review window.

## CL-ST4-a — The API writes an unrotated log file inside the pod

```defect
id:       CL-ST4-a
file:     apps/api/src/logging/logger.ts
line:     10
severity: low
command:  /cost-review
class:    FIN-ST-4
owner:    finops
bucket:   report-with-fix
detector: storage-growth-scan §4
anchor:   new winston.transports.File({ filename: '/var/log/quaywise/api.log' })
match:    winston|api\.log|File|log file
match:    rotat|maxsize|maxFiles|disk|grow|stdout|cap
```

Besides stdout, every log line goes to a file with no `maxsize`/`maxFiles` and no rotation; it grows on the node's disk until the pod is evicted. Proof V586. Fix: drop the file transport (stdout is shipped) or rotate with a cap.

## CL-ST4-b — The worker's spool `emptyDir` has no size limit and is never cleaned

```defect
id:       CL-ST4-b
file:     k8s/base/worker.yaml
line:     46
severity: low
command:  /cost-review
class:    FIN-ST-4
owner:    finops
bucket:   report-with-fix
detector: storage-growth-scan §4
anchor:   emptyDir: {}
match:    emptyDir|spool|worker
match:    sizeLimit|cap|grow|clean|evict|disk
```

`report_export.py` writes each day's manifest ZIPs into `/var/spool/quaywise` and never removes them; the volume is an `emptyDir: {}` with no `sizeLimit`. Proof V586. Fix: delete the ZIP after upload and set `sizeLimit`.

## CL-EG1-a — Merchant logos are served from the S3 origin host

```defect
id:       CL-EG1-a
file:     apps/api/src/branding/brand-assets.ts
line:     2
severity: medium
command:  /cost-review
class:    FIN-EG-1
owner:    finops
bucket:   report-with-fix
detector: egress-trace §1
anchor:   const BRAND_ASSET_HOST = 'https://qw-prod-brand.s3.eu-central-1.amazonaws.com';
match:    BRAND_ASSET_HOST|logo|brand|s3\.eu-central-1
match:    CDN|CloudFront|origin|egress|edge
```

Every tracking page view and every notification e-mail loads the logo straight from the bucket: all origin egress, no edge cache, while a CloudFront distribution already fronts the static assets. Proof V587 (URL-builder test asserts the CDN host). Fix: serve `qw-prod-brand` through the CDN host.

## CL-EG1-b — The tracking page's photo thumbnails use the S3 origin host in prod

```defect
id:       CL-EG1-b
file:     k8s/overlays/prod/config.yaml
line:     8
severity: medium
command:  /cost-review
class:    FIN-EG-1
owner:    finops
bucket:   report-with-fix
detector: egress-trace §1
anchor:   PUBLIC_MEDIA_BASE_URL: https://qw-prod-media.s3.eu-central-1.amazonaws.com
match:    PUBLIC_MEDIA_BASE_URL|media|thumbnail|s3\.eu-central-1
match:    CDN|CloudFront|origin|egress|edge
```

`PodPhotosService.publicUrl` builds the public thumbnails from `PUBLIC_MEDIA_BASE_URL`, and the deployed prod value is the bucket's origin endpoint (dev already uses its CDN host). Proof V587. Fix: the CDN host in the prod overlay.

## CL-EG2-a — Full-size delivery photos stream through the API pods

```defect
id:       CL-EG2-a
file:     apps/api/src/media/pod-photos.controller.ts
line:     28
severity: low
command:  /cost-review
class:    FIN-EG-2
owner:    finops
bucket:   report-with-fix
detector: egress-trace §2
anchor:   return reply.send(object.Body);
match:    pod-photos|photo|GetObject|reply\.send
match:    stream|proxy|through the (api|app|pod)|signed URL|redirect|egress
```

The tenant check runs once, then 3–6 MB per photo is piped through the pod: pod egress (through the NAT) plus CPU, where a short-lived signed URL would keep the same check. Proof V587 (the route answers a redirect and streams no body). Fix: `reply.redirect(await getSignedUrl(...))` after the ownership check.

## CL-EG2-b — Daily manifest ZIPs stream through the API to every depot

```defect
id:       CL-EG2-b
file:     apps/api/src/manifests/manifests.controller.ts
line:     23
severity: low
command:  /cost-review
class:    FIN-EG-2
owner:    finops
bucket:   report-with-fix
detector: egress-trace §2
anchor:   return new StreamableFile(object.Body as Readable, {
match:    manifest|StreamableFile|zip|GetObject
match:    stream|proxy|through the (api|app|pod)|signed URL|redirect|egress
```

40–400 MB per carrier per day, downloaded several times a day by depot systems, piped through the pod after an API-key guard. Proof V587. Fix: a signed-URL redirect after the guard.

## CL-EG3-a — Labels are archived from Frankfurt into a us-east-1 bucket

```defect
id:       CL-EG3-a
file:     apps/api/src/labels/label-archive.client.ts
line:     8
severity: medium
command:  /cost-review
class:    FIN-EG-3
owner:    finops
bucket:   report-with-fix
detector: egress-trace §3
anchor:   private readonly s3 = new S3Client({ region: 'us-east-1' });
match:    us-east-1|label.?archive|S3Client|region
match:    cross.?region|region|eu-central-1|transfer|parity
```

Every rendered label is written from eu-central-1 pods to `qw-label-archive` in us-east-1: inter-region transfer on every label, the new `EUC1-USE1-AWS-Out-Bytes` line on the September bill (CL-UE4-b). Not DR: ADR-0007's replica region is eu-west-1. Proof V588 (config parity: every client region = the deploy region). Fix: move the archive to eu-central-1 (or replicate it there and write locally).

## CL-EG3-b — The worker reads and writes the us-east-1 archive too

```defect
id:       CL-EG3-b
file:     services/worker/worker/manifest_archive.py
line:     10
severity: medium
command:  /cost-review
class:    FIN-EG-3
owner:    finops
bucket:   report-with-fix
detector: egress-trace §3
anchor:   archive_s3 = boto3.client("s3", region_name="us-east-1")
match:    us-east-1|region_name|archive|boto3
match:    cross.?region|region|eu-central-1|transfer|parity
```

`report_export.py` fetches every label PDF of the day from us-east-1 and uploads the day's ZIP back there: both directions cross regions. Proof V588. Fix: same as CL-EG3-a.

## CL-EG4-a — The API calls the label renderer through its public hostname

```defect
id:       CL-EG4-a
file:     apps/api/src/config/env.schema.ts
line:     43
severity: low
command:  /cost-review
class:    FIN-EG-4
owner:    finops
bucket:   report-with-fix
detector: egress-trace §4
anchor:   LABEL_RENDERER_URL: z.string().url().default('https://labels.quaywise.example/render'),
match:    LABEL_RENDERER_URL|labels\.quaywise|renderer
match:    public|hairpin|internal|svc|cluster\.local|load balancer|NAT
```

The prod overlay does not set `LABEL_RENDERER_URL`, so the API reaches the in-cluster renderer through `labels.quaywise.example` — out through the NAT, back in through the internet-facing ALB. Proof V588 (internal callers name internal hosts). Fix: `http://label-renderer.quaywise.svc.cluster.local:8080/render`.

## CL-EG4-b — The worker posts batch callbacks to the API's public hostname

```defect
id:       CL-EG4-b
file:     services/worker/worker/settings.py
line:     22
severity: low
command:  /cost-review
class:    FIN-EG-4
owner:    finops
bucket:   report-with-fix
detector: egress-trace §4
anchor:   TRACKING_API_BASE_URL = os.environ.get("TRACKING_API_BASE_URL", "https://api.quaywise.example/internal")
match:    TRACKING_API_BASE_URL|api\.quaywise|callback|internal
match:    public|hairpin|svc|cluster\.local|load balancer|NAT
```

Unset in the overlay, so every applied carrier batch posts to `api.quaywise.example` through the public load balancer. Proof V588. Fix: the API's service name.

## CL-PX1-a — The dev runbook's monthly costs carry no date or source

```defect
id:       CL-PX1-a
file:     ai/runbooks/platform-do.md
line:     27
severity: low
command:  /cost-review
class:    FIN-PX-1
owner:    finops
bucket:   report-with-fix
detector: candidate-pricing §4
anchor:   | DOKS node pool | 2 × s-4vcpu-8gb | $96/mo |
match:    \$96|DOKS|runbook|platform-do
match:    undated|date|source|as.?of|provenance|stale
```

Three `$…/mo` rows with no as-of date or source in the row or the table; ADR-0009 shows the dated form. Proof V589 (provenance lint). Fix: the pricing page and read date, or the bill line and its period, on each row.

## CL-PX1-b — The notifications doc prices an SMS with no date or source

```defect
id:       CL-PX1-b
file:     docs/architecture/notifications.md
line:     17
severity: low
command:  /cost-review
class:    FIN-PX-1
owner:    finops
bucket:   report-with-fix
detector: candidate-pricing §4
anchor:   costs $0.0463 per message at our tier
match:    \$0\.0463|SMS|notifications
match:    undated|date|source|as.?of|provenance|stale
```

A per-message price that planning will quote, with no source and no date. Proof V589. Fix: the Twilio pricing page and its read date (or the invoice line).

## Bill seeds — the FOCUS export (`billing/`)

Read only when the run is given the export (`--export=billing/focus-sample.csv`, the key's `Invocation:`) and reads it with `bill-lane.py`; each anchor is one row (the September one where a resource has three).

## CL-UE1-a — The preview database is untagged on the bill

```defect
id:       CL-UE1-a
file:     billing/focus-sample.csv
line:     147
severity: medium
command:  /cost-review
class:    FIN-UE-1
owner:    finops
bucket:   report-with-fix
detector: bill-lane.py attribution (/audit-cost-attribution)
anchor:   2026-09-01T00:00:00Z,2026-10-01T00:00:00Z,Usage,preview database,
match:    preview|qw-preview|222222222222
match:    untagged|unattributed|unallocated|tag
```

Part of the 1,502.66 USD (21.1 %) untagged: the preview account's cluster, nodes and database carry no tags (CL-TG1-a). Proof V589 (tagged + mis-tagged + untagged + untaggable = total, to the cent).

## CL-UE1-b — The label archive bucket is untagged on the bill

```defect
id:       CL-UE1-b
file:     billing/focus-sample.csv
line:     139
severity: medium
command:  /cost-review
class:    FIN-UE-1
owner:    finops
bucket:   report-with-fix
detector: bill-lane.py attribution (/audit-cost-attribution)
anchor:   2026-09-01T00:00:00Z,2026-10-01T00:00:00Z,Usage,S3 Standard storage qw-label-archive,
match:    label.?archive|us-east-1|S3
match:    untagged|unattributed|unallocated|tag
```

The us-east-1 archive bucket is not in any Terraform root and carries no tags. Proof V589.

## CL-UE1-c — The media bucket's spend is mis-tagged (`Team`)

```defect
id:       CL-UE1-c
file:     billing/focus-sample.csv
line:     137
severity: medium
command:  /cost-review
class:    FIN-UE-1
owner:    finops
bucket:   report-with-fix
detector: bill-lane.py attribution (/audit-cost-attribution)
anchor:   2026-09-01T00:00:00Z,2026-10-01T00:00:00Z,Usage,S3 Standard storage qw-prod-media,
match:    media|qw-prod-media|Team
match:    mis-?tag|Team|case|variant
```

The `Team` key of CL-TG2-a on the bill: counted mis-tagged, and absent from `--by tag:team` (growth shows 38.47 USD for the quarter). Proof V589.

## CL-UE1-d — QuickSight is tagged `env=production`

```defect
id:       CL-UE1-d
file:     billing/focus-sample.csv
line:     149
severity: medium
command:  /cost-review
class:    FIN-UE-1
owner:    finops
bucket:   report-with-fix
detector: bill-lane.py attribution (/audit-cost-attribution)
anchor:   2026-09-01T00:00:00Z,2026-10-01T00:00:00Z,Usage,QuickSight authors
match:    QuickSight|analytics|333333333333|production
match:    mis-?tag|production|allowed|value
```

Created in the console, tagged `env=production`, outside the policy's set. Proof V589.

## CL-UE3-a — The node-pool Savings Plan expires in 42 days

```defect
id:       CL-UE3-a
file:     billing/commitments.csv
line:     2
severity: medium
command:  /cost-review
class:    FIN-UE-3
owner:    finops
bucket:   report-flagged
detector: bill-lane.py commitments (commitment-coverage)
anchor:   sp-0a1b2c3d,Compute Savings Plan
match:    sp-0a1b2c3d|savings plan|commitment
match:    expir|renew|42 days|2026-11-30|coverage
```

Covers the whole general node pool at 100 % utilisation and ends 2026-11-30; without a renewal decision the pool drops to on-demand (list rate ~1.5× in this export). A person decides the term and size (precedents § 4).

## CL-UE3-b — Half the RDS reservation is paid for a database that no longer exists

```defect
id:       CL-UE3-b
file:     billing/focus-sample.csv
line:     134
severity: medium
command:  /cost-review
class:    FIN-UE-3
owner:    finops
bucket:   report-flagged
detector: bill-lane.py commitments (commitment-coverage)
anchor:   2026-09-01T00:00:00Z,2026-10-01T00:00:00Z,Usage,"reserved db.r6g.large
match:    qw-orders-ri|reserv|RI|db\.r6g\.large
match:    unused|utili[sz]ation|50 ?%|idle|wasted
```

The RI covers two `db.r6g.large`; only `qw-orders` matches (the reporting replica was retired): 50 % utilisation, 213.44 USD a month unused until 2027-03-31. A person decides (move a matching workload onto it, or accept).

## CL-UE4-a — SQS requests tripled in September

```defect
id:       CL-UE4-a
file:     billing/focus-sample.csv
line:     140
severity: medium
command:  /cost-review
class:    FIN-UE-4
owner:    finops
bucket:   report-flagged
detector: bill-lane.py split (spend-anomaly-triage)
anchor:   ,61800000,
match:    SQS|Requests|label.?requests|61\.?8
match:    usage|spike|tripl|short poll|increase
```

61.8 M requests against 19.1 M in August: a usage effect of +17.08 USD with no traffic change; the cause is CL-FQ2-a's short polling. Confirm against the September deploy log before reporting it as explained.

## CL-UE4-b — A new inter-region transfer line appears in September

```defect
id:       CL-UE4-b
file:     billing/focus-sample.csv
line:     141
severity: medium
command:  /cost-review
class:    FIN-UE-4
owner:    finops
bucket:   report-flagged
detector: bill-lane.py split (spend-anomaly-triage)
anchor:   EUC1-USE1-AWS-Out-Bytes
match:    EUC1-USE1|transfer|inter.?region|us-east-1
match:    mix|new line|new|cross.?region|appear
```

2,150 GB from eu-central-1 to us-east-1 (43.00 USD), a line that did not exist in August: a mix change, the label archive's writes (CL-EG3-a/b).

## Routed rows — scored only under their owner

Each is listed by `/cost-review` as `→ <owner pack> <skill> §n` (or `N/A (owner pack <x> not installed)`), priced at most, and never graded there; a `/cost-review` finding on one is UNMATCHED, not credited.

## CL-HO-INF — The worker's KEDA ScaledObject has no maxReplicaCount

```defect
id:       CL-HO-INF
file:     k8s/overlays/prod/keda-worker.yaml
line:     2
severity: medium
command:  /infra-audit
class:    INF §8 K-HPA-COST (scale ceiling)
owner:    infrastructure
bucket:   routed
detector: infrastructure iac-cost-scan §8 (KEDA default 100)
anchor:   kind: ScaledObject
match:    ScaledObject|KEDA|quaywise-worker|maxReplicaCount
match:    maxReplicaCount|ceiling|100|unbounded|max
```

No `maxReplicaCount`: KEDA's default ceiling is 100 workers on a queue backlog. Infrastructure's scale-ceiling row; `/cost-review` lists it `→ infrastructure iac-cost-scan §8` and prices it through `candidate-pricing` only.

## CL-HO-OBS — The LLM token counter carries a `user_id` label

```defect
id:       CL-HO-OBS
file:     apps/api/src/metrics/metrics.ts
line:     18
severity: medium
command:  /obs-audit
class:    OBS §1 unbounded label
owner:    observability
bucket:   routed
detector: observability metric-hygiene-scan §1
anchor:   labelNames: ['tenant', 'feature', 'user_id', 'direction'],
match:    user_id|llm_gateway_tokens_total|label
match:    cardinality|unbounded|series|label
```

One series per user per tenant per feature. Observability's class; `/cost-review` prices the series (flat-rate: self-hosted Prometheus with `retentionSize`, precedents § 1) and never re-grades it.

## CL-HO-PERF — The content-hashed widget bundle is served `no-store`

```defect
id:       CL-HO-PERF
file:     apps/api/src/widget/widget.controller.ts
line:     18
severity: medium
command:  /perf-audit
class:    PERF §6 HTTP caching headers
owner:    performance
bucket:   routed
detector: performance caching-scan §6
anchor:   reply.header('cache-control', 'no-store');
match:    widget|no-store|cache-control|bundle
match:    immutable|max-age|cache|hash
```

A file whose name changes with its content can be `public, max-age=31536000, immutable`; `no-store` makes every merchant page view re-download it from the origin. Performance's class; finops prices the origin egress only.

## CL-HO-AI — The gateway call sets no `max_tokens`

```defect
id:       CL-HO-AI
file:     apps/api/src/llm/gateway.client.ts
line:     37
severity: medium
command:  /ai-audit
class:    AI §B2 output cap
owner:    ai-engineering
bucket:   routed
detector: ai-engineering llm-gateway-audit §B2
anchor:   body: JSON.stringify({ model: this.config.llmModel, messages, temperature: 0.2 }),
match:    max_tokens|gateway|completions|body
match:    max_tokens|output cap|output tokens|unbounded|limit
```

No per-call output cap on a public route. ai-engineering's class (the per-call half); the aggregate half is CL-PS1-a, finops'.

## Decoys — must NOT be reported

Each mirrors a precedent in `templates/snippets/precedents/finops.md` (the class line names it) or a grep trap a detector's `Measured` paragraph names; reporting one is a false positive in every run its `command:` names.

```decoy
id:       CL-DECOY-01
file:     infra/terraform/envs/analytics/main.tf
line:     22
command:  /cost-review
class:    decoy/BG-1 (precedents/finops.md § 9)
anchor:   provider "aws" {
match:    analytics|333333333333|provider
match:    budget|BG-1|no budget
```

No budget in this root, and ADR-0003 cites the org-billing budget `qw-analytics-monthly` by name and path.

```decoy
id:       CL-DECOY-02
file:     apps/api/src/audit/audit-log.entity.ts
line:     4
command:  /cost-review
class:    decoy/ST-3 (§ 21, § 3)
anchor:   @Entity({ tableName: 'audit_log' })
match:    audit_log|AuditLog
match:    retention|purge|grow|append|delete
```

Append-only, but `AuditRetentionJob` deletes rows older than the 7-year floor `docs/compliance/retention.md` sets.

```decoy
id:       CL-DECOY-03
file:     apps/api/src/audit/audit-retention.job.ts
line:     8
command:  /cost-review
class:    decoy/ST-3 (§ 3, § 21)
anchor:   const AUDIT_LOG_RETENTION_YEARS = 7;
match:    audit|7 years|AUDIT_LOG_RETENTION
match:    too long|shorten|excess|storage|grow|retention
```

Seven years is the documented compliance floor; shortening it needs the compliance page changed first.

```decoy
id:       CL-DECOY-04
file:     infra/terraform/envs/prod/main.tf
line:     91
command:  /cost-review
class:    decoy/EG-3 · waste (§ 2, § 24)
anchor:   resource "aws_db_instance" "orders_dr_replica" {
match:    orders_dr|replica|eu-west-1|DR
match:    cross.?region|idle|waste|unused|region|duplicate
```

A warm standby in eu-west-1 with an RTO of 4 h and an RPO of 15 min in ADR-0007; its cost is bought on purpose.

```decoy
id:       CL-DECOY-05
file:     infra/terraform/envs/prod/main.tf
line:     65
command:  /cost-review
class:    decoy/BG-6 (§ 5)
anchor:   min_size     = 3
match:    general|node.?group|min_size|prod
match:    floor|always.?on|non.?prod|schedule|scale.?to.?zero|idle
```

A prod node floor, not a non-prod one.

```decoy
id:       CL-DECOY-06
file:     apps/api/src/outbox/outbox-relay.ts
line:     22
command:  /cost-review
class:    decoy/FQ-1 (§ 1, § 17)
anchor:   @Cron(CronExpression.EVERY_MINUTE)
match:    outbox|relay|EVERY_MINUTE
match:    every minute|frequency|billed|1,?440|calls/day|poll
```

A minute-level outbox relay that reads the fixed-size orders database and publishes to in-cluster Redis: contention at most, never money.

```decoy
id:       CL-DECOY-07
file:     apps/api/src/geocoding/geocoder.service.ts
line:     24
command:  /cost-review
class:    decoy/PS-1 (§ 16 cleared)
anchor:   await this.credits.debit(tenantId, 'geocode', 1);
match:    geocod|credit|MapGrid
match:    cap|budget|aggregate|per.?tenant|org|month
```

Per-tenant credits alone would leave PS-1 open (§ 16), but the next line reserves from the org-wide `GEOCODER_MONTHLY_CAP` before the call.

```decoy
id:       CL-DECOY-08
file:     apps/api/src/exports/exports.controller.ts
line:     24
command:  /cost-review
class:    decoy/EG-1 · EG-2 (§ 22)
anchor:   const url = await getSignedUrl(this.s3, command, { expiresIn: 300 });
match:    export|getSignedUrl|presign|download
match:    presign|origin|CDN|egress|stream|proxy
```

A merchant downloads their own export a few times through a 5-minute presigned redirect: private, low volume, no bytes through the pod.

```decoy
id:       CL-DECOY-09
file:     k8s/overlays/prod/config.yaml
line:     30
command:  /cost-review
class:    decoy/EG-1 (pass)
anchor:   ASSETS_CDN_BASE_URL: https://d3k9qw7example.cloudfront.net
match:    ASSETS_CDN|cloudfront|assets
match:    origin|CDN|egress
```

Static assets already resolve to the CloudFront host.

```decoy
id:       CL-DECOY-10
file:     apps/api/src/queue/status-events.consumer.ts
line:     27
command:  /cost-review
class:    decoy/FQ-2 (§ 18)
anchor:   WaitTimeSeconds: 20,
match:    status.?events|WaitTimeSeconds|ReceiveMessage
match:    short poll|empty receive|WaitTimeSeconds|long poll
```

Long polling at the maximum wait.

```decoy
id:       CL-DECOY-11
file:     apps/api/src/queue/status-events.consumer.ts
line:     23
command:  /cost-review
class:    decoy/FQ-3 (§ 18)
anchor:   while (!this.stopping) {
match:    while|stopping|status.?events
match:    busy|tight|delay|sleep|backoff
```

The loop's receive blocks up to 20 s: the blocking receive is the sleep.

```decoy
id:       CL-DECOY-12
file:     apps/api/src/webhooks/webhook-delivery.entity.ts
line:     4
command:  /cost-review
class:    decoy/ST-3 (pass)
anchor:   @Entity({ tableName: 'webhook_deliveries' })
match:    webhook_deliveries|WebhookDelivery
match:    retention|purge|grow|append|delete
```

A 30-day retention job deletes by `createdAt`, and its spec seeds an older and a younger row.

```decoy
id:       CL-DECOY-13
file:     k8s/monitoring/prometheus.yaml
line:     11
command:  /cost-review
class:    decoy/flat-rate (§ 1, research F-11)
anchor:   retentionSize: 18GB
match:    prometheus|retentionSize|20Gi
match:    \$|cost|series|cardinality|price|retention
```

Self-hosted on a 20 Gi PVC with `retentionSize`: cardinality and retention cost disk, not money (CL-HO-OBS is contention, not a priced row).

```decoy
id:       CL-DECOY-14
file:     k8s/overlays/prod/hpa.yaml
line:     11
command:  /cost-review
class:    decoy/BG-6 (§ 5)
anchor:   minReplicas: 2
match:    minReplicas|hpa|quaywise-api|prod
match:    floor|always.?on|non.?prod|idle|waste|schedule
```

Two replicas in two zones for the 99.9 % SLO (ADR-0007): a prod purchase.

```decoy
id:       CL-DECOY-15
file:     docs/adr/0009-dev-on-digitalocean.md
line:     15
command:  /cost-review
class:    decoy/PX-1 (pass)
anchor:   $48/mo per node (DigitalOcean pricing page, read 2026-09-14)
match:    \$48|ADR-0009|DOKS|pricing
match:    undated|date|source|provenance
```

Dated and sourced in the row.

```decoy
id:       CL-DECOY-16
file:     k8s/monitoring/alertmanager.yaml
line:     22
command:  /cost-review
class:    decoy/BG-7 (§ 11)
anchor:   inhibit_rules:
match:    inhibit|alertmanager
match:    suppress|mute|silence|expiry|no end
```

Critical inhibits warning for the same alertname and namespace: topology, not a mute.

```decoy
id:       CL-DECOY-17
file:     ai/runbooks/platform-do.md
line:     44
command:  /cost-review
class:    decoy/BG-7 (§ 11)
anchor:   "endsAt": "2026-10-03T12:00:00Z",
match:    silence|endsAt|matchers
match:    suppress|mute|expiry|no end|permanent
```

A silence with an end.

```decoy
id:       CL-DECOY-18
file:     infra/terraform/envs/prod/dns.tf
line:     11
command:  /cost-review
class:    decoy/BG-6 6d grep trap (DNS ttl)
anchor:   ttl     = 300
match:    ttl|route53|dns
match:    TTL|expir|destroy|non.?prod|preview
```

A DNS record's TTL, not an environment TTL tag.

```decoy
id:       CL-DECOY-19
file:     k8s/platform/velero-schedule.yaml
line:     12
command:  /cost-review
class:    decoy/BG-6 6d grep trap (Velero ttl)
anchor:   ttl: 720h0m0s
match:    velero|ttl|backup
match:    TTL|expir|destroy|non.?prod|preview|retention
```

A backup's TTL in a schedule.

```decoy
id:       CL-DECOY-20
file:     ai/runbooks/providers.md
line:     32
command:  /cost-review
class:    decoy/BG-1 1b grep trap
anchor:   The latency budget alert for the tracking API pages the dispatch on-call
match:    latency budget|providers|paging
match:    budget|billing|spend alert|BG-1
```

An SLO latency budget, not a cost budget.

```decoy
id:       CL-DECOY-21
file:     k8s/base/worker.yaml
line:     28
command:  /cost-review
class:    decoy/TG-3 label grep trap (container env list)
anchor:   env:
match:    env|worker
match:    label|team|missing|pod template
```

A container `env:` list; the worker's pod template carries `team` (and the overlay stamps `env`).

```decoy
id:       CL-DECOY-22
file:     .env.example
line:     6
command:  /cost-review
class:    decoy/EG-3 (§ 24)
anchor:   # AWS_REGION=eu-west-2
match:    eu-west-2|AWS_REGION|env\.example
match:    cross.?region|region|mismatch|parity
```

A commented example line for restoring old snapshots locally.

```decoy
id:       CL-DECOY-23
file:     k8s/overlays/prod/config.yaml
line:     32
command:  /cost-review
class:    decoy/EG-4 (§ 23)
anchor:   PUBLIC_ORIGIN: https://track.quaywise.example
match:    PUBLIC_ORIGIN|track\.quaywise
match:    public|hairpin|internal|svc|service.to.service
```

Rendered into SMS and e-mail links only (`tracking-link.ts`); no service calls it.

```decoy
id:       CL-DECOY-24
file:     apps/api/src/media/pod-photos.service.ts
line:     22
command:  /cost-review
class:    decoy/ST-1 (§ 20)
anchor:   new PutObjectCommand({ Bucket: bucketFor(this.config, 'podPhotos')
match:    pod/|proof.of.delivery|photo|PutObject
match:    lifecycle|expir|delete|retention|forever|no rule
```

Proof-of-delivery photos are the merchant's evidence, kept for the life of the account (retention page): a business record — ask, not ST-1.

```decoy
id:       CL-DECOY-25
file:     infra/terraform/envs/prod/queues.tf
line:     20
command:  /cost-review
class:    decoy/FQ-2 (pass)
anchor:   receive_wait_time_seconds  = 20
match:    status_events|receive_wait_time_seconds
match:    short poll|WaitTimeSeconds|long poll|0
```

The status queue sets the long-poll attribute.

```decoy
id:       CL-DECOY-26
file:     k8s/base/address-revalidate-cronjob.yaml
line:     41
command:  /cost-review
class:    decoy/ST-4 (pass)
anchor:   sizeLimit: 64Mi
match:    sizeLimit|emptyDir|tmp
match:    sizeLimit|grow|cap|disk
```

Scratch for a read-only root filesystem, capped.

```decoy
id:       CL-DECOY-27
file:     k8s/overlays/dev/config.yaml
line:     9
command:  /cost-review
class:    decoy/EG-1 (pass)
anchor:   PUBLIC_MEDIA_BASE_URL: https://qw-dev-media.fra1.cdn.digitaloceanspaces.com
match:    qw-dev-media|cdn\.digitaloceanspaces|dev
match:    origin|CDN|egress
```

The `.cdn.digitaloceanspaces.com` host is the Spaces CDN.

## Detector measurement — the six finops pre-flights, the plan and render lanes, and `bill-lane.py`

Measured 2026-10-19 on a copy staged the way `run.sh` stages it (the tree minus this key), from the copy's root, with
every pre-flight block run verbatim from its `SKILL.md` under `/bin/bash` 3.2 and the documented `ROOTS=(.)` (rg 15.2,
jq 1.7.1). The plan lanes read this tree's `infra/terraform/plans/{prod,preview}.plan.json` copied to `$OUT/plan-*.json`
(`guard.jq`, `tags.jq`); the render lanes read `kubectl kustomize k8s/overlays/{prod,dev}` (offline, `KUBECONFIG` an empty
scratch file) converted to JSON arrays (`labels.jq`, the § 6 quota jq). `tags.jq` and `labels.jq` ran with the policy's sets from
`ai/finops/attribution.md` substituted for the block's example `REQ`/`ALLOWED` line, as its comment says. The prod plan
carries `after_unknown` for its three ARN-bearing changes (the budget's topic list, the topic, the anomaly subscriber), as
`terraform show -json` writes it. No cloud CLI,
Terraform, Infracost or kubectl call reached a network or a cluster. Nothing was written into the copy (`find -newer` on
a stamp: 0 files). These are the detectors' raw rows, not a `/cost-review` result.

Wall time per block: `guardrail-scan` 0.19 s (59 lines), `allocation-scan` 0.13 s (37), `spend-path-scan` 0.16 s (92),
`storage-growth-scan` 0.14 s (52), `egress-trace` 0.10 s (31), `candidate-pricing` 0.07 s (19). No `rg` exit 2 in any
block (no `BLOCKED` line).

**All 52 finops seeds are printed by their owning lane**: 36 at their exact line; 16 as a listed file, a plan or
render row naming the resource, a per-file count pair (5a/5b), the odd region value (3a) or a printed absence the read
closes (an inventory line with no `SpendGuard` beside it, an empty 1b, 3, 5b, 6b, 6d). The first run printed 47: the
other 5 (`CL-TG1-b`, `CL-EG3-b`, `CL-EG4-a`, `CL-EG4-b`, `CL-PX1-b`) were detector gaps, closed in the detectors (below),
not seeds bent to fit. Routed rows: the
KEDA object's floor line prints in guard 6c and spend 4c, the `user_id` counter's declaration in spend 2; no finops grep
grades any of the four.

Decoys: 15 of 27 print at their line (02, 05, 06, 08, 09, 11–17, 24, 26, 27), 9 more in their file or as a count
(01, 03, 04, 07, 10, 19, 21, 22, 25), and 3 never print (18 and 20 — the 6d quoted-value rule and the 1b look-behinds
the `Measured` paragraphs describe — and 23, whose `PUBLIC_ORIGIN` key names no call target, so 4b keeps it out now
that 4a loads the `.example` hosts). The gap fixes added no decoy. Each printed one is cleared by the precedent its class
line names.

Plan and render lanes. `guard.jq` on the prod plan: `§2 BG-2 aws_budgets_budget.prod_monthly ACTUAL only (thresholds
100)`, `§2 … no threshold below 100 %`, `§3 BG-3 … notifies aws_sns_topic.billing_alerts which no
aws_sns_topic_subscription reads` (the topic list is unknown until apply, so the empty-subscriber rule stays silent), `§4 BG-4 aws_ce_anomaly_monitor.account_total
monitor_type=CUSTOM dimension=-` and the absolute-2500 subscription row; on the preview plan `§1 BG-1 (this plan) no
budget resource` and `§4 BG-4 … no aws_ce_anomaly_monitor` (cleared by ADR-0003: the org monitor covers preview).
`tags.jq`: preview `aws_eks_cluster.preview`, `aws_eks_node_group.preview`, `aws_db_instance.preview missing team,env`;
prod `17 taggable resources of 20` and `aws_s3_bucket.media key case drift: Team for team`. `labels.jq`: prod and dev
`Deployment/…/quaywise-api missing team (on the workload metadata only …)`, dev `Namespace/-/quaywise-dev missing team`;
prod `§2 TG-2 … env=production not in [prod,preview,dev]` on the Namespace, both Deployments and the CronJob.
Quota jq: `[]` for both renders.

`bill-lane.py` (`--self-test` 30/30) on `billing/focus-sample.csv`: `columns` — FOCUS profile, cost column
`EffectiveCost`, 150 rows, USD, periods 2026-07/08/09; `summary --by service` — every period `complete` (31/31, 31/31,
30/30 days), total 7,109.19 over 10 services, sum of groups = total; `attribution --required-keys team,env` with the
policy's sets — tagged 4,641.55 (65.3 %) + mis-tagged 297.98 (4.2 %) + untagged 1,502.66 (21.1 %) + untaggable 667.00
(9.4 %) = 7,109.19 **OK**, top untagged: the unused RI rows (no resource id) 640.32, the preview node group 423.94,
cluster 220.80 and database 150.14, the label archive 67.46; `split --base 2026-08 --cur 2026-09 --by sku` — Δ 60.91 =
rate 0.01 + usage −4.90 + mix 43.00 + unexplained 22.80 (tax rows carry no quantity) **OK**, movers: the new
`EUC1-USE1-AWS-Out-Bytes` line (mix 43.00) and SQS requests (usage 17.08); `commitments --expiry billing/commitments.csv
--as-of 2026-10-19` — coverage 28.4 %, `qw-orders-ri` utilisation 50.0 % (640.32 unused), `sp-0a1b2c3d` 100.0 % and
`EXPIRES in 42 days`. Every exit code 0.

What the first run found in the detectors, and how each gap closed (none changed a seed's verdict; each fix was
re-run here and on a read-only real repo, with a noise delta of 0 rows there):
- **`allocation-scan` § 1 had no static lane for a DigitalOcean resource without `tags`** (1a/1b counted AWS only, 1c
  listed files that already carry tags). Closed by grep 1d, a per-resource walk of the taggable DO types: it prints
  `envs/do/main.tf:23` and not the untaggable Spaces bucket beside it.
- **`labels.jq` checked key presence only.** It now receives `$allowed` and prints the value outside the policy's set
  (`env=production`) on every rendered prod pod template and the namespace.
- **`egress-trace` 3a never counted boto3's `region_name=`** (no word boundary after `region`). The key list now carries
  `region_name` and `aws_?region` (KEDA's `awsRegion:`): us-east-1 counts ×2.
- **`egress-trace` 4a dropped every host ending in `.example`**, so `hosts.txt` was `__no_public_host__` on every
  fixture. It now drops only the bare documentation apexes (`example.com|net|org`) and the internal, `.test` and
  `.invalid` suffixes; a placeholder host still prints in 4b only when a config key names it as a call target.
- **`candidate-pricing` 4a had no per-unit billing words.** It now matches `message`, `msg`, `SMS`, `segment`, `lookup`,
  `call`, `token`, `email` and `per 1,000` (plurals too): `notifications.md:17` prints UNDATED.
- **`guard.jq` § 3's empty-subscriber rule fired on unknown ARNs.** It now skips a subscriber list `after_unknown`
  marks; the topic → subscription join stays the row for this budget.
- **`spend-path-scan` grep 1 missed env-style cap names** (`\bmonthly` has no boundary after `_`). The left edge is a
  look-behind and the middle word takes billed units: the caps' declarations, values and reads print (13 → 31 lines),
  so a repo without a `SpendGuard` class no longer reads every capped client as a PS-1 candidate.
- **`guardrail-scan` § 7's BAD example** said "`amtool silence add` … with no `--duration`/`--end`"; `amtool` defaults
  `--duration` to 1h and the v2 API requires `endsAt`, so the example now names a long explicit end or a silence
  renewed on a schedule.
- Read-only lines the read clears: guard 0d prints only the first line of the runbook's multi-line create (allocation
  4 joins it); spend 4a prints the nightly retention, export and APScheduler jobs (flat-rate or once a day); egress 2a
  prints the presigned export's `GetObjectCommand` (not streamed) and the worker's archive read (no response).

| id | printed by |
|----|------------|
| CL-BG1-a | guard 0a `envs/preview/main.tf:1` (an aws root); 1a prints no budget in it; `guard.jq` on the preview plan: `§1 BG-1 (this plan) no budget resource` |
| CL-BG1-b | guard 0a `envs/do/main.tf:1` (digitalocean); 0d the two `doctl databases create` lines; 1b prints 0 lines — no runbook or ADR names an alert |
| CL-BG2-a | guard 2 `budgets.tf:13`; `guard.jq` prod plan: `§2 BG-2 aws_budgets_budget.prod_monthly ACTUAL only (thresholds 100)` and `no threshold below 100 %` |
| CL-BG2-b | guard 1a `data-account.yaml:23` (`AWS::Budgets::Budget`); 2 `:34` and `:36` (`Threshold: 100`) |
| CL-BG3-a | guard 3 `budgets.tf:14`; 3b prints 0 subscriptions; `guard.jq`: `§3 BG-3 … notifies aws_sns_topic.billing_alerts which no aws_sns_topic_subscription reads` |
| CL-BG3-b | guard 3 `data-account.yaml:40` |
| CL-BG4-a | guard 4 `budgets.tf:27`, `:29` (`monitor_type = "CUSTOM"`), `:52`; `guard.jq`: `§4 BG-4 … monitor_type=CUSTOM dimension=-` and the absolute 2500 subscription row |
| CL-BG4-b | guard 4 `data-account.yaml:50` (`AWS::CE::AnomalySubscription`, 9 lines above; the threshold is read in the block) |
| CL-BG5-a | guard 5a `terraform.yml:36` (and `:27`, `:39`); 5b prints 0 |
| CL-BG5-b | guard 5a `terraform.yml:56` (and `:48`); 5b prints 0 |
| CL-BG6-a | guard 6c `preview/main.tf:55`; 6b and 6d print 0 (no schedule, TTL tag or destroy) |
| CL-BG6-b | guard 6c `dev/hpa.yaml:10`; 6a `dev/namespace.yaml:2` (a namespace); 6b 0; the render jq prints `[]` (no quota or LimitRange) for dev and prod |
| CL-BG7-a | guard 7b `budgets.tf:64` |
| CL-BG7-b | guard 7b `cost-rules.yaml:21` |
| CL-TG1-a | alloc 1a `preview/main.tf:1` against 1b none and 1c none; `tags.jq` on the preview plan: `aws_db_instance.preview missing team,env` (and the cluster and node group) |
| CL-TG1-b | alloc 1d `do/main.tf:23: resource "digitalocean_kubernetes_cluster" "dev" {  (no tags)` |
| CL-TG2-a | alloc 2 counts `1 Team` against `17 team`; `tags.jq` prod plan: `§2 TG-2 aws_s3_bucket.media key case drift: Team for team` |
| CL-TG2-b | `labels.jq` prod render: `§2 TG-2 … env=production not in [prod,preview,dev]` on the Namespace, both Deployments and the CronJob; alloc 3b `prod/kustomization.yaml:11` (`labels:`) and `:15` (`includeTemplates: true`) name the transformer |
| CL-TG3-a | `labels.jq` prod and dev renders: `Deployment/quaywise/quaywise-api missing team (on the workload metadata only: cost tools read the pod template)`; 3a merges the file's keys (`app.kubernetes.io/name team`) |
| CL-TG3-b | alloc 3a `dev/namespace.yaml: app.kubernetes.io/part-of`; `labels.jq` dev render: `Namespace/-/quaywise-dev missing team` |
| CL-TG4-a | alloc 4 (continuation joined) `platform-do.md:11: doctl databases create qw-dev-pg --engine pg … --num-nodes 1`; guard 0d prints the first line |
| CL-TG4-b | alloc 4 `bootstrap.sh:10`; guard 0d `:10` |
| CL-PS1-a | spend 0c `LLM_GATEWAY_URL` ×6 (reached by base URL, no SDK); grep 1 lists `SpendGuard` in the SMS, carrier and geocoder clients and not in `gateway.client.ts`, and the caps `SMS_MONTHLY_CAP`, `CARRIER_MONTHLY_CALL_CAP`, `GEOCODER_MONTHLY_CAP` (`env.schema.ts:38-40`, prod `config.yaml:23-25`) with no `LLM_*` cap |
| CL-PS1-b | spend 0c `ADDRESS_API_BASE_URL` ×6; grep 1 lists `SpendGuard` and `RATES_MONTHLY_CALL_CAP` (`rates_client.py:16`, `settings.py:19`) and no address cap on the Python side |
| CL-PS2-a | spend 0a `sms.service.ts:2` (`twilio`); grep 2 prints 4 metrics in `metrics.ts` (LLM tokens, carrier calls, geocoder lookups, HTTP) — none for SMS |
| CL-PS2-b | spend 2 `rates_client.py:14` |
| CL-PS3-a | spend 3 `providers.md:10` — the only line; it is a rate tier |
| CL-PS3-b | absence: spend 3 prints only the gateway line; nothing names a Twilio limit |
| CL-FQ1-a | spend 4a `carrier-poll.scheduler.ts:23`; 4c prod `hpa.yaml:11-12` (2–6) |
| CL-FQ1-b | spend 4b `address-revalidate-cronjob.yaml:10` |
| CL-FQ2-a | spend 5a `label-requests.consumer.ts:2` against 5b none for that file; 5c `queues.tf:3` against 5d `:1` |
| CL-FQ2-b | spend 5a `sqs_consumer.py:1` against 5b none for that file |
| CL-FQ3-a | spend 6 `label-job.poller.ts:16` |
| CL-FQ3-b | spend 6 `rate_sync.py:26` |
| CL-ST1-a | store 1a `export-runner.ts:22`; 1b `object-store.ts:6` (`exports/`); 1c the only prefix rule is `tmp-uploads/` (`storage.tf:17`); 1d only the imports delete |
| CL-ST1-b | store 1a `report_export.py:40` and `:47`; 1c no rule on the reports bucket; 1d no delete |
| CL-ST2-a | store 2a `bulk-import.service.ts:22`; 2b only `storage.tf:47` (media bucket) |
| CL-ST2-b | store 2a `report_export.py:47`; 2b only the media bucket |
| CL-ST3-a | store 3a `tracking-event.entity.ts:5`; 3b names only `webhook_deliveries`, `audit_log` and `outbox` |
| CL-ST3-b | store 3a `models.py:28`; 3b has no Python retention path |
| CL-ST4-a | store 4a `logger.ts:10`; 4b prints 0 |
| CL-ST4-b | store 4c `worker.yaml:46` |
| CL-EG1-a | egress 1a `brand-assets.ts:2` |
| CL-EG1-b | egress 1a `prod/config.yaml:8` (and dev `:9`, the CDN host) |
| CL-EG2-a | egress 2a `pod-photos.controller.ts:26` + 2b `:28` (same handler) |
| CL-EG2-b | egress 2a `manifests.controller.ts:22` + 2b `:23` |
| CL-EG3-a | egress 3a `us-east-1 ×1` against `eu-central-1 ×10` (the odd value; the count names no file — the read finds this line) |
| CL-EG3-b | egress 3a `us-east-1 ×2` (the TypeScript client and this boto3 `region_name=`) against `eu-central-1 ×11` |
| CL-EG4-a | egress 4a `labels.quaywise.example`; 4b `env.schema.ts:43` |
| CL-EG4-b | egress 4a `api.quaywise.example`; 4b `settings.py:22` |
| CL-PX1-a | price 4a/4b `platform-do.md:27` UNDATED (and `:28`, `:29`) |
| CL-PX1-b | price 4a/4b `notifications.md:17` UNDATED |
| CL-UE1-a | `attribution` untagged top rows: preview node group 423.94, cluster 220.80, `qw-preview-pg` 150.14 |
| CL-UE1-b | `attribution` untagged `arn:aws:s3:::qw-label-archive` 67.46 |
| CL-UE1-c | `attribution` mis-tagged 297.98 (with CL-UE1-d); `summary --by tag:team` growth 38.47 |
| CL-UE1-d | `attribution` mis-tagged 297.98 (with CL-UE1-c) |
| CL-UE3-a | `commitments --expiry … --as-of 2026-10-19`: `sp-0a1b2c3d … utilisation 100.0% · end 2026-11-30 EXPIRES in 42 days` |
| CL-UE3-b | `commitments`: `qw-orders-ri used 640.32 unused 640.32 … utilisation 50.0%` |
| CL-UE4-a | `split 2026-08 → 2026-09 --by sku`: `EUC1-Requests-Tier1 [priced] usage 17.08, rate 0.00` |
| CL-UE4-b | `split`: `EUC1-USE1-AWS-Out-Bytes [mix: new line] mix 43.00` |
| CL-HO-INF | guard 6c and spend 4c print `keda-worker.yaml:8` (`minReplicaCount: 1`, a prod floor, § 5); no finops grep looks for the missing ceiling |
| CL-HO-OBS | spend 2 `metrics.ts:15` (the counter's declaration, read for PS-2); the label is observability's |
| CL-HO-PERF | not printed by a finops grep (caching headers are performance's) |
| CL-HO-AI | not printed by a finops grep (spend 0c inventories the gateway by `LLM_GATEWAY_URL`; 0d says ai-engineering is not installed) |

| decoy | printed by → cleared by |
|-------|------------------------|
| CL-DECOY-01 | guard 0a `analytics/main.tf:1`; 1a none — cleared by ADR-0003 → precedents/finops.md § 9 |
| CL-DECOY-02 | store 3a `:4`; 3b `audit-retention.job.ts:17` names it → § 21, § 3 |
| CL-DECOY-03 | store 3b `:11` and `:17` (the class and its delete) → § 3, § 21 |
| CL-DECOY-04 | egress 3a `eu-west-1 ×1` (the DR provider's region) → § 2, § 24 |
| CL-DECOY-05 | guard 6c `prod/main.tf:65` → § 5 |
| CL-DECOY-06 | spend 4a `outbox-relay.ts:22` → § 1, § 17 |
| CL-DECOY-07 | spend 1 `geocoder.service.ts:5`, `:19` (`SpendGuard`), `:25` (`GEOCODER_MONTHLY_CAP`); 0c `GEOCODER_API_URL` → § 16 cleared |
| CL-DECOY-08 | egress 1b `:24`; 2a `:23` (the command, not streamed) → § 22 |
| CL-DECOY-09 | egress 1a `prod/config.yaml:30` → pass |
| CL-DECOY-10 | spend 5a `:2` against 5b `:1` (the file pairs) → § 18 |
| CL-DECOY-11 | spend 6 `status-events.consumer.ts:23` → § 18 |
| CL-DECOY-12 | store 3a `:4`; 3b `webhook-retention.job.ts:10`, `:16` → pass |
| CL-DECOY-13 | price 1 `prometheus.yaml:11`, `:29` → § 1, research F-11 |
| CL-DECOY-14 | guard 6c `prod/hpa.yaml:11`; spend 4c → § 5 |
| CL-DECOY-15 | price 4b `0009-dev-on-digitalocean.md:15` dated → pass |
| CL-DECOY-16 | guard 7a `alertmanager.yaml:22` → § 11 |
| CL-DECOY-17 | guard 7a `platform-do.md:44` → § 11 |
| CL-DECOY-18 | guard 6d prints 0 (the quoted-value rule keeps it out) → DNS ttl |
| CL-DECOY-19 | not printed (6d reads Terraform and CI only); spend 4b prints the schedule `:7` → Velero ttl |
| CL-DECOY-20 | guard 1b prints 0 (the latency/error/burn look-behinds) → decoy/BG-1 1b grep trap |
| CL-DECOY-21 | alloc 3a reads `labels:` blocks only: `worker.yaml: app.kubernetes.io/name team` → container env list |
| CL-DECOY-22 | egress 3a `eu-west-2 ×1` → § 24 |
| CL-DECOY-23 | not printed: 4a loads `track.quaywise.example`, and 4b skips the line because `PUBLIC_ORIGIN` names no call target → § 23 |
| CL-DECOY-24 | store 1a `pod-photos.service.ts:22`; 1b `object-store.ts:9` → § 20 |
| CL-DECOY-25 | spend 5d `queues.tf:1` → pass |
| CL-DECOY-26 | store 4c `:40`, `:41` → pass |
| CL-DECOY-27 | egress 1a `dev/config.yaml:9` → pass |
