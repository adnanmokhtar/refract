---
description: Auto-fixes the mechanical UI findings from /ui-crawl by applying the closure-verb vocabulary from align-discipline.md. Patches at the WRAPPER level (the project's own form-field / row-action / modal wrappers, named in _extracted-idioms.md) so one fix cascades through hundreds of call sites. Closes color-contrast (token swap), button-name (aria-label injection), label (for/id wiring), unsanitized-raw-HTML (v-html / dangerouslySetInnerHTML / equivalent), raw-library-component, hardcoded-translations. Skips bugs requiring human judgment (broken dialog triggers, layout overflow, page load failures). Re-runs /ui-crawl in verify mode to confirm gap-count parity. Frontend stacks only.
kind: command
pack: ui-ux
---

# /ui-crawl-fix [<class>] [--dry-run] [--plan] [--safe-only] [--verify]

> **Not this command? (ANTI-triggers)** — no crawl report yet → **`/ui-crawl`** first (this command's only input is its JSON). "the page looks bad" rather than "N routes fail one mechanical rule" → **`/enhance-ui`** (one surface) · **`/redesign`** (the layout) · **`/art-direct`** (the language). Structural drift with no crawl involved → **`/align-recheck`**. Measured project-wide quality with an HTML report → **`/ui-sweep`**. A behavioural bug (broken trigger, 5xx, page won't load) → human triage; this command never touches those. Full map: [`ui-sweep.md § The ui-ux command map`](ui-sweep.md).

## The Premise

**The /ui-crawl report is mostly the same 5 issues, repeated 1,000 times.** A typical report shows:
- 700+ `color-contrast` violations → usually 2-3 design tokens at fault
- 300+ `button-name` violations → usually 1-2 shared wrappers missing `aria-label`
- 300+ `label` violations → usually 1 wrapper not wiring `for`/`id`

**Fixing at the call site = 1,000 commits. Fixing at the wrapper = 5 commits.** This command picks the wrapper path. Every fix obeys `align-discipline.md` (align pack): one finding-class per commit, closure verb from its 21-verb closure vocabulary (structural `replace-with-shared` + functional `add-validator` etc.), behaviour preserved, security/perf gets assertions, re-detect on completion.

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
**Every wrapper name and helper name below is a ROLE, not a path.** The concrete file for each role comes from `_extracted-idioms.md § Wrappers`; the names in this table are illustrative placeholders for "whatever this project calls its form-field wrapper / row-action wrapper / sanitize helper". If a role has no named owner in idioms, that row halts and routes to `/setup-project --refine` — it is never invented here.

| axe rule / pattern | Closure verb | Fix shape | Risk |
|---|---|---|---|
| `color-contrast` (token-rooted) | `replace-with-shared` | Swap the design token to an AA-compliant value **in the project's token source** (SCSS variables module, `tokens.css`, theme object, utility-framework theme config — from idioms) | Low (cascades; **pixel-changing** — visual regression gated by the Phase 3 before/after diff, never asserted in this cell) |
| `button-name` on icon-only buttons inside the project's **row-action / table-action wrappers** | `add-validator` | Wrapper injects `aria-label` from an i18n key per icon | Low (the key MUST resolve in every shipped locale — Phase 2 i18n gate; a raw key would render as the accessible name) |
| `label` missing `for`/`id` linkage in the project's **form-field wrapper** | `replace-with-shared` | Auto-wire the wrapper's generated id to its inner input | Low |
| Raw library dialog / dropdown / multiselect used directly in pages (PrimeVue, MUI, Vuetify, Ant, shadcn — whichever this project ships) | `replace-with-shared` | Swap to the project's own wrapper for that role | Medium (call sites; **pixel-changing** — visual regression gated by the Phase 3 before/after diff) |
| Raw-HTML injection without a sanitize wrapper — `v-html`, `dangerouslySetInnerHTML`, `[innerHTML]`, `{@html}` | `add-validator` (security) | Wrap the value with the project's sanitize helper from `_extracted-idioms.md` | Low (security row; gets a test assertion) |
| Hardcoded per-locale literal maps in code (`{ en: '', ar: '' }`) | `replace-with-shared` | Replace with the project's own empty-translations builder / locale factory, named in `_extracted-idioms.md § Voice / locales`. **If idioms names no such helper, HALT this row** — do not invent an API name, and do not assume one exists because it would be convenient | Low |
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
| Color values NOT rooted in tokens | Either tokenize first (route to `/align-recheck` — align pack) or human edits the raw color |

## Phases

### Phase 0 — Pre-flight
- Verify `ai/audits/ui-crawl-findings.json` exists and is < 24h old (else suggest `/ui-crawl` first).
- **Clean tree required.** Refuse to start on a dirty working tree — HALT and ask the user to commit or stash first. Every fix lands as a discrete commit and regression rollback is `git revert`; on a dirty tree each per-class commit would sweep in unrelated staged/unstaged work, and a revert-on-regression would roll that work back too. Relaxed ONLY under `--dry-run` / `--plan` (read-only — nothing is committed).
- **Snapshot the "old" side before any edit.** Copy the input findings JSON to `ai/audits/ui-crawl-findings.pre-fix.json` — Phase 3 diffs the re-crawl against THIS snapshot, because the re-crawl overwrites the live `ui-crawl-findings.json` (the same path Phase 1 read as input), destroying the old side otherwise. Likewise, the input crawl's screenshots at `tests/crawl/.screenshots/` are the BEFORE baseline for the pixel-changing classes (contrast-token swap, raw→shared-component swap) — copy them to `tests/crawl/.screenshots-pre-fix/` so the Phase 3 visual diff has a reference the re-crawl will not clobber.
- Verify `_extracted-idioms.md` populated (else halt; route to `/setup-project --refine`).
- Read `align-discipline.md`'s closure-verb vocabulary. **It ships with the align pack — if the file is absent, degrade: fall back to the inline `## Hard rules` block below (which restates the discipline floor), or HALT with a clear message. Never silently no-op** — a missing discipline rule must not read as "no discipline."

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
   - **i18n gate (any injected i18n key — e.g. the `button-name` `aria-label`).** Before injecting an `aria-label` (or any user-visible string) from an i18n key, assert the key RESOLVES in EVERY shipped locale: read the project's locale tree (from `_extracted-idioms.md § Voice / locales`) and confirm the key is present in each. A key missing from any locale renders its RAW string (`SETTINGS_MENU`, `actions.edit`) as the accessible name — a NEW a11y defect dressed up as a closed finding. Missing in any locale → HALT that row: add the key to all locales first (or route to `/setup-project --refine` if no key exists for it); NEVER inject a key that resolves in only some locales.
3. Run typecheck + lint on touched files.
4. Run scoped Vitest suite for the wrapper (if exists).
5. Commit with conventional message: `fix(<class>): <verb> <wrapper> — closes <N> findings across <M> routes`.

### Phase 3 — Verify (`--verify` or end-of-fix auto)
- Re-run `/ui-crawl --filter=<affected-modules>` (only the modules where findings were closed). This overwrites the live `ui-crawl-findings.json` with the NEW side.
- **Diff `ai/audits/ui-crawl-findings.pre-fix.json` (the Phase-0 snapshot = old side) against the fresh `ui-crawl-findings.json` (new side)** — not the live file against itself. Every targeted finding must be gone.
- **Visual diff for the pixel-changing classes** (contrast-token swap, raw→shared-component swap). Compare the re-crawl's fresh screenshots against the `tests/crawl/.screenshots-pre-fix/` baseline, per affected route × breakpoint, reusing the same authenticated capture `/ui-crawl` performs — the render harness the ui-ux commands standardize on is `visual-check` (frontend pack), which carries the authenticated + blocked-render contract. Print the honest status line — `rendered: VERIFIED (before/after diff computed, <N> routes)` — or, when the harness is absent or the re-crawl render is BLOCKED (login wall / redirect / surface marker absent), `rendered: SKIPPED (no baseline / blocked render) — visual regression NOT verified; re-crawl is axe-only + human review needed`. NEVER assert this as a checkmark in a Risk cell, and never let a login-wall screenshot count as a clean diff. An unintended-region diff over threshold is a visual regression → treat it as a new finding (halt + revert, below).
- **Raw-key scan (i18n).** Grep the re-crawl's captured accessible names + rendered DOM for raw-key patterns — `SCREAMING_SNAKE_CASE` and `dotted.key.path`. A raw key visible on screen or in an accessible name is a FAILURE, not a closed finding → halt the row, revert, surface (the injected key did not resolve in the rendered locale).
- If any finding remains: halt the row, write `ai/align/halts/<finding-id>.md`, surface to user.
- If new findings appear (including a visual regression or a raw key on screen): a fix regressed something — halt, revert the commit, surface.

### Phase 4 — Report
- Append summary to `ai/audits/ui-crawl-fix-log.md`:
  - Findings closed (per class)
  - Commits authored
  - Routes affected
  - Findings remaining (skipped for human triage)
  - Verification result

## Flags

- `<class>` — Optional. Fix only this class. Examples: `contrast`, `button-name`, `label`, `unsanitized-html` (matches `v-html` / `dangerouslySetInnerHTML` / `[innerHTML]` / `{@html}`), `translations`, `raw-component`.
- `--dry-run` — Show what WOULD be edited (per file + diff preview). No changes written.
- `--plan` — Universal handoff flag (see `templates/snippets/plan-flag.md`). Runs the read-only Phase 0–1 only (pre-flight + triage: which wrapper file to patch, the closure verb, and the cascade count per class), writes that wrapper-level fix plan to `.claude/plans/ui-crawl-fix-<slug>-<YYYYMMDD-HHmm>.md`, prints the path + a one-line summary, and exits BEFORE Phase 2 — no edits, no commits. The clean-tree precondition is relaxed under `--plan` (nothing is written). Hand the plan to another tool or execute later with `/execute-plan <file>`. Distinct from `--dry-run`, which previews diffs to the terminal but leaves no portable artifact.
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
/ui-crawl-fix --plan                 # read-only: write the wrapper-fix plan to .claude/plans/, exit before any edit
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
- **Clean tree to start.** The run refuses a dirty working tree (Phase 0): discrete per-class commits + `git revert` rollback are only safe from a clean baseline, else a revert sweeps unrelated work. Relaxed only under `--dry-run` / `--plan` (nothing is committed).
- **i18n keys resolve in every locale.** Any `aria-label` / string injected from an i18n key is asserted present in EVERY shipped locale before commit (Phase 2 gate), and the re-crawl is grepped for raw-key patterns (Phase 3). A raw key on screen is a FAILURE, never a closed finding.
- **Pixel-changing fixes are verified by render, not by claim.** Contrast-token and raw→shared-component swaps are gated by the Phase 3 before/after visual diff, which prints `rendered: VERIFIED / SKIPPED` — a visual-regression check is never asserted in a Risk cell. When the render is `SKIPPED`/`BLOCKED`, the axe/DOM re-scan alone is blind to visual regressions, so the visual side is reported NOT verified and human review is needed — the fix is not silently claimed safe.

## Output (terminal summary)

```
[fix] reading ai/audits/ui-crawl-findings.json (146 routes, 1463 violations)
[fix] pre-flight: clean tree ✓ · snapshot → ai/audits/ui-crawl-findings.pre-fix.json + tests/crawl/.screenshots-pre-fix/
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
[verify] visual-diff (contrast + raw→shared swaps): rendered: VERIFIED (before/after, 79 routes) — no unintended-region regressions
[verify] i18n raw-key scan (button-name aria-labels): 0 raw keys in rendered accessible names ✓
[fix] complete. 3 commits. 1451 of 1463 violations closed (99.2%).
```

## Cross-references

- `/ui-crawl` — the detector this command consumes.
- `.claude/rules/align-discipline.md` — closure-verb vocabulary, tier rules, validator script.
- `/align-recheck` / `/align-fast` (align pack) — sibling commands for structural-only fixes; this is the UI-specific variant that consumes a `/ui-crawl` report instead of an `/align-scan` report.
- `_extracted-idioms.md` — the source of truth for which wrappers exist; this command never invents.
- `/enhance-ui` — visual polish on one surface (different scope).
- `/ui-sweep` — deeper specialist sweep with HTML report + visual baselines; orthogonal to this fix loop.
- `/polish` — the simple-surface entry; for `frontend-*` its visual branch dispatches the `ui-design-sweep` skill's SEPARATE 19-verb DESIGN vocabulary (hierarchy / rhythm / tokens / states / motion / …), which shares no verbs with what this command patches. `/ui-crawl-fix` patches at the wrapper level using `align-discipline.md`'s (align pack) 21-verb closure vocabulary (`replace-with-shared` / `add-validator` / …). The two vocabularies are disjoint — do not conflate them: /polish's set corrects DESIGN axes, this command's set closes structural/mechanical findings.

## Stack scope

Frontend stacks only (`PROJECT_KIND in {frontend-*, mobile-web}`). Halts on backend / data / library / CLI projects.

**Every concrete file path, wrapper name, component-library name and helper name in this file is ILLUSTRATIVE** — the worked example happens to be shaped like a Vue 3 + Vite + Pinia app with a PrimeVue control layer, and the terminal transcript below shows it that way because a transcript with `<the form-field wrapper>` in it teaches nothing. Substitute the real names for React / Next / Svelte / Solid / Angular (and MUI / Ant / Vuetify / shadcn) from the project's `_extracted-idioms.md`. **The command resolves every one of them from idioms at run time and halts if a role has no named owner — it never pattern-matches the names printed here against the repo.**
