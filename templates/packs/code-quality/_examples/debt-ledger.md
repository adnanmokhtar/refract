---
name: debt-ledger
kind: example
pack: code-quality
---

# Skill: debt-ledger

Technical debt that gets rediscovered on every audit is debt nobody is accountable for. This skill treats debt as a **persisted, ranked ledger** at `ai/debt-ledger.md` — not a transient scan result. Every item carries an owner, a date, a blast-radius, and a fix-cost, and every run **diffs against the last ledger** so accrual (new debt vs paid-down) is visible. The point is to make *accrual over time* visible, so intentional debt gets a due date instead of becoming permanent. Every item cites `<path:line>`.

## Boundary — what this owns vs siblings

- `dead-code-finder` / `dead-branch-scan` find **unreachable** code (delete). Debt is *reachable, running* code that's knowingly suboptimal — disjoint.
- `@dependency-auditor` owns dep **vulnerabilities / licenses**; this skill records **version-lag as debt** (how far behind, catch-up cost).
- `check-health` surfaces debt **point-in-time**; this skill is the **longitudinal tracker** — persist, rank, diff run-over-run.
- `architectural-diagnosis` finds **unmarked** structural smells; this tracks **marked/intentional** debt (a finding may spawn a ledger item).

## The four debt kinds (inventory sources)

1. **Undated / unowned markers** — `TODO`/`FIXME`/`HACK`/`XXX` with no `(owner, YYYY-MM)`. Age via `git blame`.
2. **Unjustified suppressions** — `eslint-disable` / `@ts-ignore` / `# noqa` / `@SuppressWarnings` / `//nolint` with no adjacent reason.
3. **Deprecated-API call sites** — calls into `@deprecated` surface; rank by call-site count + removal timeline.
4. **Major-version-behind deps** — ≥ 1 major behind; record lag magnitude + migration cost.

## Ranking

Score **blast-radius × fix-cost**, bucket by priority (high-blast × low-cost first), age as a multiplier (older debt ranks up).

## Halt conditions

- Refuse an item with no `<path:line>` cite, or one without both a blast-radius AND a fix-cost.
- Do NOT auto-delete / auto-fix — records and ranks; remediation is a separate owned decision.
- A suppression WITH a justification + issue link is compliant, not debt.
- Missing prior ledger → **baseline mode** (whole ledger is "new"; say so), don't fail.

## The persisted artifact — `ai/debt-ledger.md`

Header: run commit + previous ledger + accrual (`+new / −paid / net`). An accrual-diff headline table, then open debt ranked (`D-001 … [P0 · blast=high · cost=low]` with kind / evidence / owner / since / due), then a "paid down since last run" section. INTERNAL — `check-health` / planning cite its headline numbers, not the whole file. The run-over-run **net accrual** is the health signal.

## Related

- `dead-branch-scan` — unreachable code (delete); disjoint from reachable-but-suboptimal debt.
- `@dependency-auditor` — dep vulns/licenses; this owns dep version-lag as tracked debt.
- `check-health` — point-in-time snapshot; cites this ledger's headline.
