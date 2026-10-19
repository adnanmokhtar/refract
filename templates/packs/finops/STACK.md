# FinOps pack — stack assumption

This pack's agents, commands, skills, and patterns assume:

- **A row-level cost and usage export** from the cloud provider (not a console summary), covering whole billing periods, with tag/label columns and usage-type granularity.
- **Daily — ideally hourly — cost granularity**, without which anomaly triage cannot correlate a spend change with a deploy.
- **A tagging or labelling mechanism** plus an account/project/subscription structure that can carry ownership.
- **Provider-side controls** capable of budgets, quotas, and policy-based creation restrictions.
- **A usage metric per business unit** (requests, tenants, orders, jobs, tokens) countable over the same period as the bill.
- **Infrastructure defined as code**, so tag enforcement and pre-merge cost estimation have somewhere to attach.

Where any of these is absent, the affected artifact says so explicitly rather than degrading silently: `unit-cost-probe` refuses without a defined denominator, `spend-anomaly-triage` refuses without daily granularity, `@finops-analyst` refuses without a row-level export, and `egress-trace` runs its four config classes and prints its flow-log lane as `NOT-RUN (no flow logs)`. The five static detectors (`guardrail-scan`, `allocation-scan`, `spend-path-scan`, `storage-growth-scan`, `egress-trace` § 1–§ 4) need only the repository; `candidate-pricing` needs a bill line or a pricing page fetched in the run for every `$` and otherwise prints `unpriced`.

## Provider-neutral vocabulary used in this pack

Cost constructs are named generically because every provider spells them differently. Substitute per environment:

| Concept (used in this pack) | Common equivalents | Substitution source |
|---|---|---|
| cost and usage export | the provider's detailed billing export or billing API | the account's billing configuration |
| committed-spend / reserved-capacity instrument | reservations, savings plans, committed-use discounts, capacity commitments | the provider's discount programme |
| allocation tag / label | tags, labels, resource tags | the allocation policy |
| account / project / subscription | the provider's billing-scope boundary | the account structure |
| per-hour-billed managed service | provisioned endpoints, node pools, clusters, gateways | the service catalogue |
| cross-zone / cross-region / internet egress | the provider's data-transfer usage types | the transfer price sheet |
| creation policy control | organisation policies, service control policies, admission policies | the governance layer |
| flat-rate capacity | committed capacity slots or reservations billed as a fixed pool | the pricing agreement |

Because the vocabulary is neutral, every price in this pack's outputs must carry a **SKU/tier name and an as-of date** — that is what makes an otherwise provider-agnostic figure verifiable.

## FOCUS — the one place the neutral vocabulary has a real schema

The table above is neutral by necessity, and neutrality has a cost: every artifact here says "the cost and usage export" without being able to name a column. There is now a published schema that closes that gap, and where a project's export conforms to it, this pack's rules stop being abstractions and become column lookups.

**FOCUS** (FinOps Open Cost and Usage Specification, <https://focus.finops.org>) normalises billing datasets across cloud, SaaS, AI, and data-centre vendors. Versions, as read: **1.2** ratified 2025-05-29; **1.3** ratified 2025-12-05 (contract-commitment dataset, split cost allocation, recency and completeness; FinOps Foundation announcement); **1.4** is the publication version on the specification site and the `v1.4` release marked Latest on the `FOCUS_Spec` GitHub repository, listed after the 1.3 tag (both read 2026-10-19; the release page shows no ratification note). The 2026-08 line here said 1.4 without a source; it now has one. The 2026-08 vendor list (17 vendors, AWS, Azure and Google Cloud among them) was not re-read in that pass; whether DigitalOcean's invoice CSV or Billing Insights export is FOCUS-conformant is unverified (research, 2026-10-19), so `bill-lane.py --map` maps its headers explicitly. Version and vendor list both move; re-check the site rather than quoting this paragraph. `bill-lane.py` matches column names after normalisation (`ResourceId` = `ResourceID`) and prints which header it read, so a version's spelling change is visible, not silent.

Where a FOCUS export exists, four of this pack's hard rules resolve to named columns instead of prose:

| This pack's rule | FOCUS column that settles it |
|---|---|
| "amortised and discounted, never list price" | `Effective Cost` (amortised, post-discount) vs `Billed Cost` (invoiced) vs `List Cost` vs `Contracted Cost` — the four are separate columns, so "which cost" stops being ambiguous |
| "amortise commitments across their term" | `Commitment Discount ID` + `Commitment Discount Status` — the commitment's identity and state travel with the row |
| "the usage type is where the mechanism lives" | `Service Name` + `SKU ID` / `SKU Price ID`, with `Consumed Quantity` and `Pricing Quantity` kept distinct (they differ, and conflating them is a common unit-cost error) |
| "attribution coverage by dollar" | `Tags` joined against `Resource ID` / `Resource Type`, over whole `Billing Period Start` periods |

Two consequences worth stating plainly. First, **ask whether a FOCUS export is available before writing a bespoke parser** — every artifact here that reads "the cost and usage export" reads it more cheaply and more portably through FOCUS. Second, **report in the project's own column names**, exactly as the neutral table above requires: translating a provider's native column into a FOCUS name in a project that does not publish FOCUS makes the finding un-greppable, which is the same defect as inventing a number. Name the schema you actually read.

## Where stack-specific names live

- The project's `_extracted-codebase.md` — the provider(s), the account structure, the infrastructure-as-code tool, and the managed services in use.
- `ai/finops/unit-economics.md` — the driver tree, the declared expectation, and the `NOT DERIVABLE` backlog.
- `ai/finops/attribution.md` — the allocation policy, coverage, the untaggable list, and the shared-cost basis.
- `ai/finops/guardrails.md` — the installed guardrails with their derivations, recipients, and last review date.

Universal hard rules (label every figure, retention on every store, bound every retry, derive every threshold, no saving against list price) are provider-agnostic.
