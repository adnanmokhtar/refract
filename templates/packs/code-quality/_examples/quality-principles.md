---
name: quality-principles
kind: example
pack: code-quality
extends: repo-baseline/.claude/rules/code-quality.md
---

# Code Quality — concrete pack rules

> **Hard rule.** Functions MUST be within the project's configured length cap (30 lines where none is configured), MUST have one reason to change, and MUST use named domain exception types. Dead code, commented-out code, `console.log` / `print` debug statements, untyped `any` casts at boundaries, and undated/unowned `TODO`s are forbidden — they fail review and the linter.

Prevents the slow death: dead code, copy-paste rot, comment lies, and "TODO" graveyards.

> Reads the baseline `code-quality.md` first (Hard Rule A19). This file adds concrete, enforceable rules on top — it is a *layer*, not the whole rule.
>
> Deliberately NOT here: pagination and index coverage (`database-principles.md` / `backend-principles.md`) and parameterized queries (`security-principles.md`, which carries the sort-column carve-out a flat rule misses).

## Must

- One reason for a function / class / file to change. If you say "and" describing it ("validates AND saves AND notifies"), split it.
- Functions ≤ the project's **configured** max-length — read the linter config and let its number win, because a cap the linter doesn't share is one review re-litigates every PR. No cap configured → **30** lines (signature + body, excluding blank lines and closing braces), and configure it. Over the cap, split: extract a helper, hoist a guard clause, or rethink the responsibility. The cap is a forcing function for the single-responsibility rule above; bypassing it requires an explicit comment naming the reason (rare — a state-machine algorithm, generated code).
- Names are descriptive: `unsettledOrders`, not `data` / `result` / `tmp`. Variable scope determines verbosity — loop counter `i` is fine; module-level `i` is not.
- Custom exception types per domain concept: `OrderNotFoundException`, `PaymentDeclinedException`. Never `throw new Error('not found')` — callers can't handle it specifically.
- Validate inputs at the boundary: HTTP / webhook / queue / CLI. Inside the system, types are the contract; don't re-validate.
- Imports tidy: dead imports removed. No commented-out import blocks.
- Identify inputs, outputs, and dependencies before modifying any logic. If you can't trace them in ~2 minutes (signature, callers via grep, downstream effects), you don't know enough yet — read more, or ask before editing. "I'll figure it out as I go" is how silent regressions ship.

## Must not

- `any` / `unknown` casts at boundaries without explicit narrowing. `as any` in TypeScript is a code smell or a CVE.
- `console.log` / `print` / `fmt.Println` debugging in committed code. Use the project logger with structured fields.
- Commented-out code. `git` remembers; commits don't need a tomb.
- Comments paraphrasing the next line: `// increment counter` above `counter++`. Delete it.
- Reference the PR / ticket / reviewer in committed prose ("This was added for PR-1234"). `git blame` is the source.
- `TODO` without owner + delete-by date: `TODO(@alice 2026-06-01): retry on 503`.
- Speculative generality: a backwards-compat shim for code that has not shipped, or an abstraction for a use that does not exist yet ("we MIGHT need this for X"). The extract trigger is the rule of three below — the third real occurrence, never an imagined one.
- `--no-verify` / hook-bypass on commits without explicit authorization. Hooks fail for reasons.

## Should

- Extract a helper / type / class once the SAME shape appears 3 times. Two is coincidence; three is a pattern — extract on the third occurrence, not the second (premature) and not the fifth (rot).
- Pure functions for business logic; side-effects pushed to the edge (services / adapters).
- Default to no comments. Add one only when the WHY is non-obvious — a hidden constraint, a known workaround, a subtle invariant.
- Boy Scout Rule, bounded: when you touch a file, fix the dead imports / commented-out blocks / vague names in the same change rather than filing a cleanup ticket that never lands — but clean what is *adjacent* to your change, not the whole file, or the diff balloons and hides the real edit.
- Track technical debt as a persisted, ranked ledger — dated/owned `TODO`s, unjustified suppressions, deprecated-API call sites, major-version-lag deps — each with a blast-radius + fix-cost, diffed run-over-run so accrual is visible instead of rediscovered every audit. Distinct from dead-code (unreachable → delete), `@dependency-auditor` (dep vulns/licenses) and `check-health` (point-in-time). See `debt-ledger` (skill).

## Enforcement

- Linter + formatter + strict type-check gate CI. A suppression needs a comment justifying it, or it fails review.
- A dead-export detector and a copy-paste detector run in CI. **Set the duplication gate from your own baseline, not a published number** — measure, gate just under it, ratchet down. A borrowed threshold either fires on everything and gets muted, or fires on nothing.
- Pre-commit hook runs lint + format on staged files; `/pre-commit` and `/check-health` own that wiring.
- Anything a tool can check is checked by the tool, so review attention goes to design (`@code-reviewer` § Diagnose).
