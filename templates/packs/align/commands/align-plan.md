---
description: Forces a phased alignment plan from the align ledger. Groups plannable rows by AL class, domain, tier and dependency, ≤ 12 per phase; routed and pending rows stay out. Never invents a row or edits the oracle.
kind: command
pack: align
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
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
- `ai/align/ledger.md` — the rows (`- id: A<NNN>` form, with `al_class`, `oracle` + `oracle_tier`, `owner`, `proof_class`, `tier`, `status`).
- `ai/align/scan-report.md` — the class ledger, the BIMODAL block and the ratification list of the last `/align-scan`; `ai/audits/<date>-align.md` is the same report and its `## What to do next` order (MUST → SHOULD → OPTIONAL) is the order this plan honours.
- `ai/architecture.md`, `ai/modules.md` — declared module boundaries (constraints on dependency order).
- `ai/conventions.md`, ADRs (`docs/adr`, `ai/decisions`) — the oracle lines rows cite; a frozen package (an ADR with a date not yet passed) is never phased (precedents/align § 16).
- `_extracted-idioms.md` → `codebase-profile.md` — the named wrappers and helpers (the inventory fallback order).

**Which rows are plannable.** Only `status: detected` rows whose closer is align (the `align-detect` class ledger's Closer column). These stay out of every phase and keep their status, listed by name in the plan's `## Not phased` section:
- `routed` — the owner's fix command closes it (`routed:` names the command and the audit id);
- `pending-ratification` — a T2g oracle; one ratification line per rule, never a fix;
- `pending-approval` — a VC row without a human `approval:`; it enters a phase only once a human fills it;
- `refuted`, `parked`, `archived-*` — terminal or deferred;
- AL-02 (a split: 0 rows by construction) and AL-04 (a stale doc: an advisory for a human doc update, never a code change).

Optional flags:
- `--phases=<N>` — target number of phases (default: auto from the row count, capped by `--max-findings-per-phase`).
- `--max-findings-per-phase=<N>` — cap per phase (default: 12). Larger phases hide regressions and slow review.
- `--strategy=<class|domain|mixed>` — phasing strategy (default: `mixed` — class-first for import, ratchet and name rows; domain-first for UI rows).
- `--exclude-class=<list>` — skip AL classes (e.g. `--exclude-class=AL-16,AL-17`); excluded rows stay `status: detected` and are picked up in a later run. A legacy class name is read through `align-detect` § The legacy class map.
- `--exclude-tier=<list>` — skip tiers (e.g., `--exclude-tier=heavy`).

## Phase 2 — Organize (decompose the work)

Decomposition strategy, in priority order:

1. **Regressions first.** AL-30 rows (a baseline that grew, a severity loosened) are MUST rows and force DRIFT on their own; closing the sites the grown entries hide is usually trivial, and nothing else can be measured against a baseline that is still growing (the baseline file itself is never edited in an align commit: `/align-gate` checks 8 and 12). They go in phase 1 with the trivial AL-29 rows (a reasonless suppression whose fix is the convention swap itself).
2. **Mechanical EQ rows next.** Classes whose fix is a local swap with a zero-diff proof: AL-14 deep imports, AL-11 raw imports where the wrapper's defaults reproduce the call, AL-22 a banned library with a declared replacement. One closure verb (`replace-with-shared`), one diff shape, one review.
3. **Domain grouping for UI rows.** The owner rows align closes — AL-05 / AL-07 / AL-12 EQ token and element swaps (ui-ux), AL-26 EQ keys and AL-28 in the AL-15 form (frontend) — group by **page or feature domain** ("auth pages", "checkout flow"), not by class: one page's token, key and prop swaps touch the same files and review together. Every such row is EQ; a nearest-token snap is AL-06 and VC, and is plannable only with its approval.
4. **Honour the dependency graph.** A row that re-routes callers through a wrapper goes before a row that removes the wrapper's raw twin; a `dedupe` (AL-13) goes after the rows that move the copy's callers; a rename (AL-16/17/18) goes after every row whose evidence sits in the file it renames.
5. **Cap phase size.** Phases over `--max-findings-per-phase` get split. **One way per pattern:** rows that share a V393 group key (rule, normalised before-value) stay in one phase, so `/align-gate` check 7 sees every after-value at once.
6. **Gates as their own phase.** AL-15 rows that add a declared permission, tenant or auth gate are FN rows proven by a behaviour test and are heavy tier: they get an early phase of their own (HIGH rows are MUST), never bundled with trivial swaps.
7. **Enforcement last.** AL-03 (turn a T2 rule into a T1 rule at `error` with a shrink-only baseline generated **after** the fixes) and AL-31 (package config drift, heavy) close the sweep: enabling the rule before the sites are fixed only grows the baseline. AL-32 (a declared migration half done) is ratcheted, then shrunk per phase.

### Phasing template (typical example, NOT a rule)

A starting point; the planner adapts to the actual row counts, the `--strategy` flag and ADR-recorded priorities. Skip phases with 0 rows; merge phases with similar themes.

| Phase | Theme | AL classes | Tier mix | Proof |
|---|---|---|---|---|
| 1 | Regressions and suppressions | AL-30, AL-29 | trivial | ratchet shrink-only (V395), reason resolves (V406) |
| 2 | Gates and required props | AL-15 (and AL-28 in the AL-15 form) | standard + heavy | FN render test as the role (V401) |
| 3 | Imports through the declared wrapper | AL-11, AL-14, AL-22 | trivial + standard | import count to zero (V400), boundary whole-repo (V404) |
| 4 | UI swaps, one domain per phase | AL-05, AL-07, AL-12 EQ; AL-26 EQ key | trivial | zero computed-style diff (V394) or `(static EQ)` |
| 5 | Helper copies | AL-13 | standard | dedupe differential (V403) |
| 6 | Names and layout | AL-16, AL-17, AL-18, AL-19 | standard | serialised names unchanged (V402) |
| 7 | Declared migration | AL-32 | standard | ratchet shrink-only (V395) |
| 8 | Enforcement | AL-03, AL-31 | heavy | rule at error count (V390), non-vacuous (V399) |

On a backend-only project phases 4 and 2's a11y half drop out; on a project with no ui-ux or frontend pack, phase 4 has no rows (those classes are `N/A (owner pack … not installed)` in the scan). A phase with 0 rows is dropped; a phase with > 12 is split.

## Phase 3 — Retrieve (read the right context)

For each row's domain assignment:
- Read 1-2 source files in the row's `scope` to understand which domain they belong to (auth / orders / dashboard / shared).
- Cross-reference `ai/architecture.md` / `ai/modules.md` if they document domain boundaries explicitly.
- Re-read the row's `oracle:` quote in its file; a quote that no longer resolves makes the row AL-01 — halt and re-scan rather than phase it.

This is moderate work; fan out via Explore subagents capped per `--max-subagents`.

## Phase 4 — Generate (produce the output)

Write `ai/align/plan.md`:

```markdown
# Alignment plan

Generated: <YYYY-MM-DD>
Audit source: ai/audits/<date>-align.md (= ai/align/scan-report.md, rev <commit>), verdict <ALIGNED-UNVERIFIED (n) | DRIFT>
Ledger source: ai/align/ledger.md (revision pinned)
PROJECT_KIND: <kind>

## Strategy

Phasing strategy: <class|domain|mixed>
Cap per phase: <N> rows
Plannable rows: <N> (of <M> in the ledger)
Total phases: <K>

## The oracle this plan enforces (non-negotiable target)

> The alignment closes drift toward what the project declares — never toward a majority, never toward a generated line. Cite specifics so each phase knows what "follow the convention" means.

- Oracle tiers (from the scan): T1 <n> · T2 <n> · T2g <n> (unratified) · contested <n>
- Wrappers and helpers the rows route through: <name → path, from wrappers.tsv / _extracted-idioms.md>
- Oracle lines cited by this plan's rows: <path:line "quote"> per rule
- Architecture boundaries respected: <list from ai/architecture.md / ai/modules.md>

## Phase 1 — <theme>
**Goal**: <one-line objective>
**AL classes**: <AL ids>
**Tier mix**: <T trivial / S standard / H heavy>
**Proof classes**: <EQ n / FN n / VC n (each with approval)>
**Estimated effort**: <hours/days>

### Rows in this phase
| ID | AL class | Owner | Tier | Files | Closure verb | Proof class | Evidence count |
|---|---|---|---|---|---|---|---|
| A001 | AL-30 | align | trivial | 1 | replace-with-shared | EQ | 1 |
| A002 | AL-29 | align | trivial | 1 | replace-with-shared | EQ | 1 |

### Phase exit criteria (the /align-gate 17-check matrix)
- Every row `status=fixed` (check 1); `gaps_closed == len(evidence)` (2).
- Re-detect zero at every evidence line (6); every removed line an evidence line or verb footprint (5).
- One after-value per before-value across the phase (7); every emitted token, import and export declared (9).
- No test, snapshot, fixture, lint-config, baseline or oracle file in a row commit; test and assertion counts not down (8); coverage within tolerance (15).
- EQ rows: zero computed-style or compiled-CSS diff, or `(static EQ)` with the probe; VC rows: a named human approval (13).
- Structural rows net-lines ≤ 0 (3); no new symbol the oracle does not name (4).
- Lint + typecheck + build + tests + boot green at HEAD (14).

## Phase 2 — <theme>
(same shape)

## Phase K — <theme>
(same shape)

## Not phased
| ID | AL class | Status | Why | Next |
|---|---|---|---|---|
| A031 | AL-06 | pending-approval | nearest-token snap (VC) | a human fills `approval:`, then `/align-replan` |
| A040 | AL-23 | routed | declared API contract | `/backend-fix ai/audits/<date>-align.md#F-07` |
| — | AL-02 | — | split, no declared winner | ratify in `/setup-project --refine` |

## Total: <N> rows across <K> phases
## Estimated wall-clock (sequential): <X> days
## Estimated wall-clock (via /align-fast, parallel where independent): <Y> days
```

Update `ai/align/ledger.md`:
- Each phased row's `phase: <N>` field is filled in and its `status` moves `detected → planned`.
- Rows assigned to no phase (excluded via `--exclude-*`) keep `phase: <unassigned>` and `status: detected`.

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/align/plan.md` — managed-block; re-runnable.
- `ai/align/ledger.md` — update `phase` field per row (managed-block update).
- `ai/index.md` — append-once entry pointing to the plan.

## Phase 6 — Validate (verify correctness)

- Every plannable row (not excluded by flags) has `phase: <N>` set; no `routed`, `pending-*`, `refuted`, `parked` or `archived-*` row has one.
- No phase exceeds `--max-findings-per-phase`; rows sharing a V393 group key sit in one phase.
- Phase 1 contains only trivial-tier rows OR is explicitly justified (heavy-tier in phase 1 is a yellow flag — usually means over-promotion at scan time).
- Within each phase, dependency order is correct (re-route callers before removing a raw twin; move a copy's callers before `dedupe`; renames after the rows whose evidence sits in the renamed file).
- Heavy-tier rows have a single-finding-per-phase rule applied OR a justification in the phase notes (heavy rows benefit from supervision).
- Every row has a `proof_class`; a VC row in a phase already carries `approval: <name>@<iso>` written by a human.
- Phase exit criteria are the 17 gate checks (not vague language).
- A phase with EQ UI rows names its proof harness: the computed-style dump (L10a), the compiled-CSS diff, or `(static EQ)` with the probe written out.

If any check fails → halt + report.

## Phase 7 — Improve (feed the learning loop)

- If a phase has 1 row, surface "consider merging with phase N±1" — single-row phases waste gate ceremony.
- If a class has > 50 rows across multiple phases and no AL-03 row exists for it, surface "the convention has no T1 rule at error" — alignment will rot back without one. Queue the rule (a `no-restricted-imports` path, an ls-lint key) and a shrink-only baseline as the enforcement phase.
- If a row's `shared_equivalent` resolves to a file no oracle row names (not in `wrappers.tsv`, not in `_extracted-idioms.md`), surface "oracle drift; run `/setup-project --refine` to update".
- If the dependency graph surfaced a circular dependency between findings → halt; the underlying convention is contradictory; ADR before fixing.

## Output to user

```
Alignment plan written:
  ai/align/plan.md

Phases:                      <K>
Plannable rows:              <N>
  Trivial:                   <T>
  Standard:                  <S>
  Heavy:                     <H>
  EQ / FN / VC (approved):   <E> / <F> / <V>
Largest phase:               <Y> rows (phase <P>)
Excluded by flags:           <X> rows (status=detected, no phase)
Not phased:                  <R> routed · <A> pending-approval · <G> pending-ratification · <D> AL-04 doc advisories

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
- **Regressions and mechanical rows first.** Phase 1 holds trivial rows only — AL-30 / AL-29 first, then EQ import swaps. Refuses a plan that puts heavy / cross-cutting work in phase 1.
- **Only align-closed rows are phased.** A row whose closer is another command (`routed`), whose oracle is generated (`pending-ratification`) or whose visible change has no human approval (`pending-approval`) is listed under `## Not phased`, never in a phase.
- **Domain coherence for UI rows.** EQ token, element and key swaps group by page/domain, not by class. An "auth pages" phase reviews better than an "all-pages tokens" phase.
- **Heavy-tier rows isolated** — at most 3 heavy-tier rows per phase, ideally 1.
- **No partial findings in a phase.** A finding is either fully in this phase (all evidence sites closed) or not. Half-fixed findings rot.

## Failure modes

- **Empty ledger** — no `detected` rows. Halt; nothing to plan.
- **All rows excluded by flags** — every row matched `--exclude-*`. Halt; user-error or scan turned up nothing planner-actionable.
- **Phase 1 has heavy rows** — surface yellow flag; user confirms or re-runs with `--exclude-tier=heavy` for an initial mechanical-only sweep.
- **Circular row dependencies** — row X needs row Y closed first, row Y needs row X. Halt; the convention is contradictory; ADR before fixing.
- **Every row is routed or pending** — nothing is align's to close. Not a failure: the plan is the `## Not phased` table, and the next steps are the owners' fix commands and the ratification lines.
- **No proof harness for EQ UI rows** — no browser and no CSS build. The rows stay plannable as `(static EQ)` with the probe written out; say so in the phase notes, never claim a zero diff that was not measured.

## Related

### Agents
- `.claude/agents/align-evidence-auditor.md` — audits the scan's rows at `/align-scan` Phase 6, before they reach this command. This command therefore phases **audited** rows only: anything it can see has already cleared evidence resolution, explicit enumeration, class-matches-signal, verb reachability, and the tier floor. If a `REJECT — out of domain` row shows up in the ledger anyway, the scan's Phase 6 did not run — halt and re-scan rather than phasing it.

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
