# finops pack — changelog

Release history for `templates/packs/finops/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record.

## 1.1.0 — 2026-08-23

**Two-thirds of this pack did not reach a greenfield project, and the one thing it could not say was
"I read no number".**

- **FALLBACK — 11 of 16 topics resolved to nothing.** `_topics.md` declared `fallback:
  stub-from-sections` on all four commands, all four skills, and three of four patterns. Per
  `templates/phases/phase-4.2-apply.md:26` that sentinel "emits a sectioned stub from that topic's
  `sections:` list" — and the four skill topics carried **no `sections:` key at all**, so a no-signal
  project received an empty file. Every one of the eleven is a finished 119–173-line artifact already
  on disk. All now declare their own source as the fallback (`commands/<name>.md`,
  `skills/<name>/SKILL.md`, `ai-patterns/<name>.md`) — the shape step 2 explicitly provides for and
  which `algorithms`, `mobile`, `align`, `learning` and `code-quality` already use. The identical
  defect was repaired by hand in `security` (CHANGELOG 87) and `infrastructure` (CHANGELOG 106); this
  is the third occurrence and no gate catches it. `_topics.md` fallback resolution is unaffected by
  the `references/` framework-name trap — check 3 resolves these paths and they all resolve.
- **`/cost-review` gained a fourth verdict, `UNPRICED`.** The pack was well defended against a
  *fabricated* number — the hand-wave grep, the three labels, five halt conditions — and undefended
  against its mirror image: a diff introducing billed mechanisms, no reachable volume metric, every
  finding correctly marked `UNKNOWN`, and a green `APPROVE` on the verdict line. That is "spend looks
  reasonable" with no number read, arriving through the front door. `UNPRICED — <n> mechanisms fired,
  0 priced; needs <named metrics / billing access>` is now the verdict in that state, `unpriced` is a
  per-mechanism row state that is never collapsed into `pass`, a `Priced: <n> of <n>` line is required
  output, and a hard rule forbids `APPROVE` where a mechanism fired and nothing was priced. This is
  the pack's answer for the case every other artifact halts on — `/cost-review` still runs, because
  the mechanism half of a finding is derivable from the diff alone, and the verdict says which half of
  the job was done. Mirrored into `@cost-reviewer` and its fallback.
- **The three magnitude tiers — `UNKNOWN` is now a last resort.** The command told you to write
  `UNKNOWN — needs <metric>` and never said where to look first. Added a per-mechanism table of the
  volume that sizes each of the eight mechanism classes and where it is reachable from, plus the tier
  vocabulary: **tier 1** a metric measured this run with its window; **tier 2** an exact multiplier
  read out of the diff (a retry cap, a fan-out factor, 730 hours a month, a loop over a
  code-bounded collection) — which needs **no billing access whatsoever** and is a real magnitude;
  **tier 3** `UNKNOWN`. "Retry cap 3 → 10, a 3.3× multiplier on billed calls to this dependency, base
  rate UNKNOWN" is actionable where bare `UNKNOWN` is not, and the multiplier was sitting in the diff.
  Tiers 1 and 2 count as priced. A tier-3 row on a mechanism whose multiplier was a literal is a
  defect in the review.
- **CURRENCY — FOCUS named, checked 2026-08.** The pack carried no stale prices, no instance families
  and no vendor product names (measured: zero matches for any provider or engine token), so there was
  nothing to retract. The cost of that abstention was that "the cost and usage export" could never
  name a column. `STACK.md` now names **FOCUS** (<https://focus.finops.org>, current release 1.4, 17
  conformant vendor exports as of 2026-08) and maps four of the pack's hard rules onto its columns —
  `Effective Cost` vs `Billed Cost` vs `List Cost` vs `Contracted Cost` settles "amortised and
  discounted, never list"; `Commitment Discount ID` / `Status` settles commitment amortisation;
  `Consumed Quantity` vs `Pricing Quantity` settles the usage-type mechanism; `Tags` × `Resource ID`
  settles coverage-by-dollar. Both the version and the vendor list are stated as re-checkable rather
  than as facts.
- **`@finops-analyst`: two thin steps made mechanical.** Step 1 now requires the analysis to state
  *which cost column it read* in the output header — "the bill" is four different numbers and the
  difference is most of this agent's error surface. Step 5 was the thinnest step in an otherwise
  precise method ("produce the tables below"); it now carries the rate/usage/mix arithmetic, with mix
  computed as the residual on purpose, and the rule that a split which fails to sum is itself the
  finding (a grouping is not comparable across the two periods) rather than something to force closed.
- **`commitment-coverage`: "prefer flexible instruments" made decidable.** The line was a real
  decision rule with nothing to apply it to. Replaced with the **denomination axis** — spend-per-hour
  vs resource-quantity vs specific-shape — which is the same axis on every provider under different
  product names, and the rule that follows: commit at the coarsest denomination whose floor you are
  confident in. Deliberately names no vendor product: the report is required to use the provider's own
  product name, mirroring the discipline the pack already applies to prices, so the finding stays
  greppable and this file stays free of anything that goes stale.
- **`spend-allocation`: showback and chargeback are not the same rigour.** Chargeback is a named
  FinOps Framework capability under *Manage the FinOps Practice* and the pack covered only showback.
  Added the promotion rule (re-derive the untaggable bucket and the shared-cost basis as defensible
  allocations first), the dispute path, and the restatement rule, plus a detector for a chargeback
  running on an `ASSERTED` basis.
- **DANGLING CROSS-PACK CLAIM — fixed in two files.** `_essentials.md` and `@cost-reviewer` both
  stated that model/token spend discipline is owned by "the `ai-engineering` pack
  (`ai-cost-discipline`, `ai-cost-tracking`)". Neither artifact exists in that pack: both live in
  `templates/domains/ai/` — a **domain overlay**, a different mechanism with different install
  conditions. ai-engineering's actual coverage is AI-3 / `ai/patterns/llm-gateway.md`. Both files now
  name the real owners, and `@cost-reviewer` reports token spend as *unowned* where a project has the
  model calls but neither the pack nor the overlay — previously both packs' prose implied coverage
  that did not exist. `lint-handoffs.sh` cannot see this class: the claim is a bare artifact name in
  prose rather than a path.
- **DISPATCH — `commitment-coverage` was reachable only from a `## Related` bullet.** `/cost-guardrails`
  needed "trailing spend history … for threshold derivation" as a raw Phase 3 input while the skill's
  own Outputs promised "an expiry calendar for `/cost-guardrails`" that nothing initiated. Added
  guardrail **class 6, expiry notifications** — the only class that fires on a calendar rather than a
  measurement, and the one no detector in classes 1–5 can see coming — which dispatches the skill for
  the calendar and the computed bill increase per entry, with a ledger row, a Phase 6 proof, and a
  coverage count. Phase 3 now dispatches `@finops-analyst` for the trailing history rather than
  retrieving it by hand, so thresholds inherit its normalisation.
