---
description: Forces a phased alignment plan from the scan output. Groups findings into phases by class + domain + tier + dependency. Caps each phase at 12 findings. Honors gold-standard inventory (no lift-and-shift, no oracle modification). Stack-agnostic.
kind: command
pack: align
---

# /align-plan

## The Premise (read this first)

**Read before grouping. Cite real findings, never invented.** The plan groups findings that ALREADY exist in the ledger (produced by `/align-scan`); it does not invent findings, does not paraphrase evidence, does not assume new fingerprints. Every plan row's `id` matches a ledger row exactly. If the ledger is missing a finding you "remember the scan flagging," halt and re-run `/align-scan` — do NOT add a row by hand.

Reads `ai/align/ledger.md` + `ai/align/scan-report.md`, produces `ai/align/plan.md` — the phased execution plan, AND updates each ledger row's `phase: <N>` field.

## Pre-requisites

- `/align-scan` has been run (`ai/align/ledger.md` and `ai/align/scan-report.md` exist).
- Ledger has rows with `status: detected`.

If pre-requisites missing → halt + tell user to run `/align-scan` first.

## Phase 1 — Understand (the ask)

Inputs:
- `ai/align/ledger.md` — finding inventory.
- `ai/align/scan-report.md` — recommended phasing + structural context.
- `ai/architecture.md` — declared module boundaries (constraints).
- `ai/conventions.md` — naming + structure rules.
- `_extracted-idioms.md` — gold-standard inventory.
- ADRs in `ai/decisions/` — past decisions that constrain the order.

Optional flags:
- `--phases=<N>` — target number of phases (default: auto from scan recommendation, capped by `--max-features-per-phase`).
- `--max-findings-per-phase=<N>` — cap per phase (default: 12). Larger phases hide regressions and slow review.
- `--strategy=<class|domain|mixed>` — phasing strategy (default: `mixed` — class-first for mechanical phases, domain-first for UI/UX phases).
- `--exclude-class=<list>` — skip a finding class (e.g., `--exclude-class=over-abstraction`); excluded rows stay `status: detected` and are picked up in a later run.
- `--exclude-tier=<list>` — skip tiers (e.g., `--exclude-tier=heavy`).

## Phase 2 — Organize (decompose the work)

Decomposition strategy, in priority order:

1. **Mechanical first.** Classes that touch isolated files with no inter-finding dependency: `dead-code`, `silent-catch`. These are the safest first phases — the diff is local, the risk is low, and the team builds confidence in the alignment workflow before tackling cross-cutting concerns.
2. **Within-class grouping for trivial-tier rows.** Trivial findings of the same class belong together — a 12-finding `dead-code` phase reads cleanly in PR review (one closure verb, one rationale, one diff shape).
3. **Domain grouping for UI/UX rows.** Frontend UI/UX findings (`a11y-violation`, `design-token-drift`, `i18n-key-drift`, `raw-library-component`, `missing-ui-state`, `motion-drift`) are best grouped by **page or feature domain** (e.g., "auth pages", "checkout flow", "dashboard widgets") rather than by sub-class — a single page's a11y + token + i18n fixes touch the same files and review together. Mixing these classes within a domain phase is preferred over splitting them across phases.
4. **Honor dependency graph.** A finding that introduces / repairs a shared helper goes BEFORE findings that swap local copies for it. A finding that removes a wrapper goes AFTER findings that remove its callers.
5. **Cap phase size.** Phases over `--max-findings-per-phase` get split.
6. **Foundation patterns first.** If a `drift` finding affects a widely-used convention (e.g., "all data access bypasses the repository pattern"), the convention's enforcement goes in an early phase — fixing one consumer at a time without aligning the convention is whack-a-mole.
7. **Heavy tier last** (within their class group). Heavy rows benefit from per-row supervision; bundling them with trivial rows in the same phase complicates the gate.

### Phasing template by stack (typical example, NOT a rule)

These templates are **starting points**, not requirements. Real projects have different priorities — a project mid-incident may front-load security; a project with a regulatory deadline may front-load tenant-isolation; a project with a design-system migration may front-load a11y + design-token drift. The planner adapts based on actual finding counts + the user's `--strategy` flag + ADR-recorded priorities. Skip phases with 0 findings; merge phases with similar themes; re-order to match the team's priorities.

For `PROJECT_KIND in {frontend-*}`, a typical phase order is:

