---
purpose: The two non-negotiable invariants every /fix-bug variant shares — failing-test-first (TDD) and the similar-bugs blast-radius ledger. Baseline and pack fix-bug commands link here so they cannot silently diverge on the load-bearing mechanics.
imported-by: templates/repo-baseline/.claude/commands/fix-bug.md (universal minimum) + templates/packs/backend/commands/fix-bug.md (enriched superset).
---

# /fix-bug core invariants (shared, non-negotiable)

Every `/fix-bug` variant — the universal baseline and every pack superset — MUST honour both invariants below. Packs ADD ceremony (telemetry gap check, reviewer cascade, postmortems); they never relax these two.

## 1. Failing test FIRST (TDD ordering)

Phase 4 order is **Reproduce → Diagnose → write FAILING test → minimal fix → verify** — never fix-then-test.

- The test is written **before** the fix and currently **FAILS for the diagnosed reason** (proving it catches *this* bug).
- Deterministic — no `sleep`, real clock, or unseeded randomness.
- Right level — unit / integration / e2e / widget per where the root cause lives.
- **Do not write the fix until the test reliably fails.** A fix before a failing test is an unverified hypothesis. This is the whole point of the command.

## 2. Similar-bugs blast-radius ledger

A reported bug is a sample, not the population. After fixing the reported site, grep the codebase for the **literal root-cause pattern** (not a vague concept), count hits, and account for every one:

`N_found == N_fixed + N_explained + N_followup`

- **fixed** — same fix applied in this diff (preferred default).
- **explained** — 1-line rationale why this hit is intentionally different.
- **followup** — tracked ticket id; out of scope for this diff.

Merge HALTS on `N_found != N_fixed + N_explained + N_followup`. Trivial tier (1 site by definition) confirms `N_found == 1`; the moment a 2nd hit appears the row promotes to standard and the ledger becomes mandatory.

---

A variant that violates either invariant is broken, regardless of how much other ceremony it carries.
