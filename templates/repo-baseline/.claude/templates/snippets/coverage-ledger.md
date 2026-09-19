---
artifact: coverage-ledger
purpose: The one contract every scanning command owes its reader — what it LOOKED AT, not only what it found.
imported-by: commands that scan a population and report findings (/optimize, /polish, /align, /unify-surfaces, /security-audit, /db-audit, /perf-audit, and any pack audit skill).
---

# Coverage ledger — say what you looked at

**A findings list is not a report.** `no findings` and `did not look` print identically in a
document that only lists findings, and the reader cannot tell them apart — which means the most
valuable thing a scan can tell you (*nobody is checking this*) is the one thing it cannot say.

This was not hypothetical. A visual sweep finished fast, reported every page scanned and no
problems, and had rendered nothing at all: no screenshots, no artifacts, no evidence of any kind.
Every structural gate in the repo was green while it happened, because gates check that files are
well-formed, not that work occurred.

## The contract

Before any command that scans a population may print a verdict, it emits a ledger over that
population. Every unit lands in exactly one column:

| Column | Meaning | The row must carry |
|---|---|---|
| **Reviewed** | the unit was examined | its findings, or an explicit clean verdict |
| **N/A** | the check has no meaning for this unit | **a reason, always — never a bare `N/A`** |
| **Live, unreviewed** | the check applies and nothing ran | the unit's population, so the gap is sized |
| **Blocked** | examination was attempted and failed | what blocked it |

**Print the arithmetic.** The four counts sum to the resolved population, and the line showing
that is the report's honesty check: `reviewed 78 · N/A 31 (each with a reason) · live-unreviewed 23
· blocked 0 = 132`.

## Four rules, each written after a specific failure

1. **A unit may never be silently absent.** Absent means the resolution step has a bug, and the run
   says so rather than shrinking its own denominator.
2. **No bare `N/A`.** A reasonless N/A is indistinguishable from a skip, and it is how a scope
   decision and an oversight come to look the same.
3. **`Live, unreviewed` is never merged into `N/A`.** They are opposite claims: N/A says *this does
   not apply here*; live-unreviewed says *this applies and nobody is looking*. Collapsing the second
   into the first is how a coverage gap disguises itself as a scoping decision.
4. **`Blocked` is its own column.** A unit that could not be examined is neither clean nor out of
   scope — it is unexamined, and averaging it into either is the failure above.

## What this is not

It is **not a quality bar.** The ledger says what was looked at; whether the thing looked at is
*good* is a separate question, and only the commands that make judgements (`/audit`, `/ui-audit`,
`/optimize`, `/polish`) carry a bar. An enforcement command (`/align`) or a transformation
(`/unify-surfaces`) owes its reader coverage, not taste — it applies a documented rule, and "this
rule was not checked here" is exactly the gap this ledger exists to surface.

It is also **not a new phase.** The ledger is emitted from the population the command already
resolved, at the point it already knows what it scanned. A command that cannot produce one does not
know what it scanned, which is the finding.
