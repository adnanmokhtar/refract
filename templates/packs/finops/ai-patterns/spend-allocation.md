---
name: spend-allocation
description: 'Pattern: Spend Allocation (tagging taxonomy, shared-cost basis, untaggable spend, showback that someone acts on)'
kind: ai-pattern
pack: finops
---

# Pattern: Spend Allocation

> **Hard rule:** Attribution coverage is measured by dollar, not by resource count. Mis-tagged is counted as untagged and fixed differently. Untaggable spend is a separate category with its own allocation rule. Shared cost is divided by a declared, computed basis or it is unallocated. Tags are enforced at creation, not detected afterwards.

**When to apply**
- Before building a unit-economics model — its error bar is this pattern's coverage figure.
- A cost report is disputed, or a team says "that is not ours".
- After a migration, an account restructure, or a reorganisation.
- Unallocated spend is growing as a share.

**When NOT to apply**
- Single-team, single-account systems where the account *is* the allocation. Do not build a tagging taxonomy to attribute spend to the only team there is.

**Halt conditions / mandatory cites**
- The allocation policy is undeclared — there is nothing to audit against.
- Required keys exist with no allowed-value set — correctness is unassessable.
- Shared-cost basis undeclared.
- A coverage claim by resource count with no dollar figure is a hand-wave — reject it.

## Why coverage by dollar

"97% of resources are tagged" is the number that gets reported and it is close to meaningless: the untagged 3% is usually the cluster. Ten thousand tagged small objects and one untagged data warehouse produce excellent resource coverage and terrible dollar coverage.

Report tagged spend as a share of total spend, in the headline, every time.

## The four categories

Attribution splits into exactly four buckets that must sum to total spend:

| Category | Meaning | Fix class |
|---|---|---|
| **tagged + valid** | key present, value in the allowed set, owner resolves to a real current team | — |
| **mis-tagged** | key present, value wrong — a decommissioned team, a typo, a value outside the set | value-set enforcement |
| **untagged (taggable)** | the resource type supports tags, nobody applied them | creation-time enforcement in the shared module |
| **untaggable** | the provider does not attach tags to this line at all (some shared network components, support and marketplace charges, certain cross-service transfer lines) | a written allocation rule |

Collapsing mis-tagged into tagged inflates coverage and hides a different problem. Collapsing untaggable into untagged aims the enforcement work at something enforcement cannot fix.

## Enforce at creation, not by detection

Detection-only tagging programmes never converge: every audit finds the same resources, someone tags them, and the next month's resources arrive untagged. The mechanism that works is making an untagged resource impossible to create — a required variable in the shared infrastructure module, a default-tag block at the account level, a policy that rejects the creation.

Detection then becomes an audit of the enforcement rather than a recurring chore. The finding "this resource was created from code without tags" is an enforcement gap, and its fix is in the module, not in the resource.

## The tagging taxonomy — few keys, strict values

A taxonomy with fifteen optional keys produces fifteen sparsely-populated columns. Keep it small enough that every key is genuinely required and genuinely used:

- **owner** (team, resolving to a real current team)
- **product** or service
- **environment** (production / staging / development — the split that answers "how much do we spend on not-production", which is frequently a surprise)
- **cost-centre**, where finance needs it

Every key has an **allowed-value set** and an owner for each value. Values drift as teams reorganise; without a set, historical series silently rebase and nobody can tell whether spend moved or a team was renamed.

## Shared cost

Some spend is genuinely shared: a platform team, a shared cluster, network components, observability ingestion. It must be divided by a **declared basis, computed from a named metric**:

| Basis | Good for | Distorts |
|---|---|---|
| request share | request-driven platforms | batch-heavy consumers under-charged |
| resource share (CPU/memory/storage) | shared clusters | bursty consumers under-charged |
| seat or tenant count | per-tenant platforms | consumers with wildly different usage per seat |
| even split | small teams, low stakes | everything, at scale |

Any of these is defensible; none of them is defensible *undeclared*. A shared pool divided by "roughly usage" with no written basis and no computed metric is unallocated spend with a story attached, and it will be argued about every quarter.

Record the basis, the metric it is computed from, and the date it was chosen. Label it `ASSERTED` if it is not computed from a metric — that is honest, and it flags the work.

## Showback that someone acts on

Allocation exists so an owner can act. A showback report going to a distribution list is unallocated spend with a mailing list. What makes it work:
- Named recipients, not aliases.
- A cadence matching the decision cycle, not the billing cycle.
- Their number **and** their unit cost, so the report says whether they are getting better or just bigger.
- A trend, not a snapshot.
- A named action: investigate, approve, or reduce.

Track whether anyone acted on the last report. If nobody did for two cycles, the report is not the problem — the ownership model is.

## Showback and chargeback are not the same rigour

They are frequently used interchangeably and they impose different standards, which is why the switch from one to the other goes badly.

- **Showback** informs. A number that is 85% attributed and 15% unallocated is useful: the owner can see their trend and act on it, and the error bar is an acceptable cost of shipping the report at all.
- **Chargeback** moves money between budgets. The same 15% now has to land somewhere by a written rule, the shared-cost basis becomes a contested figure rather than an analytical convenience, and every `ASSERTED` basis becomes a line someone will dispute in a finance review.

The rule that follows: **do not promote a showback report to chargeback without first re-deriving the untaggable bucket and the shared-cost basis as defensible allocations.** The four categories above are what makes that possible — a chargeback built on a coverage figure computed by resource count rather than by dollar will be wrong in exactly the direction that is hardest to argue with, because the biggest resources are the untagged ones.

Chargeback additionally needs two things showback does not: a **dispute path** (who arbitrates when an owner rejects a charge, and on what evidence) and a **restatement rule** (what happens to last quarter's charge when a tag error is found — corrected, or accepted and documented). Neither is optional; without them the first disputed invoice becomes a standing argument, and the usual outcome is that chargeback is quietly abandoned and the tagging programme loses its sponsor.

## Detectors

- A coverage figure reported as a resource percentage with no dollar figure.
- Untagged spend concentrated in a small number of large resources.
- Untagged resources created from infrastructure code (an enforcement gap, not a hygiene gap).
- Tag values not in the allowed set, or resolving to teams that no longer exist.
- A shared pool with no written basis, or a basis with no computed metric and no `ASSERTED` label.
- The untaggable bucket treated as a rounding error when it is a tenth of the bill.
- A showback report with no recorded action for two consecutive cycles.
- A chargeback programme running on a shared-cost basis labelled `ASSERTED`, or with no dispute path and no restatement rule.

## Related

- `ai/patterns/unit-economics.md` — consumes this coverage figure as its error bar.
- `ai/patterns/cost-anomaly-detection.md` — a budget can only be scoped to what can be attributed.
- `@finops-analyst`, `@cost-reviewer` — the measurement and the diff-time enforcement.
- `/audit-cost-attribution` — the command that measures and proposes.