- **RULE — 1,727 → 1,589 tok (6,909 → 6,359 chars, −8%).** Deleted `## Review checklist` entirely.
  Measured, not assumed: a scripted map of all nine checkboxes onto the Must / Must-not / Should set
  found a counterpart for every one. Two carried something the body did not — a named owner on the
  idle floor, and the diff-time cost-per-unit threshold breach — and both were folded into the Musts
  they restate (`:23`, `:27`) rather than dropped. `## Enforcement` is untouched: five bullets that
  name mechanisms, the best value in the file. The Must/Must-not sets are untouched at ~38 tok per
  distinct obligation, the tightest ratio in the batch. The fallback lost the same section and gained
  the same two folded clauses, so the pair stays consistent.
- **All three agent fallbacks regained a sibling boundary** (0 of 3 → 3 of 3). Greenfield previously
  installed three cost agents with the routing intact (the frontmatter `Do NOT trigger` clause is
  gated by check 8b) and no statement of who owns what between them. Each now opens `## Related` with
  a compressed `**Boundary:**` line — design-time / diff-time / after-the-fact for the three moments,
  and "you measure, you never propose an architecture change" for the analyst.

## 1.0.0 — 2026-08-20

- NEW pack. The infrastructure pack already ships `/cost-audit` — a point-in-time sweep of existing
  resources for idle, over-provisioned, and forgotten spend. This pack deliberately does NOT
  duplicate it. It owns the *discipline* around that sweep: what a unit costs, whose spend it is,
  what the commitment posture should be, what prevents the next surprise, and the cost lens on a
  diff before it merges. `/cost-audit` stays where it is and is cross-referenced from every artifact
  that would otherwise overlap it.
- agents (3): `cost-architect` (opus — pricing dimensions, driver tree, cost at target and 10×
  target, idle floor, exit cost, the trade-off table), `cost-reviewer` (opus — the missing review
  lens: always-on resources, per-row paid calls, retry and fan-out bounds, cross-zone movement,
  retention and log-volume defaults, scan cost, allocation tags), `finops-analyst` (sonnet —
  mechanical: parse the cost/usage export, group by every allocation axis, compute unit costs
  against the declared model, split deltas into rate/usage/mix).
- commands (4): `/cost-model`, `/cost-review`, `/audit-cost-attribution`, `/cost-guardrails`.
- skills (4): `unit-cost-probe`, `commitment-coverage`, `egress-trace`, `spend-anomaly-triage`.
- rules (1): `finops-principles`.
- ai-patterns (4): `unit-economics`, `spend-allocation`, `commitment-strategy`,
  `cost-anomaly-detection`.
- The pack's central discipline is the three-label rule — every cost figure is `measured`,
  `ALLOCATED (basis: <named proxy>)`, or `NOT DERIVABLE — <instrumentation>`. There is no fourth
  label, and an estimate presented as a measurement is treated as a defect, because a fabricated
  number gets quoted in a planning meeting and outlives everyone who knew it was a guess.
- Boundaries stated in every artifact: `infrastructure` `/cost-audit` owns the resource sweep;
  `performance` owns latency and throughput (the same N+1 is often a finding on both sides — the
  lens that produced it is named); `ai-engineering` owns model and token spend discipline, which
  this pack treats as one more billed dependency; `observability` owns alert routing, which cost
  alerts reuse rather than duplicating; `data-engineering`'s `warehouse-scan-audit` owns the SQL
  that produces warehouse spend, and hands the money total here.
