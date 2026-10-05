---
description: "i18n audit: preset of /frontend-audit --classes=i18n."
kind: command
pack: frontend
allowed-tools: [Read, Write, Grep, Glob, Bash, Task, Skill]
---

# /i18n-audit [base-branch] [--whole-repo] [--routes=<glob>]

A thin preset. The audit is `/frontend-audit` with its scope fixed to the i18n family: one class ledger, one verification protocol, one verdict, one report shape. This file keeps the name because `/do`, the docs and the frontend lane route to it. It hands the ask, verbatim, to

```text
/frontend-audit --classes=i18n <every argument the user passed>
```

through the Skill tool, and does nothing else.

## What the preset fixes

- **Family.** The i18n row of `/frontend-audit`'s class ledger: every § in `i18n-scan`'s coverage block, gated by its locale-count gate. Every other row prints `N/A (out of scope: --classes=i18n)`. The report is `ai/audits/<YYYY-MM-DD>-frontend-i18n.md`.
- **Judge.** `@i18n-auditor` (this pack) grades and ranks `i18n-scan`'s rows; the refuter is `.claude/agents/verifier.md` when installed, else a `Task` refuter. `<html lang>` as accessibility stays on the a11y rows.
- **Catalog scope.** The catalog script runs whole-repo even on a diff run: a key missing from one locale is never in the diff that added it to another.

## When to use / NOT to use
- USE: before a feature that adds copy ships; after a translator delivers a locale; before a locale is promoted; when a brief first names a second market.
- NOT: closing findings → `/frontend-fix`. One hard-coded string in a diff under review → `@ui-reviewer`. Visual RTL design → `/design-review` (ui-ux pack, when installed). Every frontend axis at once → `/frontend-audit` with no preset.

## When `/frontend-audit` is not installed

An install made before `/frontend-audit` shipped has `i18n-scan` but no orchestrator. Run the same contract directly, and never improvise the retired three-pass procedure from memory:

1. **Gate.** Run `i18n-scan` § The locale-count gate: the catalog script's `GATE:` line plus pre-flight greps 0a–0d. **OFF** → print `N/A (single-locale product, no i18n library)` for every class, write the one-line report, stop.
2. **Detect.** Run the `i18n-scan` skill through the Skill tool: its pre-flight greps (limited to changed files on a diff run), its lint lane when installed, `scripts/catalog-parity.py --used=<UI roots>` (always whole-repo), the prefix × union sweep for the top dynamic prefixes, and its 3,000-hit path.
3. **Judge.** Dispatch `@i18n-auditor` (`Task`) with the skill's rows and the scope, never the detector's reasoning. It ranks and grades them (its § Contract).
4. **Refute.** Each high candidate goes to its own verifier (`Task`; `.claude/agents/verifier.md` in mode `refute` when present) through [`refute-before-report.md`](../../../snippets/refute-before-report.md) § 1–§ 8 and § 10, with [`precedents/ui.md`](../../../snippets/precedents/ui.md) and the oracles in [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Accessibility and UI states. Medium and low share one batch verifier. Buckets: **Finding · Unconfirmed · Hardening · Pre-existing** (diff runs) **· Refuted**. Print `Verification: <n> candidates → <F> findings · <U> unconfirmed · <H> hardening · <P> pre-existing · <R> refuted`.
5. **Ledger.** The class ledger is `i18n-scan`'s coverage block, all eleven rows, each `checked (k hits → m findings)` / `N/A (<reason>)` / `blocked (<reason>)` / `Live, unreviewed (k groups / n hits)`. Emit the coverage ledger over the routes and UI files resolved ([`coverage-ledger.md`](../../../snippets/coverage-ledger.md)).
6. **Verdict.** **NO-GO**: a Finding at high (a key missing in a shipped locale, a placeholder mismatch, hard-coded copy on a translated route, server text in the wrong language). **GO-UNVERIFIED (N)**: no such Finding, but N open items — Unconfirmed highs, `blocked` rows (a pseudo-locale render with no harness counts), an unswept dynamic prefix with no fallback. **GO**: none of the above.
7. **Report.** Write `ai/audits/<YYYY-MM-DD>-i18n.md` (gate, lanes, ledger, verification line, findings by bucket, verdict) and one line in `ai/dynamic/changelog.md`. End with `## What to do next` per [`review-action-plan.md`](../../../snippets/review-action-plan.md): MUST FIX → SHOULD FIX → OPTIONAL, each with `<file:line>` or `<set> :: <key> [<locale>]`, the **Fix** and the **Verify** oracle (§ What to do next below; `/fix-bug` per finding when `/frontend-fix` is absent).

Grep the draft for hand-waves before printing it ([`hand-wave-grep.md`](../../../snippets/hand-wave-grep.md)): every row is enumerated, never `several keys` or `N+ strings`.

## What to do next — required closing section

`/frontend-audit` writes it (step 7 above when it is absent): the findings as one ordered to-do, MUST FIX → SHOULD FIX → OPTIONAL, each with the site or `<set> :: <key> [<locale>]`, the **Fix** and the **Verify** oracle (missing-key run, pseudo-locale walk, plural matrix, RTL mirror), closing with **`/frontend-fix`** on the report, then a re-run of `/i18n-audit` and `/learn-from-task`. Canonical contract: [`review-action-plan.md`](../../../snippets/review-action-plan.md).

## Never

- Machine-translate a missing value. A scaffolded key copies the base value with a `TODO: translate` marker; a translator writes the copy.
- Collapse a plural to `one`/`other` for a locale that needs more (Arabic: zero, one, two, few, many, other).
- Delete a key a grep could not find while a dynamic prefix may build it: the prefix × union sweep decides.
- Edit product code, catalogs or CI. The audit's outputs are the report, the changelog line and the status line.

## Where the old procedure went

The hard-coded, parity and dead-key passes are `i18n-scan` §1, §2 and its catalog script. The dynamic-key prefix × union sweep is `i18n-scan` § The catalog script. Interpolation and plural-category checks are the script's `placeholder` and `plural-forms` rows. The hand-wave halt is the shared snippet above.

## Related

- `/frontend-audit` — the orchestrator this preset fixes to `--classes=i18n`. `/frontend-fix` — closes the findings, failing first (missing-key, pseudo-locale and RTL oracles).
- `i18n-scan` (skill) — the detector. `@i18n-auditor` (agent) — the judge and ranker over it.
- `/a11y-audit` — the sibling preset (`--classes=a11y`). `<html lang>` as accessibility is its row; `lang`/`dir` following the locale is this one's.
- `.claude/rules/i18n.md` — how many locales the code assumes. `ai/patterns/i18n.md` — key architecture, ICU plurals, `Intl` formatting.
