---
artifact: engineering-baseline
purpose: The minimum every change must meet, per stack, whatever the surrounding code or V1 does. Indexed by ID so a build command can ask for evidence per standard instead of trusting the model to remember prose.
---

# Engineering baseline

The rules in `templates/packs/*/rules/` say how to write good code. This directory says **which of
those a given change must prove it met**. It restates no rule: each row is one line, points at the
rule or pattern that owns the prose, and names what counts as evidence.

It exists because prose in context was not enough. A ported user table lost its unique email
constraint while the rule demanding it was loaded; the command that ran never asked. (Refract's
`docs/plans/2026-09-28-engineering-baseline-audit.md` has the full account.)

## Files — which apply

| File | Applies to |
|---|---|
| `architecture.md` | every change, every stack |
| `quality-gates.md` | every change, every stack |
| `backend-api.md` | `PROJECT_KIND` `backend-*`, and the server half of `mixed` |
| `data.md` | any change that touches a schema, entity, migration, query or repository — any stack |
| `web.md` | `frontend-*`, and the browser half of `mixed` |
| `mobile.md` | `mobile-*` (its UI rows point back into `web.md` where the rule is shared) |

A command reads the files that apply, then keeps only the rows whose **Fires when** matches the
change. Most changes fire five to fifteen rows. Rows marked *project-level* are properties of the
repo, not of a diff: `standards-check.py` and `/setup-project-health` report them, and a change's
ledger carries them as one line.

## Row format

`| ID | Standard | Fires when the change… | MET means | Checked by | Source |`

- **Standard** — the MUST, one line. The source owns the detail.
- **Fires when** — a property of the diff or plan, never of the tier. The tier sets ceremony; it
  never switches a standard off.
- **MET means** — the evidence: a `file:line`, a named test that ran green, or a command's output.
  A claim is not evidence.
- **Checked by** — `gate` (the ledger in [`snippets/standards-gate.md`](../../snippets/standards-gate.md)), `hook:<name>`
  (blocks at edit or stop time), `ci`, `standards-check.py` (the deterministic detector —
  `python3 ~/.claude/scripts/standards-check.py <repo>`; its OPEN rows are UNMET until fixed or
  allow-listed in `.claude/standards-check.allow`), or the agent / command that owns the review.
- **Source** — the rule or pattern that owns the prose, relative to Refract's `templates/`
  (`~/.claude/templates/` once synced). In a project, a pack rule is installed at
  `.claude/rules/<file>` and a pattern at `ai/patterns/<file>` — read whichever exists.

## Verdicts

The vocabulary of the production-readiness gate in `packs/backend/commands/add-endpoint.md`,
reused so there is one: `MET <evidence>` · `n-a <reason>` · `UNMET` · `SKIPPED — unverified:
<command to run>`. Any `UNMET` or `SKIPPED` makes the run **INCOMPLETE**, never a silent COMPLETE.

## Precedence

**The baseline outranks the sibling and outranks V1.** A sibling that lacks a unique constraint, a
timeout or a denial test is a defect to report and fix in this change — or to record as `UNMET`
with a follow-up — never a shape to copy. A V1 that lacked one does not license V2 to lack it.
Mirroring still governs everything the baseline is silent on: naming, layout, error type, DI.

## Waivers

A row that genuinely does not apply is `n-a <reason>` in the ledger. A project that deliberately
departs from a row records an ADR in its decisions directory (`ai/decisions/`, `docs/decisions/`,
wherever the project keeps them) citing the ID; the ledger row then reads `n-a — ADR-NNNN`. An
undocumented departure is `UNMET`.

## IDs

Existing families are reused where the backend pack already defined them (`SEC-01..03`,
`API-1..8`, `PERF-2..6`, `OBS-1..4`, `RES-1..2`). New families: `DATA`, `ARCH`, `WEB`, `MOB`, `QG`,
and `RES-3` onward. IDs are append-only: never renumber, never reuse a retired one.
