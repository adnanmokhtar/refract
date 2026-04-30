---
description: Reads phase-N.md summary + per-feature audits, drafts one ADR per P0 finding + cross-cutting decision, presents one review doc. Sibling step between /migration-phase --audit-only and /migration-phase --chain. Skipping this step forces decisions to be made interactively per /port-feature run.
kind: command
pack: migration
---

# /draft-phase-adrs <N>

## The Premise (read this first)

**Don't draft an ADR when V1-parity is the answer.** ADRs document genuine, user-confirmed divergences — not V2's accidental drift, not "the author preferred X," not cosmetic deltas. Default closure for V2-deviates-from-V1 is **edit V2 to match V1 in the port phase** — no ADR. Auto-drafting parity-restoring ADRs inflates docs while leaving real parity gaps unfixed (the Phase 7 lesson). Surface every divergence with three options; wait for explicit user choice before writing any ADR file.

Decisions-first batch. After `/migration-phase <N> --audit-only`, this command reads every per-feature audit + the phase summary, identifies decision points (P0 cutover blockers + cross-cutting items that recur across features), and **drafts** one ADR per decision in `ai/decisions/`. The user reviews + edits + signs off in one focus session, then `/migration-phase <N> --chain` runs the ports unattended against the pre-approved decisions.

The point: making the same RBAC decision N times across N features in N separate `/port-feature` runs is the dominant supervision cost. Batching the decisions cuts that cost — and matches `migration-discipline.md`'s rule "Document every intentional behaviour break" by doing it once, upfront, with full phase context.

## Pre-requisites

- `<N>` is a valid phase number from `ai/migration/plan.md`.
- `/migration-phase <N> --audit-only` has been run; per-feature audits + phase summary exist.
- Working tree is clean (recommended) so the user can review the ADR drafts as a single commit.

Optional flags:
- `--include-cross-cutting` (default: on) — produce phase-spanning ADRs for items recurring across ≥2 features.
- `--exclude-features=F0xx,F0yy` — skip drafting ADRs for these features (e.g., parked / deprecated rows).

## Phase 1 — Understand (the ask)

Inputs:
- `<N>` — phase number (required).
- `ai/migration/audits/phase-<N>.md` — phase summary (per-feature verdicts, cross-cutting findings, ADR backlog).
- `ai/migration/audits/F0NN-*.md` — per-feature audits (one per feature in phase N).
- `ai/migration/ledger.md` — feature rows (for v1_commit_pinned, gap_priority, dependencies).

## Phase 2 — Organize (decompose the work)

**ADR-default policy** (per `migration-discipline.md` § "Default to V1-parity, ADR is opt-in"): ADRs are drafted ONLY for explicit user-decided contract breaks. When a phase audit finds V2-deviates-from-V1 (extra button, renamed route, flipped default, new field, removed feature), the **default action is "remove V2 deviation to match V1"** — NOT "draft an ADR to legitimize V2's deviation". Auto-drafting parity-restoring ADRs inflates docs while leaving user-visible parity gaps unfixed (see Phase 7 lesson — ~6 ADRs drafted to preserve V2 over V1 in tenant-portal-v2).

This command's behaviour:
1. For every V2-deviates finding in audits, **surface the divergence to the user** with three options: (a) match V1 (default — no ADR, becomes a port-phase parity restoration), (b) keep V2 + ADR, (c) deprecate-V1-feature + ADR.
2. **Wait for explicit user choice** per divergence. Do NOT auto-pick (b) or (c).
3. **Draft ADRs only on (b) or (c)**. If user picks (a), record the divergence as a port-phase gap closure in the audit + skip the ADR.

For phase N:

1. **Read** `phase-<N>.md` § "Headline findings" + § "ADR backlog candidates" + § "Cross-repo follow-ups".
2. **Read** every per-feature audit's `Decision recommended` + `Hard-halt findings` sections.
3. **Classify** each decision point:
   - **V2-deviates-from-V1 (default: match V1)** — surface to user; draft ADR ONLY if user chooses keep-V2 or deprecate-V1.
   - **Per-feature ADR** — user-confirmed contract break affecting exactly one feature.
   - **Cross-cutting ADR** — user-confirmed contract break affecting ≥2 features.
   - **Cross-repo coordination** — decision blocked on a sibling repo / backend; produce a question doc, not an ADR.
   - **No-decision** — finding is pure parity restoration (no contract break); skip ADR, defer to port phase.
4. **Order** decisions by dependency: cross-cutting ADRs first (they may simplify per-feature ADRs), then per-feature.

See `migration-discipline.md` § Required artifacts per feature — tiered floor + § "Default to V1-parity, ADR is opt-in".

## Phase 3 — Retrieve (read the right context)

For each decision:
- Read the existing `ai/decisions/` directory; identify next free ADR number.
- Read related existing ADRs (e.g., a new RBAC ADR cites and may supersede a prior partial one).
- Read the cited V1/V2 source `<path:line>` from the audit to verify the finding still holds.

## Phase 4 — Generate (produce the output)

For each decision, write `ai/decisions/NNN-<slug>.md` with this structure:

