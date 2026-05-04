---
purpose: Canonical format for the "Actionable next steps" section every report-producing command emits. Turns deferred / unfixed findings into paste-ready follow-up commands so users skip the manual translation step. Used by /optimize, /polish, /align, /migrate, /refactor, and every /*-audit command.
---

# Actionable next steps — report contract

Every command that writes a final report (`ai/<command>/final-report.md`) MUST end the report with a section titled **`## Actionable next steps`** that lists every deferred / unfixed / out-of-scope finding as a paste-ready follow-up command. No orphan deferrals.

The validator (`check_actionable_next_steps` in each command's `validate-*-artifacts.sh`) halts the gate when:

- The section header is missing.
- A deferral exists in the report (`Deferred`, `God file`, `Out of scope`, `Recommendation`, `TODO`) without a corresponding actionable line.
- A command line in the section omits a concrete `<path>` or `--scope=<path>` (i.e., hand-wave like `/refactor god files` instead of `/refactor src/.../OrdersListPage.vue`).

## Required shape

```markdown
## Actionable next steps

> Run these commands directly. Each block is one paste-ready instruction with the exact path / args. Sorted by leverage (highest impact first).

```bash
# <one-line description: WHAT is broken + WHY it matters + scope (count or path)>
/<exact-command> <exact-args> [--scope=<path>] [--focus=<verb>]

# <next item>
/<command> ...
```
```

## The 3 rules every line follows

1. **Comment line first.** One sentence: WHAT (the finding class) + WHY (impact / risk / count) + scope (file count, LOC, module). Plain English, no terminology the user has to look up.
2. **Exact command second.** Fully-qualified: real path (not "the orders module"), real flags from the command's flag set, real `--focus=<verb>` from the closed verb vocabulary if applicable.
3. **Sorted by leverage.** Largest-impact + lowest-risk first. A 47-site `/polish` batch ranks above a single-file `/refactor`. CI / ADR / docs tasks rank last (one-shot, low-risk).

## Required per-command flag mapping

When a finding maps to a closed verb vocabulary, the actionable line MUST include `--focus=<verb>` so the receiving command runs the right closure verb instead of re-detecting blindly.

| Producing command | Verb vocabulary cited | Common receivers |
|---|---|---|
| `/optimize` | `architectural-diagnosis` (foundations) + `refactoring-sweep` (10 verbs) | `/refactor` (with `--focus=extract-method` etc.), `/polish` (for visual deferrals) |
| `/polish` (frontend) | `ui-design-sweep` (18 verbs: `consolidate-tokens`, `extract-token`, `unify-component`, `extract-pattern`, `normalize-hierarchy`, `apply-type-scale`, `tighten-rhythm`, `simplify-density`, `wire-empty-state`, `wire-loading-state`, `wire-error-state`, `lift-contrast`, `align-focus-ring`, `unify-iconography`, `normalize-motion`, `expand-tap-target`, `unify-cta-placement`, `clarify-affordance`, `normalize-surface`) | `/enhance-ui`, `/refactor` |
| `/polish` (backend) | `api-consistency-audit` (15 detectors → `unify-envelope`, `unify-error-contract`, `unify-naming`, `unify-pagination`, …) | `/add-endpoint`, `/refactor` |
| `/polish` (data) | `schema-consistency-audit` | `/add-migration` |
| `/align` | per-axis closure verbs from `align-discipline.md` | `/refactor`, `/polish` |
| `/migrate` | per-feature ledger transitions | `/find-and-fix`, `/port-feature` |
| `/refactor` | `refactoring-sweep` 10 verbs | (terminal — refactor closes its own findings) |
| `/security-audit` / `/perf-audit` / `/a11y-audit` / `/i18n-audit` / `/db-audit` | per-audit class | `/fix-bug`, `/add-test`, `/add-ci` |

## Worked example (real `/optimize` report)

```markdown
## Actionable next steps

> Run these commands directly. Each block is one paste-ready instruction with the exact path / args. Sorted by leverage (highest impact first).

```bash
# 275 inline styles across 70+ files → consolidate to design tokens (largest deferred class, mechanical fix)
/polish

# God file: OrdersListPage.vue 1438 LOC → extract form logic to composable, then split sections
/refactor src/modules/orders/pages/OrdersListPage.vue --focus=extract-method,extract-class

# God file: OperationsPage.vue 1276 LOC → extract sections to child components
/refactor src/modules/operations/pages/OperationsPage.vue --focus=extract-method,extract-class

# God file: ReportsPage.vue 948 LOC → extract filter logic
/refactor src/modules/reports/pages/ReportsPage.vue --focus=extract-method

# God file: ProductsPage.vue 919 LOC → extract table logic
/refactor src/modules/inventory/pages/ProductsPage.vue --focus=extract-method,extract-class

# God file: PurchaseSettingsPanel.vue 889 LOC → extract sub-panels
/refactor src/modules/inventory/components/product-edit/advanced/PurchaseSettingsPanel.vue --focus=extract-method

# Parity tests for new service methods (S2sPanel: getS2sConfigs, saveS2sConfigs)
/add-test src/modules/store-management/services/index.ts

# Document crossModuleServices pattern as Architecture Decision Record
/add-adr crossModuleServices

# CI guard: ban inline style attributes via ESLint rule
/add-ci eslint-no-inline-style

# CI guard: enforce LOC budget (warn at 500, fail at 1000)
/add-ci loc-budget
```
```

## Anti-patterns (what NOT to write)

- ❌ `# God files deferred to dedicated refactoring phase.` — no command, no scope, dead-end.
- ❌ `/refactor the god files` — hand-wave, no path. Validator halts.
- ❌ `# Consider running /polish next` — speculative; either route or don't, no "consider".
- ❌ `# Inline styles → /polish` — too terse; user can't gauge impact / scope.
- ❌ Bullet list outside a `bash` fence — not paste-ready.

## Commands that use this block SHOULD link here, not paste verbatim

```markdown
## Actionable next steps

See `~/.claude/templates/snippets/actionable-next-steps.md` for the contract. Each row in this section follows the 3-rule format (comment + command + sorted by leverage).

```bash
# (paste-ready commands here)
```
```
