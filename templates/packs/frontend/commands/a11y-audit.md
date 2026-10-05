---
description: "WCAG 2.2 AA audit: preset of /frontend-audit --classes=a11y."
kind: command
pack: frontend
allowed-tools: [Read, Grep, Glob, Skill]
---

# /a11y-audit [base-branch] [--whole-repo] [--routes=<glob>]

A thin preset. The audit procedure lives once, in `/frontend-audit` (this pack): the detectors, the refute step, the class ledger, the production bar, the verdict and the report. This command fixes the class family and the judge, and hands the ask, with every flag the user passed, to

```text
/frontend-audit --classes=a11y <base-branch | --whole-repo> [--routes=<glob>]
```

through the Skill tool. The name is kept because `/do`, the docs and the delivery lanes route accessibility asks here.

## What the preset fixes

- **Families.** The four a11y rows of `/frontend-audit`'s class ledger: A11y static (`a11y-code-scan` §1–§14), A11y rendered (`a11y-scan` §1–§7), A11y motion (`motion-audit`, ui-ux pack, when installed) and the A11y manual pass. Every other row prints `N/A (out of scope: --classes=a11y)`. The report is `ai/audits/<date>-frontend-a11y.md`.
- **Judge selection.** `@ux-reviewer` (ui-ux pack) when `.claude/agents/ux-reviewer.md` is installed: it is the single WCAG owner, it refutes every BLOCKER and HIGH under [`refute-before-report.md`](../../../snippets/refute-before-report.md) § 10 (the accessibility column), and its **SC-coverage block** is this run's ledger — every WCAG 2.2 A and AA success criterion `checked` / `N/A` / `blocked` / `NOT RUN (human lane)`. Without ui-ux, `@accessibility-auditor` (this pack) judges, and the ledger is the two detectors' class blocks plus its manual-lane checklist. The report header names the judge that ran.
- **Ask the user** (on top of `/frontend-audit`'s cases) when an image is decorative or informative and the code cannot say: never invent `alt` text; `alt=""` stays on decoration ([`precedents/ui.md`](../../../snippets/precedents/ui.md) § 11).

## The automation ceiling — printed in every report

A clean run is the **automated floor**, never "accessible", "WCAG compliant" or "a11y ✓". Automation finds part of the problem: 57 % of issues by volume in Deque's 2021 study, 41 % of 143 barriers for the best single tool in the GDS 2017 test (`precedents/ui.md` § 58). A clean axe run says nothing about keyboard operability, focus order, live regions or state changes; a Lighthouse 100 is not axe (§ 51). A GO prints `GO — automated floor; manual pass <recorded at <path> | not recorded>`.

## When the target is missing

- `/frontend-audit` not installed (an install older than this preset): stop and print `Missing: /frontend-audit — run /setup-project --refresh.` Do not improvise the old single-agent audit.
- A native mobile tree only: the a11y rows print `N/A (native UI — not a DOM)`; route the ask to the mobile pack's a11y detector when installed.

## What to do next — required closing section

`/frontend-audit` writes it: the findings as one ordered to-do (MUST FIX → SHOULD FIX → OPTIONAL), each with `<file:line>`, the route-state, the WCAG SC, the **Fix** and the **Verify** oracle, closing with **`/frontend-fix`** on the report, then a re-run of `/a11y-audit` and `/learn-from-task`. The visual rows (contrast, focus ring, tap target, affordance) go to `/polish` or `/enhance-ui` (ui-ux, when installed). Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Related

- `/frontend-audit` (this pack) — the procedure. `/frontend-fix` (this pack) — closes the findings, accepting an a11y fix only when the violation count at the cell strictly drops.
- `a11y-code-scan`, `a11y-scan` (this pack) — the static and rendered detectors. `a11y-quick-check` (ui-ux, when installed) — the 60-second lane on a diff.
- `@ux-reviewer` (ui-ux, when installed) — the WCAG judge; `@accessibility-auditor` (this pack) — the judge without ui-ux.
- `/i18n-audit` (this pack) — locale parity and hard-coded copy; it becomes the `i18n` preset of `/frontend-audit`.
- [`precedents/ui.md`](../../../snippets/precedents/ui.md) · [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Accessibility and UI states.