```markdown
# ADR-NNN: <decision title>

> **Status**: proposed → ACCEPTED / REJECTED (user flips after review)
> **Date**: <UTC ISO>
> **Author**: /draft-phase-adrs (auto-drafted from audit; signed off by <user>)
> **Phase**: <N>
> **Features covered**: F0xx, F0yy, ...
> **Audit refs**: ai/migration/audits/F0xx-*.md, phase-<N>.md
> **Supersedes**: ADR-MMM (if applicable)

## Context

<2-4 sentences: what's in V1, what's in V2, why a decision is needed. Cite `<path:line>` on both sides.>

## Decision

<1-3 sentences: what we will do. Be unambiguous. Include the contract clause.>

## Rationale

<3-6 bullet points: why this decision over alternatives. Acknowledge the trade-off.>

## Alternatives considered

<2-3 alternatives, why rejected. "Preserve V1 parity" is always one alternative.>

## Implications for the port

- **Contract** (`ai/migration/contracts/F0xx-*.md`): cite this ADR in § 9 (Known V1 bugs / intentional breaks).
- **Parity tests**: <how the test changes — tolerance class, ignored fields, etc.>.
- **V2 code**: <files touched / patterns followed>.
- **i18n**: <new keys needed in each declared locale>.
- **RBAC migration**: <if applicable: backend script needed before cutover>.
- **Deprecation timeline**: <if applicable>.

## Open questions

<list cross-repo or backend questions this ADR DOES NOT answer; these go to the question doc, not the ADR>.

## Sign-off

- [ ] User read and approved on <date>
- [ ] Linked from each affected feature's ledger row (`intentional_break: ADR-NNN`)
- [ ] Cited in contract § 9 of each affected feature
```

After all per-feature + cross-cutting ADRs are drafted, write **one index doc** at `ai/decisions/_phase-<N>-decisions.md`:

```markdown
# Phase <N> decisions index

> **Generated**: <UTC ISO> by `/draft-phase-adrs <N>`
> **Status**: drafts pending review

## ADRs drafted (<count> total)

| ADR | Title | Type | Features | Status |
|---|---|---|---|---|
| ADR-NNN | <title> | per-feature \| cross-cutting | F0xx | proposed |
| ... | | | | |

## Backend / cross-repo coordination items (not ADRs)

| Item | Affected features | Recipient | Notes |
|---|---|---|---|
| ... | | | |

## Sign-off checklist

- [ ] Read every ADR (including § Rationale and § Alternatives)
- [ ] Flip `Status: proposed` → `Status: accepted` on each (or write a successor ADR for rejections)
- [ ] Resolve cross-repo coordination items (or accept that the ports will halt on those features)
- [ ] Run `/migration-phase <N> --chain` to execute ports unattended

## Decisions deferred

<features for which no ADR was drafted because: parity-clean, parked, deprecated, or backend-blocked>.
```

Reviewer-friendly output: print to the user a one-screen summary of every ADR drafted with link, title, features covered, and a 1-line "what it decides". User opens each, reviews, flips status.

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/decisions/NNN-*.md` — one file per decision (drafts; user edits/accepts).
- `ai/decisions/_phase-<N>-decisions.md` — index doc (managed-block; idempotent on re-run).
- `ai/dynamic/changelog.md` — append entry: "Phase <N> decisions drafted: <count> ADRs + <count> coord items".
- DOES NOT modify ledger rows, contracts, plans, or audit files. Those update only after sign-off, during `/port-feature` runs.

## Phase 6 — Validate (verify correctness)

- Every drafted ADR has the required sections.
- Every per-feature P0 in `phase-<N>.md` has a corresponding ADR OR is in the cross-repo-coordination list.
- Every cross-cutting recurrence (≥2 features sharing a finding) has exactly one ADR.
- The index doc lists every drafted ADR.
- No ADR file omits `Status: proposed` (drafts must NOT auto-accept).

## Phase 7 — Improve (feed the learning loop)

- If the same cross-cutting decision recurred in Phase <N-1> as well, suggest promoting the policy from per-phase ADR to a project-wide rule in `.claude/rules/`.
- If multiple ADRs point at the same backend question, suggest collapsing into one cross-repo coordination doc.

## Output to user

```
/draft-phase-adrs <N> complete:

ADRs drafted:           <count>
  Per-feature:          <a>
  Cross-cutting:        <b>
Coord items:            <c>
Decisions deferred:     <d>   (parity-clean / parked / deprecated)

Index: ai/decisions/_phase-<N>-decisions.md
ADRs: ai/decisions/NNN-*.md

Next steps:
  1. Review each ADR (~5 min × <count>).
  2. Flip Status: proposed → accepted on each (edit the file).
  3. Resolve cross-repo coord items.
  4. Run: /migration-phase <N> --chain    (executes ports unattended against pre-approved ADRs)
```

## Mechanical halt — refuse to draft without explicit user choice

For every V2-deviates-from-V1 finding in the audits, the command MUST present the three options (match V1 / keep V2 + ADR / deprecate V1 + ADR) and wait for explicit user input per finding. Auto-picking option (b) or (c) is forbidden. If the user has not chosen, NO ADR file is written for that finding — it stays in the audit as a port-phase parity-restoration item. A run that drafts ADRs without user-confirmed contract-break choice is invalid; halt and surface the unprompted findings.

## Hard rules

- **Drafts ship as `Status: proposed`.** Never auto-accept on the user's behalf.
- **One ADR per decision.** Don't bundle independent decisions into one ADR — they have different reviewers and different revert paths.
- **No code changes.** This command only writes to `ai/decisions/`. Contracts, plans, ledger rows, V2 source — untouched until `/port-feature` runs.
- **Cite source.** Every Context section has `<path:line>` cites for both V1 and V2.
- **Acknowledge alternatives honestly.** "Preserve V1 parity" is always one alternative; the rationale must explain why we don't.

## Related

- `/migration-phase <N> --audit-only` — runs before this command; produces the audits this command reads.
- `/migration-phase <N> --chain` — runs after this command; executes ports unattended against the accepted ADRs.
- `/port-feature <id> --unattended` — per-feature loop that reads ADRs as pre-approved decisions.
- `.claude/rules/migration-discipline.md` § "Document every intentional behaviour break" — the rule this command operationalises.
- `ai/patterns/migration-ledger.md` — `intentional_break: ADR-NNN` field on ledger rows points back at these ADRs.
