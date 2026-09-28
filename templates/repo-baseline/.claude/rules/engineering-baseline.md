# Rule: the engineering baseline is proved, not remembered

> **Hard rule (TL;DR):** No feature, fix, migration or port is done until the standards gate has run on it — `.claude/templates/snippets/standards-gate.md`. Select the rows of `.claude/templates/governance/engineering-baseline/` the change fires; close each with evidence (a `file:line`, a test that ran green, a command's output) as `MET`, `n-a <reason>`, or `UNMET` → report INCOMPLETE. This holds whether or not the command you are running mentions the gate, and when no command is running at all.

## Must

- **The baseline outranks the sibling you mirror and the V1 you port.** A sibling or V1 that lacks a guarantee — a unique constraint on a natural key, a timeout, a 403 test, a loading / empty / error state — is a defect to fix in this change or to report `UNMET`, never a shape to copy.
- **Tier shrinks ceremony, never the baseline.** A trivial change fires fewer rows; it does not skip the ones it fires.

## Why

The rules that demand these guarantees were in context when a V1→V2 port shipped a users table without its unique email. Knowing a rule is not applying it; the gate asks for the evidence.
