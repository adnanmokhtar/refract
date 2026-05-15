---
description: Auto-fixes the mechanical UI findings from /ui-crawl by applying the closure-verb vocabulary from align-discipline.md. Patches at the WRAPPER level (FormField, CrudActions, TableActions, BaseModal) so one fix cascades through hundreds of call sites. Closes color-contrast (token swap), button-name (aria-label injection), label (for/id wiring), v-html-without-sanitize, raw-library-component, hardcoded-translations. Skips bugs requiring human judgment (broken dialog triggers, layout overflow, page load failures). Re-runs /ui-crawl in verify mode to confirm gap-count parity. Frontend stacks only.
kind: command
pack: ui-ux
---

# /ui-crawl-fix [<class>] [--dry-run] [--safe-only] [--verify]

## The Premise

**The /ui-crawl report is mostly the same 5 issues, repeated 1,000 times.** A typical report shows:
- 700+ `color-contrast` violations → usually 2-3 design tokens at fault
- 300+ `button-name` violations → usually 1-2 shared wrappers missing `aria-label`
- 300+ `label` violations → usually 1 wrapper not wiring `for`/`id`

**Fixing at the call site = 1,000 commits. Fixing at the wrapper = 5 commits.** This command picks the wrapper path. Every fix obeys `align-discipline.md`: one finding-class per commit, closure verb from the vocabulary, behaviour preserved, security/perf gets assertions, re-detect on completion.