| Phase | Theme | Classes | Tier mix |
|---|---|---|---|
| 1 | Mechanical cleanup | dead-code | trivial-only |
| 2 | Mechanical cleanup | silent-catch | trivial-only |
| 3 | Auth domain UI/UX | a11y + design-tokens + i18n + raw-library-component (auth pages only) | trivial + standard |
| 4 | Core flow UI/UX | a11y + design-tokens + i18n (dashboard / list pages) | trivial + standard |
| 5 | Data-fetch states | missing-ui-state (any page that fetches data) | trivial + standard |
| 6 | Reinvented wrappers | reinvented-wrapper (cross-domain) | standard |
| 7 | Lifecycle / permission gates | lifecycle-hook-wrong + permission-gate-drop + default-true-prop | standard + heavy |
| 8 | Drift cleanup | drift (cross-cutting conventions) | standard + heavy |
| 9 | Over-abstraction | over-abstraction | standard |

For `PROJECT_KIND in {backend-*}`:

| Phase | Theme | Classes | Tier mix |
|---|---|---|---|
| 1 | Mechanical cleanup | dead-code + silent-catch | trivial |
| 2 | Tenant gates | tenant-gate-missing (auth / data layer) | standard + heavy |
| 3 | Query alignment | n-plus-one + raw-sql-where-repo-exists | standard |
| 4 | Transaction boundaries | transaction-boundary | standard + heavy |
| 5 | Reinvented wrappers + dedupes | reinvented-wrapper + duplicated-logic | standard |
| 6 | Drift + over-abstraction | drift + over-abstraction | standard + heavy |

These templates are starting points; the planner adapts based on actual finding counts. A phase with 0 findings is dropped; a phase with > 12 findings is split.

## Phase 3 — Retrieve (read the right context)

For each finding's domain assignment:
- Read 1-2 source files in the finding's `scope` to understand which domain they belong to (auth / orders / dashboard / shared).
- Cross-reference `ai/architecture.md` if it documents domain boundaries explicitly.

This is moderate work; fan out via Explore subagents capped per `--max-subagents`.

## Phase 4 — Generate (produce the output)

Write `ai/align/plan.md`:

```markdown
# Alignment plan

Generated: <YYYY-MM-DD>
Scan source: ai/align/scan-report.md (rev <commit>)
Ledger source: ai/align/ledger.md (revision pinned)
PROJECT_KIND: <kind>

## Strategy

Phasing strategy: <class|domain|mixed>
Cap per phase: <N> findings
Total findings: <N>
Total phases: <K>

## Gold-standard summary (non-negotiable target)

> The alignment closes drift toward the gold-standard inventory — never away from it. Cite specifics so each phase knows what "follow the convention" means.

- Shared wrappers (top 5 referenced by findings): <list with paths from _extracted-idioms.md>
- Conventions enforced this run: <list from ai/conventions.md>
- Architecture boundaries respected: <list from ai/architecture.md>

## Phase 1 — <theme>
**Goal**: <one-line objective>
**Class focus**: <single class name OR "mechanical cleanup">
**Tier mix**: <T trivial / S standard / H heavy>
**Estimated effort**: <hours/days>

### Findings in this phase
| ID | Class | Tier | Files | Closure verb | Evidence count |
|---|---|---|---|---|---|
| A001 | dead-code | trivial | 1 | remove | 1 |
| A002 | dead-code | trivial | 1 | remove | 1 |
| ... | | | | | |

### Phase exit criteria (per /align-gate)
- Every finding: `status=fixed` in ledger.
- Every finding: re-detect returns 0 hits at the cited evidence lines.
- Cumulative diff: net-lines ≤ 0.
- Lint + typecheck + scoped tests green.
- Coverage ≥ pre-phase baseline.
- No new symbol introduced.
- For frontend phases: visual regression / a11y regression / bundle-size all green.

## Phase 2 — <theme>
(same shape)

...

## Phase K — <theme>
(same shape)

## Total: <N> findings across <K> phases
## Estimated wall-clock (sequential): <X> days
## Estimated wall-clock (via /align-fast, parallel where independent): <Y> days
```

