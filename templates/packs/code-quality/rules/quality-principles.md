---
paths:
  - "**/*.{ts,tsx,mts,cts,js,jsx,mjs,cjs,vue,svelte,astro}"
  - "**/*.{py,pyi,rb,php,go,rs,java,kt,kts,scala,groovy,cs,fs,vb,swift,m,mm,dart}"
  - "**/*.{ex,exs,erl,hrl,clj,cljs,cljc,hs,ml,elm,lua,pl,pm,r,R,jl,zig,nim,cr,c,h,cc,cpp,cxx,hpp}"
  - "**/*.{yml,yaml,json,jsonc,json5,toml,ini,cfg,conf,properties,xml,env,plist,gradle}"
  - "**/{Makefile,Justfile,Taskfile}*"
paths-origin: pack-default-debd489e
name: quality-principles
description: Code-quality pack — concrete MUST rules (function size cap, single responsibility, named domain exceptions, comment + TODO discipline). Layered ON TOP of repo-baseline/.claude/rules/code-quality.md (A19).
kind: rule
pack: code-quality
severity: must
applies-to: code-quality-track, every-code-writing-task-in-code-quality
extends: repo-baseline/.claude/rules/code-quality.md
---

# Code Quality — concrete pack rules

> **Hard rule.** Functions MUST be within the project's configured length cap (`THR-FN-LEN`: the linter's value), MUST have one reason to change, and MUST use named domain exception types. Dead code, commented-out code, `console.log` / `print` debug statements, unvalidated `any` casts at boundaries, swallowed errors, and undated/unowned `TODO`s are forbidden — they fail review and the linter.

Prevents the slow death: dead code, copy-paste rot, comment lies, hidden failures, and "TODO" graveyards.

> Reads the baseline `code-quality.md` first (Hard Rule A19). This pack file adds concrete, enforceable rules on top. Where two rules disagree, `templates/governance/precedence.md` decides (A1, A5, A28, A30 are settled there and below).
>
> Deliberately NOT here: pagination and index coverage (`database-principles.md` / `backend-principles.md`) and parameterized queries (`security-principles.md`, which carries the sort-column carve-out a flat rule misses). This file used to restate all three, worse.

## Must

- One reason for a function / class / file to change. If you say "and" describing it ("validates AND saves AND notifies"), split it.
- Functions within the project's **configured** max-length (`THR-FN-LEN`, precedence A5): read the linter config and let its number win, because a cap the linter doesn't share is one review re-litigates every PR. No cap configured → the length rule is advisory, never a hard fail: configure one. Over the cap, split: extract a helper, hoist a guard clause, or rethink the responsibility. A length or complexity score is a triage cut-off (default — project config wins), never a finding by itself: a function becomes one only with impact evidence — churn and fix history on its own lines (`architectural-diagnosis` § 9), a branch no test covers, a defect it hides (`precedents/code-quality.md` § 51).
- Names are descriptive: `unsettledOrders`, not `data` / `result` / `tmp`. Variable scope determines verbosity — loop counter `i` is fine; module-level `i` is not.
- Custom exception types per domain concept: `OrderNotFoundException`, `PaymentDeclinedException`. Never `throw new Error('not found')` — callers can't handle it specifically. A rethrow keeps the cause (`error-handling-scan` § 6).
- Every failure has one declared outcome — propagate, retry with a bound, compensate, or degrade visibly (`concerns/error-handling.md`, C4). A caught error that is dropped, logged and then reported as success, or turned into an empty result is a defect, not a style choice (`error-handling-scan` § 1–§ 2).
- Validate inputs at every trust boundary — HTTP, webhook, queue, CLI, a storage read, and any service boundary data crosses from another trust domain (precedence A30: security wins at trust boundaries). Inside one trust domain, types are the contract.
- Imports tidy: dead imports removed. No commented-out import blocks.
- Identify inputs, outputs, and dependencies before modifying any logic. If you can't trace them quickly (read the function signature, callers via grep, downstream effects), you don't know enough yet — read more, or ask before editing. The "I'll figure it out as I go" pattern is how silent regressions ship.

## Must not

