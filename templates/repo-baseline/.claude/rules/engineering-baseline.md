# Rule: the engineering baseline is proved, not remembered

> **Hard rule (TL;DR):** No feature, fix, migration or port is done until the standards gate has run on it — `.claude/templates/snippets/standards-gate.md`. Select the rows of `.claude/templates/governance/engineering-baseline/` the change fires; close each with evidence (a `file:line`, a test that ran green, a command's output) as `MET`, `n-a <reason>`, or `UNMET` → report INCOMPLETE. This holds whether or not the command you are running mentions the gate, and when no command is running at all.

## Precedence — when two rules disagree (full order and conflict log: `.claude/templates/governance/precedence.md`)

1. Hooks and settings (mechanical) outrank all prose.
2. A baseline row is a **floor**: tighten it, never loosen it. It outranks the sibling you mirror and the V1 you port — a missing guarantee is fixed in this change or `UNMET`, never copied; mirroring governs only what the baseline is silent on.
3. Regulatory overlay: stricter wins. 4. Domain rule, inside its domain. 5. Stack pack rule. 6. Generic pack rule.
7. Project conventions and siblings: shape only. 8. Template docs and examples.
- Ties: stricter wins on security and data integrity, the more specific rule otherwise. Numbers live in `.claude/templates/governance/thresholds.json` — cite the `THR-…` id, never restate it.
- An unresolved conflict is reported to the user, never picked silently. **Tier shrinks ceremony, never the baseline:** a trivial change fires fewer rows; it does not skip the ones it fires.