Update `ai/align/ledger.md`:
- Each row's `phase: <N>` field is filled in.
- Rows assigned to no phase (excluded via `--exclude-*`) keep `phase: <unassigned>` and `status: detected`.

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/align/plan.md` — managed-block; re-runnable.
- `ai/align/ledger.md` — update `phase` field per row (managed-block update).
- `ai/index.md` — append-once entry pointing to the plan.

## Phase 6 — Validate (verify correctness)

- Every ledger row that's eligible (not excluded by flags) has `phase: <N>` set.
- No phase exceeds `--max-findings-per-phase`.
- Phase 1 contains only trivial-tier rows OR is explicitly justified (heavy-tier in phase 1 is a yellow flag — usually means over-promotion at scan time).
- Within each phase, dependency order is correct (helper-introduce before consumer-swap; remove-callers before remove-wrapper).
- Heavy-tier rows have a single-finding-per-phase rule applied OR a justification in the phase notes (heavy rows benefit from supervision).
- Phase exit criteria are measurable (gap-count parity, re-detect, test-suite — not vague language).
- Frontend phases that touch UI rendering name the visual regression baseline + a11y baseline they'll validate against.

If any check fails → halt + report.

## Phase 7 — Improve (feed the learning loop)

- If a phase has 1 finding, surface "consider merging with phase N±1" — single-finding phases waste gate ceremony.
- If a class has > 50 findings across multiple phases, surface "consider authoring a lint rule / pre-commit hook" — the convention isn't enforced; alignment will rot back without it. Queue ADR.
- If a finding's `shared_equivalent` resolves to a file not in `_extracted-idioms.md`'s named inventory, surface "oracle drift; run `/setup-project --refine` to update".
- If the dependency graph surfaced a circular dependency between findings → halt; the underlying convention is contradictory; ADR before fixing.

## Output to user

```
Alignment plan written:
  ai/align/plan.md

Phases:                      <K>
Total findings:              <N>
  Trivial:                   <T>
  Standard:                  <S>
  Heavy:                     <H>
Largest phase:               <Y> findings (phase <P>)
Excluded by flags:           <X> findings (status=detected, no phase)

Next: /align-phase 1       (executes phase 1, manual flow)
   OR: /align-fast 1       (one-shot phase 1 + auto-gate, parallel waves)
```

## Mechanical halt — refuse to invent findings or fabricate paths

Every plan row MUST trace to a ledger row by `id`. Forbidden: adding a finding to the plan that isn't in the ledger; citing evidence not present in the ledger row; assigning a `phase` to a row whose `status != detected` (rows already in-progress / fixed / archived stay where they are); using `...`, `etc.`, `and similar` in any phase summary.

If a plan-time discovery surfaces a missing finding → halt; the user runs `/align-scan` to re-inventory. Do NOT silently extend the ledger from this command.

## Hard rules

- **No phase ships findings that aren't in the ledger.** The ledger is the source of truth; the plan reads from it, never invents findings.
- **Every phase has measurable exit criteria.** Not "phase complete when most things look better."
- **Cap at 12 findings per phase.** Larger phases hide regressions in PR review and slow the gate.
- **Mechanical first.** Phase 1 is dead-code OR silent-catch (or both, if combined trivial count ≤ 12). Refuses a plan that puts heavy / cross-cutting work in phase 1.
- **Domain coherence for UI/UX.** Frontend UI/UX phases group by page/domain, not by sub-class. A "auth a11y" phase reviews better than a "all-pages a11y" phase.
- **Heavy-tier rows isolated** — at most 3 heavy-tier rows per phase, ideally 1.
- **No partial findings in a phase.** A finding is either fully in this phase (all evidence sites closed) or not. Half-fixed findings rot.

## Failure modes

- **Empty ledger** — no `detected` rows. Halt; nothing to plan.
- **All rows excluded by flags** — every row matched `--exclude-*`. Halt; user-error or scan turned up nothing planner-actionable.
- **Phase 1 has heavy rows** — surface yellow flag; user confirms or re-runs with `--exclude-tier=heavy` for an initial mechanical-only sweep.
- **Circular finding dependencies** — finding X needs finding Y closed first, finding Y needs finding X. Halt; convention is contradictory.
- **Visual regression baseline missing** (frontend) — UI/UX phases reference a baseline that doesn't exist. Halt; route to "run baseline command first".

## Related

### Sibling commands in align pack
- `/align-scan` — runs before this command; produces the inputs.
- `/align-phase <N>` — next command; executes phase N from this plan.
- `/align-fast <N>` — one-shot per-phase variant (mirrors `/migration-fast`).
- `/align-status` — read-only ledger reader.
- `/align-rollback <N>` — undo a phase if a regression slipped through the gate.

### Rules
- `.claude/rules/align-discipline.md` — the parity contract enforced downstream.

### Patterns
- `ai/patterns/align-ledger.md` — schema for the ledger this command updates.
