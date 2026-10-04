---
purpose: The posting bar every review applies before a finding reaches a human — three severities, a nit cap, no style where a formatter exists, Important-only after round 1, escalation on round 3. Shared by every review lens, every review command and the review records persist-review.sh writes.
---

# Posting bar — what a review is allowed to say

A review that posts everything it noticed is a review nobody reads. Nits drown the one finding that
matters; style comments argue with the formatter; round three re-litigates round one. The bar below
is applied **after** [`refute-before-report.md`](refute-before-report.md) — a candidate that did not
survive verification is never posted, whatever its severity — and **before** anything is printed,
written to a review record, or posted to a PR.

## 1. Three severities, one vocabulary

| Severity | Means | Blocks? |
|---|---|---|
| **IMPORTANT** | A verified defect this change introduced, touched or copied: a wrong result, data loss, a crash, a contract break, a security hole, a *measured* performance or accessibility violation | Yes — the run is not COMPLETE while one stands |
| **NIT** | Real, small, and worth one line: a misleading name, a missing edge-case test that is not a criterion, a clearer shape the siblings already use | Never |
| **PRE-EXISTING** | A real defect in code this change neither introduced, touched nor copied | **Never blocks a diff review**; listed with its probe so it can be scheduled (refute-before-report § 5) |

These replace every older label set in review output (`BLOCKER / CRITICAL / HIGH / MEDIUM / LOW`,
`must-fix / should-fix`, `APPROVE / REQUEST_CHANGES`). A command that keeps a domain scale for
ranking (security's CRITICAL…LOW, an audit's P0…P3) maps it onto this bar when it posts: anything at
or above its blocking threshold that survived verification is IMPORTANT; the rest is a NIT or not
posted. The verdict vocabulary that sits above the findings is one too: **PASS · CONCERNS · FAIL**
(security's GO · GO-UNVERIFIED · NO-GO are display aliases of the same three).

## 2. Caps and exclusions

- **At most 5 NITs per review.** Keep the five that matter most; drop the rest silently — a sixth
  nit costs the reader more than it gives. `persist-review.sh` refuses a record with more.
- **Never comment on style where a formatter or linter owns it.** Indentation, quotes, import order,
  line length, trailing commas — when the project configures Prettier, Biome, Black, Ruff format,
  gofmt, rustfmt, clang-format, swiftformat, php-cs-fixer or an equivalent, the tool decides and the
  review is silent. A style finding in a project that has a formatter is refused at persist time.
- **Never restate a tool finding.** If the linter, type checker, test run or scanner already reported
  it, cite the tool's output in the evidence ledger; do not post it again as a review finding.
- **Every posted finding is restated** as one sentence: *When <condition reachable in real use>,
  <code at file:line> produces <observable wrong outcome> instead of <expected outcome>.* A finding
  that cannot be written that way is an opinion, not a finding.

## 3. Rounds

| Round | What may be posted |
|---|---|
| 1 | IMPORTANT, up to 5 NITs, PRE-EXISTING (listed, non-blocking) |
| 2 | **IMPORTANT only** — a NIT that was not worth fixing in round 1 is not worth a second round |
| 3+ | A non-trivial finding still open on a third pass is **an upstream problem**, not a review comment: the requirement, the design or the contract is wrong or missing. Escalate to a human with the finding and the history; do not post round four |

`persist-review.sh` numbers the rounds per lens per run (`round` in the record), refuses NITs from
round 2, and stamps `escalate: true` when round 3 still carries an IMPORTANT finding.

## 4. What reaches the human

One line per IMPORTANT finding (with its proof), the NITs, the PRE-EXISTING list, and the
verification tally from refute-before-report § 5:
`Verification: <n> candidates → <F> findings · <U> unconfirmed · <H> hardening · <P> pre-existing · <R> refuted`.
An empty review says so in one line — "no IMPORTANT finding; N candidates refuted" — rather than
padding itself with nits to look thorough.

---

Source of the bar: the research behind Refract's verification layer (`[A §2 #8]`, `[B §1 #6]`,
`[B §3]` in the architecture proposal) — reviewer noise, rounds-to-convergence and dismissal rates
are the measured failure modes of LLM code review; the caps answer them directly. The hosted-review
twin of this file is `REVIEW.md` in the project root when the project uses one.
