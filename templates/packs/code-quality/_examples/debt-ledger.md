---
name: debt-ledger
description: Track technical debt as a persisted, ranked ledger — dated/owned TODOs, unjustified suppressions, deprecated-API call sites, major-version-lag deps — each with a blast-radius and a fix-cost, diffed run-over-run so accrual (new debt vs paid-down) is visible instead of rediscovered every audit.
kind: example
pack: code-quality
---

# Skill: debt-ledger

## Premise

Technical debt that gets rediscovered on every audit is debt nobody is accountable for. This skill treats debt as a **persisted, ranked ledger** at `ai/debt-ledger.md` — not a transient scan result. Every item carries an owner, a date, a blast-radius, and a fix-cost, and every run **diffs against the last ledger** so accrual (new debt vs paid-down) is visible. The point is to make *accrual over time* visible, so intentional debt gets a due date instead of becoming permanent. Every item cites `<path:line>`. "Debt" here means **intentional, marked, or knowingly-deferred** shortcuts. If it isn't cite-backed and classifiable into one of the four inventory sources below, it doesn't go in the ledger.

## Boundary — what this owns vs siblings

- `dead-code-finder` / `dead-branch-scan` find **unreachable** code (delete). Debt is *reachable, running* code that's knowingly suboptimal — disjoint.
- `@dependency-auditor` owns dep **vulnerabilities / licenses**; this skill records **version-lag as debt** (how far behind, catch-up cost).
- `check-health` surfaces debt **point-in-time**; this skill is the **longitudinal tracker** — persist, rank, diff run-over-run.
- `architectural-diagnosis` finds **unmarked** structural smells; this tracks **marked/intentional** debt (a finding may spawn a ledger item).

## Halt conditions

- Refuse an item with no `<path:line>` cite, or one without both a blast-radius AND a fix-cost.
- Do NOT auto-delete / auto-fix — records and ranks; remediation is a separate owned decision.
- A suppression WITH a justification + issue link is compliant, not debt.
- Missing prior ledger → **baseline mode** (whole ledger is "new"; say so), don't fail.

## When to use

- Quarterly (or per-release) debt review — the canonical cadence; the diff is the deliverable.
- After a "we'll fix it later" sprint — capture the deferrals as dated, owned items before they evaporate.
- Before planning — the ranked ledger feeds the top-N into the backlog.
- After a major dependency or language-version bump — record the new deprecated-API surface the bump introduced.

## The four debt kinds (inventory sources)

1. **Undated / unowned markers** — `TODO`/`FIXME`/`HACK`/`XXX` with no `(owner, YYYY-MM)`. Age via `git blame`.
2. **Unjustified suppressions** — `eslint-disable` / `@ts-ignore` / `# noqa` / `@SuppressWarnings` / `//nolint` with no adjacent reason.
3. **Deprecated-API call sites** — calls into `@deprecated` surface; rank by call-site count + removal timeline.
4. **Major-version-behind deps** — ≥ 1 major behind; record lag magnitude + migration cost.

## Ranking

Score **blast-radius × fix-cost**, bucket by priority (high-blast × low-cost first), age as a multiplier (older debt ranks up).

## The persisted artifact — `ai/debt-ledger.md`

Header: run commit + previous ledger + accrual (`+new / −paid / net`). An accrual-diff headline table, then open debt ranked (`D-001 … [P0 · blast=high · cost=low]` with kind / evidence / owner / since / due), then a "paid down since last run" section. INTERNAL — `check-health` / planning cite its headline numbers, not the whole file. The run-over-run **net accrual** is the health signal.

## Procedure (step-by-step)

1. **Pin commit** — `git rev-parse HEAD` → artifact header.
2. **Load prior ledger** — read the previous `ai/debt-ledger.md` if present; else baseline mode.
3. **Run the four inventory sources** — collect cite-backed candidates from markers, suppressions, deprecated-API call sites, dep version-lag.
4. **Filter compliant items** — drop markers with owner+date, suppressions with justification, `@ts-expect-error` that self-heal; keep only real debt.
5. **Age each item** — `git blame` / `git log` for first-seen date; compute age.
6. **Rank** — blast-radius × fix-cost × age → priority bucket per item.
7. **Diff against prior ledger** — match by (kind, path-anchor, identity); classify each as new / carried / paid-down. Compute the accrual headline.
8. **Assign owners** — from `git blame` where the marker/suppression has no explicit owner; flag `NEEDS OWNER`.
9. **Write `ai/debt-ledger.md`** — the structure above. No fixes applied.

## Related

- `dead-branch-scan` — unreachable code (delete); disjoint from reachable-but-suboptimal debt.
- `@dependency-auditor` — dep vulns/licenses; this owns dep version-lag as tracked debt.
- `check-health` — point-in-time snapshot; cites this ledger's headline.
