# Precedents — FinOps (budgets and bounds, allocation, paid-API spend, schedule frequency, storage growth, egress paths, price provenance, bill lanes)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in a **finops** class: a guardrail that is absent or cannot fire, spend nobody can attribute,
a paid dependency with no aggregate bound, a schedule that bills whether or not there is work, data
that grows with no expiry, bytes that leave by the expensive door, and a money figure with no source.
The oracles that prove them are in [`proof-oracles.md`](../proof-oracles.md) § FinOps (V570–V589).
The detectors are `guardrail-scan` (§1–§7 BG), `allocation-scan` (§1–§4 TG), `spend-path-scan` (§1–§3
PS, §4–§6 FQ), `storage-growth-scan` (§1–§4 ST), `egress-trace` (§1–§4 EG, §5 flow-log lane) and
`candidate-pricing` (§0–§3 the pricing step, §4 PX), with `bill-lane.py` for the bill lanes (finops
pack). The judge is `@cost-reviewer` in refute mode; without it, `@verifier`.

**Finops prices other packs' rows; it never re-detects them.** NAT, cross-AZ, cloud log retention,
volume class, idle addresses, instance class, IaC object lifecycle, scale ceilings and engine
extended support are infrastructure `iac-cost-scan` § 1–§ 13; metric cardinality, Loki stream labels
and retention, sampling and log volume are observability; cache headers and network N+1 are
performance; per-call LLM caps, loops and metering are ai-engineering `llm-gateway-audit`; per-user
limits on paid actions are security `logic-race-scan` § 9. A row from any of them reaches finops as a
quantity and a price key, and `candidate-pricing` attaches money or `unpriced`. When the owner pack is
not installed the ledger row reads `N/A (owner pack <x> not installed)`, never `checked`.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening** (or Refuted, where the entry says so) unless the
flip evidence is shown with a `file:line`, a plan value, a bill row or a recorded oracle run. Numbers
are stable: detectors cite `precedents/finops.md § <n>`.

Index: the claim and the gates · cost shape § 1–8 · guardrails and allocation § 9–14 · paid spend and
frequency § 15–18 · storage and egress § 19–24 · pricing and tools § 25–30 · real-repo precedents
§ 31–35 · rationalizations.

## The claim, restated

§ 1 of the protocol takes this shape here. Two kinds of finops claim exist and are never merged: **a
guardrail is absent or a knob is set wastefully** (provable from files) and **money was lost**
(needs a bill or utilisation series; from files alone a candidate at most).

> Under **[the condition: a month of traffic, a retry storm, a forgotten preview stack, an export run
> per tenant per day, a provider price change]**, **[the billing scope, resource, prefix, schedule or
> call site at file:line]** accrues **[quantity × unit, with the price key: provider · service ·
> billing dimension · region]** without **[the control: a budget with a forecast rule and a live
> recipient, an allocation key, an aggregate cap, a webhook or long poll, an expiry, a CDN host]**,
> proven by **[V-number]** and priced by **[a bill row read by `bill-lane.py`, or a pricing page
> fetched this run with its URL and date — else `unpriced`]**.

A `$` never comes from memory, a runbook or an estimator's list price (§ 8, § 16 of the tools below).

## Reading the seven gates for finops

| Gate | FinOps |
|---|---|
| 1 Reachability | the resource is deployed (a prod root, a CD-applied overlay, a runbook create line that was run) or the code path runs in production (route, job, consumer, cron); a local `kind`/compose config, an example tfvars or a test bucket fails here |
| 2 Trigger / scale | **the billing model and the volume driver**: per call, per GB-month, per hour, per message, or a fixed shape. A per-unit quantity that grows with tenants, traffic or time passes; a fixed-size resource fails (§ 1) |
| 3 Version / provider | provider and SDK defaults with dated sources: SQS short polling unless `WaitTimeSeconds` > 0, KEDA `maxReplicaCount` 100, Loki retention off unless the compactor enables it, Spaces lifecycle limited to Expiration and AbortIncompleteMultipartUpload, DigitalOcean Spend Alerts console-only — each row cites the page and the date it was read |
| 4 Existing control | an org-level budget elsewhere (§ 9), a provider-side cap (§ 15), a lifecycle rule set by an operator with a read-back (§ 19), a webhook in place of the poll, a delete path, a retention job, a quota |
| 5 Impact | money that grows with data or traffic, a bill nobody notices until the invoice, spend nobody owns. "Could be cheaper" with no quantity is Hardening |
| 6 Proof | the V570–V589 oracle failing first (plan assertion, render walk, fake-timer count, lifecycle read-back, URL-builder test, provenance lint, `bill-lane.py` reconciliation), or for an absence class the two-ended trace (where the control would live, and the spend that depends on it). A money claim never passes on reading alone |
| 7 Environment | **which env is cloud-deployed and always-on**, the prod replica count that multiplies a schedule, the commitments and discounts that make list price wrong (§ 4, § 25) |