Bugs that need human judgment (broken dialog triggers, page won't load, network 5xx) are NOT auto-fixed. They're surfaced for triage.

## When to use

- Right after `/ui-crawl` produces a fresh report.
- After a design-token change to mass-fix downstream contrast regressions.
- Pre-release, when the crawl report has hundreds of mechanical findings.

## When NOT to use

- Without a fresh `/ui-crawl` report (input is missing).
- For behavioral bugs (broken triggers, page errors) — those need human eyes.
- For visual polish — use `/enhance-ui`.
- For new abstractions — this command never invents wrappers; if `_extracted-idioms.md` doesn't name the gold-standard helper, halt and route to `/setup-project --refine`.

## Auto-fixable classes (safe-list)

| axe rule / pattern | Closure verb | Fix shape | Risk |
|---|---|---|---|
| `color-contrast` (token-rooted) | `replace-with-shared` | Swap design token to AA-compliant variant in `_variables.scss` | Low (cascades; visual diff verifies) |
| `button-name` on icon-only buttons inside shared wrappers (`<CrudActions>`, `<TableActions>`, `<RowActionMenu>`) | `add-validator` | Wrapper injects `aria-label` from i18n key per icon | Low |
| `label` missing `for`/`id` linkage in `<FormField>` | `replace-with-shared` | Auto-wire `for={slot.attrs.id}` to inner input | Low |
| Raw `<Dialog>` / `<Dropdown>` / `<MultiSelect>` in pages | `replace-with-shared` | Swap to `<BaseModal>` / `<BaseDropdown>` / `<BaseMultiSelect>` | Medium (call sites; visual diff verifies) |
| `<v-html>` / `dangerouslySetInnerHTML` without sanitize wrapper | `add-validator` (security) | Wrap value with project's sanitize helper from `_extracted-idioms.md` | Low (security row; gets a test assertion) |
| Hardcoded `{ en: '', ar: '' }` translation refs | `replace-with-shared` | Replace with `useLanguages().buildEmptyTranslations()` (or stack equivalent) | Low |
| `<a target="_blank">` missing `rel="noopener noreferrer"` | `add-validator` | Inject `rel` (security) | Low |
| Empty `catch { }` swallow | `replace-with-shared` | Route through project's error handler | Medium (read each catch; some are intentional) |

## NOT auto-fixed (surfaced for human triage)

| Finding | Why human-only |
|---|---|
| Dialog button clicked but no dialog opened | Could be permission gate, missing handler, broken composable, API 404 |
| Horizontal overflow at 375px | Needs layout judgment (hidden vs reflowed vs hidden-on-mobile) |
| Page didn't load OR uncaught JS error | Likely backend, routing, or composable bug |
| Heading hierarchy skip (h1 → h3) | Restructuring content needs human eyes |
| Network 5xx | API or auth issue; not a UI fix |
| `aria-required-parent` / `aria-required-children` mismatches | Structural component shape change; review case-by-case |
| Color values NOT rooted in tokens | Either tokenize first (route to `/align-recheck`) or human edits the raw color |

## Phases

### Phase 0 — Pre-flight
- Verify `ai/audits/ui-crawl-findings.json` exists and is < 24h old (else suggest `/ui-crawl` first).
- Verify `_extracted-idioms.md` populated (else halt; route to `/setup-project --refine`).
- Read `align-discipline.md`'s closure-verb vocabulary.

### Phase 1 — Triage
- Parse findings JSON.
- Group violations by class.
- Compute the proposed wrapper-level fixes (which shared file to patch + count of cascading call sites).
- Surface estimate: "Patching `<FormField>` will close 338 label violations across 38 routes."
- Ask user to confirm before any edit (unless `--dry-run` skips, or `--safe-only` auto-confirms whitelist classes).

### Phase 2 — Fix
For each approved class:
1. Open the canonical wrapper file (named in `_extracted-idioms.md`).
2. Apply the closure-verb edit:
   - Read the file in full.
   - Identify the minimal change that closes the class for ALL its call sites.
   - Apply (typed-only, no `any`).
3. Run typecheck + lint on touched files.
4. Run scoped Vitest suite for the wrapper (if exists).
5. Commit with conventional message: `fix(<class>): <verb> <wrapper> — closes <N> findings across <M> routes`.

### Phase 3 — Verify (`--verify` or end-of-fix auto)
- Re-run `/ui-crawl --filter=<affected-modules>` (only the modules where findings were closed).
- Diff old vs new findings JSON: every targeted finding must be gone.
- If any finding remains: halt the row, write `ai/align/halts/<finding-id>.md`, surface to user.
- If new findings appear: a fix regressed something — halt, revert the commit, surface.

### Phase 4 — Report
- Append summary to `ai/audits/ui-crawl-fix-log.md`:
  - Findings closed (per class)
  - Commits authored
  - Routes affected
  - Findings remaining (skipped for human triage)
  - Verification result

## Flags

- `<class>` — Optional. Fix only this class. Examples: `contrast`, `button-name`, `label`, `v-html`, `translations`, `raw-component`.
- `--dry-run` — Show what WOULD be edited (per file + diff preview). No changes written.
- `--safe-only` — Skip the user-confirm step for whitelist classes (`contrast`, `button-name`, `label`, `noopener`). Useful for CI.
- `--verify` — After fixing, automatically re-crawl affected modules to confirm closure.
- `--no-commit` — Apply edits but skip git commit (user reviews + commits manually).
- `--module=<name>` — Only fix findings in this module. Useful for incremental rollout.

## Examples

```
/ui-crawl-fix                        # interactive: triage + fix all safe classes
/ui-crawl-fix contrast               # only fix color-contrast violations
/ui-crawl-fix button-name --verify   # fix button-name then re-crawl to confirm
/ui-crawl-fix --dry-run              # show all proposed edits, no writes
/ui-crawl-fix --safe-only --verify   # CI mode: auto-apply whitelist + verify
/ui-crawl-fix --module=inventory     # only inventory module findings
```

## Hard rules (inherited from align-discipline.md)

- **One finding-class = one commit.** Mixing classes in one commit hides which fix caused which delta.
- **No new abstractions.** If the fix needs a new wrapper, halt; route to `/setup-project --refine` to add the wrapper to idioms first.
- **Behaviour preservation for structural classes.** Re-run scoped tests; coverage must not drop (tolerance 0.5%).
- **Security findings ship with assertions.** Any `add-validator` (sanitize wrap, noopener add) co-commits a test.
- **No fix without `<path:line>` evidence.** Every commit's body cites the findings closed (with route + violation count).
- **Re-detect mandatory.** Phase 3 verification re-runs `/ui-crawl` on affected modules; gap-count parity (closed == in-count) is the gate.
- **Halt on regression.** If verification shows new findings, revert the commit and surface — no auto-progress past a regression.

## Output (terminal summary)

```
[fix] reading ai/audits/ui-crawl-findings.json (146 routes, 1463 violations)
[fix] triage:
  - color-contrast: 778 nodes / 79 routes → patch src/assets/scss/_variables.scss ($gray-500 → AA-compliant)
  - button-name: 347 nodes / 22 routes → patch src/shared/components/table/CrudActions.vue + TableActions.vue
  - label: 338 nodes / 38 routes → patch src/shared/components/form/FormField.vue
  - (skipped) 7 broken dialog triggers → human triage; surfaced in ai/audits/ui-crawl-fix-log.md
[fix] confirm? [y/N] y
[fix] patching FormField.vue ... typecheck pass ... committed (a3f9c2e)
[fix] patching CrudActions.vue + TableActions.vue ... committed (b8e1d44)
[fix] patching _variables.scss ... committed (c2a5e90)
[verify] re-crawling 38 affected modules (~12m)
[verify] label: 338 → 0 ✓
[verify] button-name: 347 → 0 ✓
[verify] color-contrast: 778 → 12 (12 remaining: hardcoded colors outside tokens; surfaced for human)
[fix] complete. 3 commits. 1451 of 1463 violations closed (99.2%).
```

## Cross-references

- `/ui-crawl` — the detector this command consumes.
- `.claude/rules/align-discipline.md` — closure-verb vocabulary, tier rules, validator script.
- `/align-recheck` / `/align-fast` — sibling commands for structural-only fixes; this is the UI-specific variant that consumes a `/ui-crawl` report instead of an `/align-scan` report.
- `_extracted-idioms.md` — the source of truth for which wrappers exist; this command never invents.
- `/enhance-ui` — visual polish on one surface (different scope).
- `/ui-sweep` — deeper specialist sweep with HTML report + visual baselines; orthogonal to this fix loop.
- `/polish` — the simple-surface entry; for `frontend-*` it dispatches the same 18-verb closure vocabulary `ui-crawl-fix` patches at the wrapper level.

## Stack scope

Frontend stacks only (`PROJECT_KIND in {frontend-*, mobile-web}`). Halts on backend / data / library / CLI projects. Wrapper paths shown in this file are the Vue 3 + Vite + Pinia shape; substitute for React / Next / Svelte / Solid / Angular per the project's `_extracted-idioms.md`.
