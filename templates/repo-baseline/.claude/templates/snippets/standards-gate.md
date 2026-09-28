---
purpose: The all-tier standards gate every build command runs — select the engineering-baseline rows the change fires, carry them into the plan as constraints, and close each with evidence before the run may report success.
---

# Standards gate — all tiers

A build command's other gates ask whether the new code **looks like** its siblings. This one asks
whether it **meets the baseline** — uniqueness, idempotency, timeouts, authorization, states,
tests — whatever the siblings do. It runs at every tier: the tier decides how much ceremony a
change gets, never which standards it may skip.

The rows live in [`governance/engineering-baseline/`](../governance/engineering-baseline/README.md)
— read its `README.md` once for the row format, verdicts and precedence. In a project it is installed
at `.claude/templates/governance/engineering-baseline/`, beside this file.

## Step 1 — Select (before Generate)

1. Read the baseline files that apply: `architecture.md` and `quality-gates.md` always; then
   `backend-api.md`, `web.md` or `mobile.md` by `PROJECT_KIND` (both halves for `mixed`); and
   `data.md` whenever the change touches a schema, entity, migration, query or repository.
2. Keep every row whose **Fires when** matches what the change does — never the tier. A row you
   considered and set aside goes on one line, `Considered, not fired: SEC-01, API-7 — no new entry
   point`, not into the ledger. **Project-level rows** (Fires when = *project-level*) never enter a
   change's ledger: the detector (Step 2) reports them once, as one line.
3. Carry the fired IDs into the plan as constraints — a trivial run writes one line:
   `Baseline: DATA-1, DATA-2, SEC-01, SEC-04, API-9, QG-1`.
4. **Check what you are about to mirror.** If the sibling you copy, or the V1 code you port,
   violates a fired row — no unique constraint on the email, no timeout on the client, no 403
   test — say so here. The default is to fix it in this change; if that is out of scope, the row
   will close `UNMET` with a follow-up. It is never a shape to copy.

## Step 2 — Close (after Validate, before the Output block)

One ledger row per fired ID:

| ID | Verdict | Evidence |
|---|---|---|
| DATA-1 | MET | `prisma/schema.prisma:41` `@@unique([tenantId, email])` · `users.spec.ts` "rejects a duplicate email" ran green |
| RES-3 | n-a | no outbound call in this change |
| SEC-04 | UNMET | no 403 test for a non-owner — follow-up filed |

- **Verdicts:** `MET <evidence>` · `n-a <reason>` · `UNMET` · `SKIPPED — unverified: <command a
  reviewer must run>`.
- **Evidence** is a `file:line`, a named test that **ran green** — in this run, or in the CI run
  for this commit — or a command's output. A claim, a plan line or "follows the sibling" is not
  evidence.
- **One line per piece of evidence.** Rows closed by the same evidence share a ledger line —
  `RES-2 · RES-3 · RES-4 | n-a | no outbound call`; the hooks and CI rows (QG-7, QG-8, QG-12) close
  together on `hooks + CI green`.
- **Reuse, don't re-judge.** Where the command's own gate already produced a verdict for an ID —
  the production-readiness ledger, a reviewer's table, the spec-conformance gate — cite that
  verdict as the evidence.
- A `hook:` row is closed by the hook's result, not by re-running its check by hand.
- **Run the detector on the change.** `python3 ~/.claude/scripts/standards-check.py . --changed=<base>`
  reads the files this change touched for the rows a machine can decide — DATA-1, DATA-9, RES-3,
  OBS-5, WEB-2, WEB-3, QG-7. Its output is the evidence for those rows; an OPEN line there is
  `UNMET` here unless this change fixes it or `.claude/standards-check.allow` records why it does
  not apply. Run once without `--changed` for the `Project baseline:` line (the project-level
  rows RES-1, RES-5, OBS-4, SEC-05, QG-13, and the repo-wide totals).

**Pre-existing is not UNMET — unless you touched it.** A gap this change neither introduced,
touched nor copied (the project has no SAST job; the DB pool has no statement timeout) goes under
`Pre-existing (not this change)`, and does not make the run INCOMPLETE. A gap in code this change
edits, or in the sibling / V1 it mirrors, is this change's — that is how a lost unique constraint
shipped.

**Verdict:** every row `MET` or `n-a` → the command may report success. Any `UNMET` or `SKIPPED`
→ the run is **INCOMPLETE**, each open row named with its next action. An honest INCOMPLETE is a
valid ending; a COMPLETE over an open row is not.

## Precedence

Mirroring governs shape — naming, layout, error type, DI, file placement. The baseline governs
what the code must guarantee. When they disagree, the baseline wins, and the disagreement is
reported in the Output, not resolved silently. A V1 that lacked a guarantee does not license V2
to lack it.

## Output line

`Standards gate: <N> fired — <M> MET · <K> n-a · <U> UNMET · <S> SKIPPED` followed by the ledger,
then `Considered, not fired: …`, `Pre-existing (not this change): …` and
`Project baseline: <standards-check.py summary line>`. A typical change fires five to fifteen rows.