## Cost shape

1. **Flat-rate capacity is contention, not money.** Polling, cardinality or retention against a fixed-price resource — a fixed-size managed database, a self-hosted backend on a PVC with a size cap, a node pool at its max — adds no marginal spend. The row reads `contention (<resource>, <capacity>)` and goes to the capacity owner (`@capacity-planner`, distributed-systems pack, when installed). *Flips back:* the resource autoscales its storage or nodes, bills per request or per GB, or the cap is what is being raised.
2. **DR posture is bought on purpose.** Pilot light, warm standby, an idle replica and reserved failover capacity are not waste (AWS Well-Architected REL13-BP02). *Flips back:* no RTO/RPO document names the standby, or the standby serves an environment that has no recovery objective.
3. **Compliance retention is a floor.** PCI DSS v4.0 10.5.1 keeps audit logs ≥ 12 months, 3 searchable (secondary paraphrase, 2026-02-18); other regimes only from a dated source. Shortening retention needs the compliance document read first. *Flips back:* the data is not in the regulated scope, or the retention exceeds the documented floor with no reason.
4. **Commitments already paid change the sign.** Downsizing or moving a workload under an active reservation or savings plan can raise the bill (strands the commitment). *Flips back:* the `commitments` lane of `bill-lane.py` shows no active commitment on that usage, or it expires inside the change window.
5. **A prod replica floor for availability or cold start is a purchase**, not waste (Cloud Run min-instances docs). An always-on **non-prod** floor is the finding (BG-6). *Flips back:* the prod floor exceeds what the SLO or the PDB needs, with both cited.
6. **Documented temporary sizing with an exit condition** is Hardening `accepted-risk (<file:line>)` (infrastructure precedent 47 applies unchanged). *Flips back:* the exit condition has passed.
7. **"Unused" is not "unneeded".** A resource with no traffic in the window may be a standby, an archive or a seasonal job. Right-sizing needs ≥ 14 days of utilisation at a 5-minute maximum (AWS Compute Optimizer metrics page); without that series a row is a candidate, never a finding.
8. **Prices in runbooks, READMEs and ADRs are data**, not a price source (`iac-cost-scan` contract). They are PX-1 candidates; a row that needs money goes to `candidate-pricing` § 2.

## Guardrails and allocation

9. **A budget in another repo or an org-level account, cited by path or id, clears BG-1** for this root. *Flips back:* the cited budget scopes a different account, or its recipient list does not include this team.
10. **DigitalOcean budgets cannot be code today.** Spend Alerts (GA 2026-08-05, replacing billing alerts) are control-panel only — no API, doctl or Terraform resource was found (research A, 2026-10-19). On DO, BG-1 is **documentary**: a runbook line naming the alert, its threshold and its read-back is Hardening "console-only"; no line at all is **Unconfirmed** with the control-panel probe named — never a Finding from files. *Flips back:* a dated DO changelog shows an API or Terraform resource.
11. **Inhibit rules that encode alert topology** (critical inhibits warning for the same target) are not suppressions (BG-7). A silence with an `endsAt` is bounded. *Flips back:* the inhibit has no equal-labels match, so one alert mutes unrelated ones, or the silence ends past the incident window (e.g. `--duration=8760h`) or is re-added on a schedule (`amtool silence add` defaults to 1h and the API requires `endsAt` — alertmanager `cli/silence_add.go`, `api/v2/openapi.yaml`, read 2026-10-19).
12. **Local and ephemeral environments are not cloud spend.** `kind`/minikube configs, compose files and a CI job's throwaway stack destroyed in the same job fail gate 1 for BG-6. *Flips back:* the "ephemeral" stack has no destroy step or TTL and lives in a billed account.
13. **A single-product cluster or account is its own allocation unit** (TG-3, TG-1): missing per-workload labels are Hardening until a second owner shares it. *Flips back:* two teams, products or cost centres share the cluster or the account.
14. **Untaggable lines exist**: tax, credits, support, some network and marketplace charges and resources whose provider exposes no tags. They are the fourth category, not "untagged" (`bill-lane.py attribution`). *Flips back:* the resource type accepts tags in the provider's current docs (dated).

