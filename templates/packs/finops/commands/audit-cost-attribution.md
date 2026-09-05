---
description: Audit whether spend can be attributed to an owner — tag and label coverage by resource and by dollar, the allocation rules for shared cost, the showback map, and the unallocated bucket. Reports the percentage of spend nobody owns, which bounds every per-unit number derived from it.
kind: command
pack: finops
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /audit-cost-attribution [--period <billing-period>]

Measure how much of the bill has an owner. Unattributed spend is not merely unmeasured — it is structurally unreducible, because no team sees it, no team is asked about it, and no team can act on it. This audit reports the number by dollar, not by resource count, and names the rules that would fix it.

## When to use / NOT to use

- USE: before building a unit-economics model (its error bar is this audit's result); when a cost report is disputed; when a team says "that is not ours"; after a migration or an account restructure; quarterly.
- NOT: to compute cost per unit — that is `/cost-model`, which should run after this.
- NOT: to find waste — that is `/cost-audit` in the infrastructure pack.
- NOT: to design the tagging taxonomy from scratch — read `ai/patterns/spend-allocation.md` first, then audit against it.

## Phases applied

1-3 + 5 + 6.

## The Premise (read this first, internalize, do not deviate)

**Coverage is measured by dollar, not by resource.** "97% of resources are tagged" is the number that gets reported and it is nearly meaningless: the untagged 3% is usually the cluster. Report tagged spend as a percentage of total spend, always, and put it in the headline.

**A tag that exists is not a tag that is correct.** Sample and verify: resources tagged with a decommissioned team, a misspelled product name, or a value not in the allowed set are counted as untagged for the purposes of this audit, and listed separately as *mis*-tagged, which is a different fix.

**Shared cost is allocated by a declared rule or it is unallocated.** There is no third state. A shared cluster divided by "roughly usage" with no written basis is unallocated spend with a story attached.

**Closure verb (default): report-and-propose.** Measure coverage, list the gaps, and propose the enforcement change. Do not retag resources as a side effect of an audit.

**Escalation triggers (halt and ask):**
- The allocation policy is undeclared — there is nothing to audit against. Propose one from `ai/patterns/spend-allocation.md` and stop.
- Required tag keys are declared but have no allowed-value set, so correctness is unassessable.
- The shared-cost allocation basis is undeclared.

## Phase 1 — Understand

Confirm:
- **The allocation policy** — which tag/label keys are required, on which resource types, with which allowed values, and who owns each value.
- **The account/project structure** — attribution by account is often stronger than by tag, and where the structure already separates teams, tags matter less. Say which mechanism is primary.
- **The shared-cost basis** — how platform, network, and shared-cluster spend divides.
- **The period** — whole billing periods.

## Phase 2 — Organize

Four passes:

1. **Coverage by dollar** — total spend, split into tagged-and-valid, mis-tagged, and untagged. Then the same split per service, ranked by untagged dollars.
2. **Untaggable spend** — the portion that cannot carry tags at all on this provider (certain shared network components, some support and marketplace charges, cross-service data transfer lines). This is a real category and must be separated from "nobody tagged it", because the fixes differ entirely: one is an allocation rule, the other is enforcement.
3. **Shared-cost allocation** — what is in the shared pool, what basis divides it, and whether that basis is computed from a real metric or asserted.
4. **Showback map** — does each owner receive their number, on what cadence, and does anyone act on it? A showback report nobody opens is unallocated spend with a mailing list.

## Phase 3 — Retrieve

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Additionally:
- `ai/patterns/spend-allocation.md`, `ai/patterns/unit-economics.md`.
- `.claude/rules/finops-principles.md`.
- The cost and usage export at row level with the tag/label columns.
- The infrastructure definitions — untagged resources created from code are an enforcement gap, not a hygiene gap, and the fix is in the module defaults.

## Phase 5 — Update

- Write `ai/finops/attribution.md`: the policy, the coverage figures, the untaggable list with its allocation rule, the shared-cost basis, and the showback map with owners and cadence.
- Propose the enforcement change where resources are created from code: a required-variable or default-tag mechanism in the shared module, so an untagged resource cannot be created rather than being detected afterwards. Detection-only tagging programmes never converge; every audit finds the same gap.

## Phase 6 — Validate

- **Reconcile**: tagged + mis-tagged + untagged + untaggable = total spend. If it does not, a category is being double-counted.
- **Sample-verify tag correctness**: take a sample across the highest-spend tagged resources and confirm the owner value resolves to a real, current team.
- **Test the enforcement proposal** in a dry run: create a resource through the shared module without the required tags and confirm it is rejected. An enforcement mechanism that has never been observed rejecting anything is unverified.
- Dispatch **`@finops-analyst`** for the numeric review.

### Attribution ledger — REQUIRED OUTPUT ARTIFACT

```
Category                    | Spend  | % of total | Fix class            | Owner
tagged + valid              | $x     | 61%        | —                    | —
mis-tagged (value invalid)  | $x     | 7%         | value-set enforcement| platform
untagged (taggable)         | $x     | 22%        | module default tags  | platform
untaggable (provider limit) | $x     | 10%        | allocation rule      | finops
```

## Output format

```
## /audit-cost-attribution — <period>

Primary attribution mechanism: <accounts | tags | both>
Policy: <required keys, allowed values, enforced where>

Attribution ledger: <the table above, verbatim>

Attributed share of spend: <%>   ← headline; every per-unit number inherits this error bar
By service (top untagged dollars):
| Service | Untagged $ | % of that service | Created from code? | Fix |

Shared-cost pool: $<x> (<%> of total) — basis: <declared basis> — computed from <metric | ASSERTED>

Showback: <n> owners · cadence <x> · owners who acted on the last report: <n>

Enforcement proposal: <the module/default change>   dry-run result: <rejected | not tested>

Status: <see gate below>
```

### Closure gate — COMPLETE only when the ledger reconciles and every category has a fix class

- **`Status: COMPLETE`** — the four categories sum to total spend, the untaggable portion has a written allocation rule, the shared-cost basis is declared and computed from a named metric (or explicitly labelled ASSERTED), and the enforcement proposal has a dry-run result.
- **`Status: INCOMPLETE — unmet: <list>`** — the ledger does not reconcile, a category has no fix class, the shared basis is asserted with no metric and not labelled, or the enforcement proposal was never dry-run.

This gate is **[self-policed]** on the Status line; the reconciliation arithmetic and the dry-run result are both reproducible.

## Hard rules

- **Report coverage by dollar in the headline**, never by resource count alone.
- **Mis-tagged is not tagged.** Count it separately; the fix is different.
- **Untaggable is a real category** and must be separated from untagged, or the enforcement work is aimed at the wrong thing.
- **Shared cost is allocated by a declared, computed basis** or reported as unallocated. An asserted basis is labelled ASSERTED.
- **Never retag as a side effect of an audit.** Report and propose; changing ownership metadata silently rewrites someone's cost history.

## Failure modes

- A tagging programme measured by resource coverage that never moves the dollar coverage.
- Detection-only enforcement: every quarter finds the same untagged resources because nothing prevents their creation.
- Shared cost divided by headcount because it was easy, then used to justify a per-tenant price.
- A showback report that goes to a distribution list rather than to named owners.
- Tag values drifting as teams reorganise, so historical cost series silently rebase.
- Treating the untaggable bucket as a rounding error when it is a tenth of the bill.

## Related

- `@finops-analyst` — performs the grouping and the reconciliation.
- `@cost-architect` — account and tagging structure decisions for new systems.
- `@cost-reviewer` — catches untagged resources at diff time, which is where the fix is cheapest.
- `/cost-model` — run after this; it inherits the attributed share as its error bar.
- `ai/patterns/spend-allocation.md`, `ai/patterns/unit-economics.md`.
- `.claude/rules/finops-principles.md`.