- `any` / `unknown` casts, `as T` or non-null assertions on a value from outside the program without a runtime validator first. `as any` in TypeScript is a code smell or a CVE. Executor: `type-safety-scan` § 1–§ 2 (malformed-input proof); security owns the mass-assignment and authorization impact.
- `console.log` / `print` / `fmt.Println` debugging in committed code. Use the project logger with structured fields. A `breakpoint()` / `pdb` / `binding.pry` / `dd()` left in shipped code is `correctness-smell-scan` § 7.
- Commented-out code. `git` remembers; commits don't need a tomb (`dead-code-scan` § 5).
- Comments paraphrasing the next line: `// increment counter` above `counter++`. Delete it.
- Reference the PR / ticket / reviewer in committed prose ("This was added for PR-1234"). `git blame` is the source.
- `TODO` without owner + delete-by date (`THR-TODO`): `TODO(@alice 2026-06-01): retry on 503`.
- A suppression (`eslint-disable` / `# noqa` / `@ts-ignore` / `//nolint`) without the rule id and a reason that says why it is safe. Executor: `suppression-scan` § 1–§ 3, which proves with an unsuppressed re-run whether the directive hides a live diagnostic; `debt-ledger` tracks the justified ones run over run.
- Speculative generality: a backwards-compat shim for code that has not shipped, or an abstraction for a use that does not exist yet ("we MIGHT need this for X"). The extract trigger is `THR-DRY` below — a real occurrence, never an imagined one.
- `--no-verify` / hook-bypass on commits without explicit authorization. Hooks fail for reasons.

## Should

- Reuse before you copy, extract on the rule of three (`THR-DRY`, precedence A28): when an implementation already exists, the second occurrence reuses it; a NEW shared helper / type / class waits for the third real occurrence — not the second (premature) and not the fifth (rot). A fix applied to one copy of duplicated logic is applied to every copy in the same change (`duplication-scan` § 1).
- Pure functions for business logic; side-effects pushed to the edge (services / adapters). Easier to test, easier to reason about.
- Default to no comments. Add one only when the WHY is non-obvious — a hidden constraint, a known workaround, a subtle invariant.
- Boy Scout Rule applies only to lines this change already touches (precedence A1: surgical wins). On those lines, fix the dead imports / commented-out blocks / vague names / redundant comments in the same change; everything else stays out of the diff — the reviewer can then see the real edit, and the rest is a separate change.
- Track technical debt as a persisted, ranked ledger — dated/owned `TODO`s, unjustified suppressions, deprecated-API call sites, major-version-lag deps — each with a blast-radius + fix-cost, diffed run-over-run so accrual (new debt vs paid-down) is visible instead of rediscovered every audit. This is *longitudinal accrual*: distinct from `dead-code-scan` (unreachable → delete), `@dependency-auditor` (dep vulns/licenses), and `check-health` (point-in-time snapshot). See `debt-ledger` (skill), which consumes `suppression-scan`'s inventory.

## Enforcement

- Linter + formatter + strict type-check gate CI, at error, with a zero-warning gate — a warn-level rule ships. `suppression-scan` § 3 reports a correctness rule off, at warn or scoped away; `type-safety-scan` § 3 reports checker strictness switched off.
- The executors per class (code-quality pack): swallowed and unobserved errors → `error-handling-scan`; boundary casts → `type-safety-scan`; logic, number and time traps → `correctness-smell-scan`; suppressions → `suppression-scan`; dead code → `dead-code-scan`; divergent copies → `duplication-scan`; complexity and coupling → `architectural-diagnosis` § 9. `/quality-audit` runs them all and prints the class ledger; `/review-changes` and `/pre-commit` run them by signal on a diff.
- A dead-export detector and a copy-paste detector run in CI. **Set the duplication gate from your own baseline, not a published number** — measure, gate just under it, ratchet down. A borrowed threshold either fires on everything and gets muted, or fires on nothing.
- Pre-commit hook runs lint + format on staged files; `/pre-commit` and `/check-health` own that wiring.
- Anything a tool can check is checked by the tool, so review attention goes to design (`@code-reviewer` § Diagnose).