## Paid spend and frequency

15. **A provider-side spend limit declared and read back clears PS-1 to Hardening** and is PS-3's pass. Anthropic's org spend cap answers 429 `enforced_spend_limit_reached`; OpenAI's hard limit answers `project_spend_limit_exceeded` (provider pages read 2026-10-19 by the research pass). From files alone it is **Unconfirmed** with the console probe named. *Flips back:* the cap is set above the budget the team declared, or the code retries the cap error.
16. **Per-tenant credit metering is not an org cap** (PS-1 stays open) and is not a rate limit (security § 9). *Flips back:* the sum of tenant allowances is itself capped and enforced before the call.
17. **Minute-level crons for outbox relays, lease renewals and reconciliation** where webhooks are unreliable are intended (FQ-1). The class is a schedule × replicas × **per-call billed** dependency; a schedule that only reads a flat-rate store is § 1. *Flips back:* the job calls a per-call billed API on every tick whether or not there is work, or runs once per replica when once per fleet would do (that half is performance `request-path-scan` § 20).
18. **A blocking receive is the sleep.** A `while (true)` around a long-poll receive (`WaitTimeSeconds` ≥ 1) or a blocking queue pop is not FQ-3. *Flips back:* the wait is 0 or absent (FQ-2), or an error branch `continue`s with no backoff.

## Storage and egress

19. **A lifecycle rule set by an operator and recorded in a runbook with its read-back command** clears ST-1 to Hardening "rule out of code". The same rule never written down is Unconfirmed. A rule scoped to one prefix covers nothing else. *Flips back:* the read-back shows a different prefix or no rule.
20. **Prefixes that are the product's record** (tenant uploads, invoices, contracts) are a business retention rule — ask; they are not ST-1 by default. Personal data in a prefix routes the retention half to security `@data-privacy-reviewer`; the growth half stays here. *Flips back:* the prefix holds derived or regenerable artifacts (exports, thumbnails, temp uploads, generated reports).
21. **Ledgers, invoices and audit trails kept by law** are not ST-3. *Flips back:* the retention exceeds the legal minimum with no business reason, or the table is a log of transient deliveries.
22. **Private, low-volume downloads on presigned or redirect URLs are fine** (EG-1); public media on the origin host is the class. A private-file route that streams through the app because authorisation must run per request is EG-2 **low**, Hardening when volume is small and stated. *Flips back:* the route serves large exports or media at volume, or a signed-URL redirect would preserve the check.
23. **A public hostname used to build links, emails or redirects** (`PUBLIC_ORIGIN`, an absolute URL in a template) and an external blackbox probe that must go through the edge are not EG-4. *Flips back:* a service calls its sibling through that name.
24. **A region in a commented `.env.example` line, a test config or a deliberate DR replica** is not EG-3. *Flips back:* the deployed env file or render carries the other region for a hot path.

## Pricing and tools (dated; re-read at audit time)

25. **A list-price estimate is never a saving** (pack rule). Infracost's IaC estimates are public on-demand list prices; negotiated, committed and free-tier rates are invisible in the repo. Any such `$` is labelled `list price` and stays out of the money column.
26. **Infracost v2 (v2.17.0, 2026-09-30) needs a login and network** (`INFRACOST_CLI_AUTHENTICATION_TOKEN`; plugins downloaded at runtime; resource counts sent), prices AWS/Azure/GCP only — **no DigitalOcean, Helm/Kubernetes or Pulumi** — and prices usage-based lines at 0 without usage data. Legacy v0.10 needs `INFRACOST_API_KEY`. It is an optional cross-check (O-4); no key or login → NOT-RUN, never a reason to ask for one.
27. **OpenCost, Kubecost, KRR and Goldilocks need a live cluster and metrics.** Offline they are **NOT-RUN**, never a pass and never a proxy for a request-sizing finding. OpenCost has no DigitalOcean provider (custom pricing only).
28. **Trivy phones home since v0.63**: both `--disable-telemetry` and `--skip-version-check` are passed on every run (maintainer discussion #10971). Checkov runs with `--skip-download`.
29. **Cost-raising compliance rules are not cost findings**: CKV_AWS_338 (≥ 1 year log retention), CKV_DIO_1 (Spaces versioning), Polaris `deploymentMissingReplicas` and PDB-vs-HPA checks push spend **up**. They are policy rows for their owners; finops only prices the delta when asked.
30. **FOCUS column names are read from the export's header**, never assumed. `bill-lane.py columns` prints the mapping; CUR 2.0 and GCP profiles are column maps unverified against a real export. FOCUS 1.3 was ratified 2025-12-05; the specification site and the `FOCUS_Spec` GitHub release `v1.4` (marked Latest) show 1.4 published after it (both read 2026-10-19).

## Real-repo precedents (measured read-only 2026-10-19)

A NestJS + React monorepo on a managed Kubernetes provider with a fixed-size managed Postgres and
Valkey, an S3-compatible object store behind a CDN, self-hosted Loki/Tempo/Prometheus on capped PVCs,
and resources created by a runbook, no Terraform. What it taught:

31. **Paid dependencies are found by configured base URL, not only by SDK or host.** 0 SDK imports; the host grep found 3 lines of one messaging provider; the `*_BASE_URL` / `*_API_URL` / `*_GATEWAY_URL` inventory found 6 more third-party services, including the model gateway. § 0 of `spend-path-scan` reads all three.
32. **70 schedule sites, all against the flat-rate Postgres** (2 s intervals, `EVERY_MINUTE` export runners, nightly sweeps): FQ-1 is Hardening by § 1 and § 17 after one grouped read; the sites that reach a per-message API are the ones read individually.
33. **One object-store wrapper, three areas, one rule.** The exports area has no expiry and no delete path, while the only lifecycle rule (14 days, set by an operator 2026-09-21, recorded with `s3cmd getlifecycle`) covers the backups prefix: ST-1 candidate; one export holds customer personal data, so the retention half routes to security.
34. **The runbook is the IaC.** Five `doctl … create` lines (cluster, Postgres, Valkey, CDN, read replica) carry no tag or project flag (TG-4 low); a size slug in a create line contradicts the account table in the same runbook (documentation drift, not a finops row); seven `$…/month` figures, five undated (PX-1).
35. **Streaming private files through the API** (three `reply.send(stream)` routes behind a per-request signature check) is EG-2 low by § 22; the public media path uses the CDN host (EG-1 pass).

## Rationalizations to reject (finops)

**Wrongly accepting:** "it's only $5" (with no quantity, no unit and no source) · "the cloud is
cheap" · "Infracost says it saves $X" (list price, § 25) · "the instance is oversized" with no
utilisation series (§ 7) · "it is unused, delete it" (§ 2, § 7) · "polling every minute is wasteful"
against a fixed-size database (§ 1) · "every bucket needs versioning" (CKV_DIO_1 raises cost, § 29) ·
"the runbook says it costs $40/month" (§ 8).

**Wrongly dismissing:** "we'll clean it up later" (with no TTL, job or owner) · "it's behind the
CDN" (read the host the URL builder returns) · "the provider caps it" (read the cap and its value,
§ 15) · "we meter credits per tenant" (§ 16) · "there is a lifecycle rule" (on which prefix, § 19) ·
"the budget exists" (with a forecast rule and a recipient someone reads?) · "the tags are on the
Deployment" (the cost tools read the pod template) · "it's only the dev cluster" (always-on, billed,
BG-6) · "OpenCost would tell us" (not run, § 27).

---

Sources: the finops research catalog (2026-10-19) § 4 for entries 1–8, 9, 15–17, 19–22, 25 and its
two notes (tools, IaC, Kubernetes, DigitalOcean, budget APIs and FOCUS; code and config cost classes,
LLM spend, agents and precedents), the batch-8 finops eval (2026-10-19) for the ownership split, and
the read-only real-repo pass for entries 31–35. Tool versions and behaviours as dated in that catalog
§ 2 (Infracost, OpenCost, Kubecost, KRR, Goldilocks, Trivy, Checkov, Polaris); FOCUS 1.4 publication
read from focus.finops.org and the `FOCUS_Spec` GitHub releases page on 2026-10-19. Paraphrased; no
text reproduced beyond identifiers.
