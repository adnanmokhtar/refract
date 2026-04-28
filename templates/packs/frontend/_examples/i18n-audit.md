---
description: Find hardcoded strings, missing keys, locale parity breaks, and unused keys.
---

# /i18n-audit [locale-dir]

Audit command. Static scan for i18n drift. Phases 1-3 + 6 dominate; Phase 4 produces a report; Phase 5 logs the audit and (optionally) scaffolds missing keys.

## When to use / NOT to use
- USE: before shipping a feature that added text.
- USE: after a translator delivers a new locale file.
- USE: before promoting a new locale to GA.
- NOT: when the repo has no i18n setup — say so and stop.
- NOT: as a substitute for human translation review — automated tools find drift, not quality.

## Phase 1 — Understand
- Locate locale files (`locales/`, `i18n/`, `lang/`, `messages/`) — confirm which directory is authoritative.
- Identify pivot locale (most-complete, usually `en`).

## Phase 2 — Organize
- Decide passes: hardcoded scan + parity diff + dead-key sweep.
- Decide reviewer: `i18n-auditor` agent runs all three passes.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

i18n-specific:
- The i18n library (`vue-i18n`, `next-intl`, `react-i18next`, `@angular/localize`, `nuxt-i18n`) — abort if none found.
- Pivot locale file + every locale file.
- UI source globs (`.tsx`, `.vue`, `.svelte`, `.html`).

## Phase 4 — Generate (the report)
- Dispatch `i18n-auditor` with locale dir + UI source globs.
- Agent runs three passes:
  - **Hardcoded**: regex for quoted strings inside JSX/templates not wrapped by the i18n call (`t(...)`, `$t(...)`, `<Trans>`, `i18n.t(...)`).
  - **Parity**: diff key sets across locales — pivot is the most-complete locale.
  - **Dead keys**: each key grepped against UI source; zero hits = candidate for removal.
- Print grouped: Missing | Hardcoded | Drifted | Dead.
  ```
  Hardcoded (3):
    Button.tsx:24   "Submit"          → suggest key: common.submit
    Form.tsx:88     "Required field"  → suggest key: form.errors.required
  Missing in ar.json (5):
    product.list.empty
    cart.checkout.cta
  Dead keys (2):
    legacy.old_modal_title  (last seen in commit 8a3f2 — confirm before deletion)
  ```

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-i18n.md` — append timestamped report.
- `ai/dynamic/changelog.md` — one-line: `i18n audit: N hardcoded, M missing in <locale>, K dead`.
- Optionally scaffold missing keys: copy source-locale value verbatim with `// TODO: translate` comment so translators see them.

## Phase 6 — Validate
- Interpolation tokens (`{count}`, `%{name}`, `{{user}}`) match across locales — mismatch = runtime crash, blocker.
- Pluralization categories match per locale (en: `one/other`; ar: `zero/one/two/few/many/other`) — don't collapse.
- Dynamic keys (`t('status.' + value)`) flagged for manual confirmation, not auto-deleted.

## Phase 7 — Improve
- `/learn-from-task` — capture missing-key patterns by feature.
- If 3+ hardcoded strings in same file → queue lint rule proposal: `i18next/no-literal-string`.
- If pivot locale drift > 10% → queue ADR: locale workflow + translator handoff process.

## Output format
```
## /i18n-audit — <H> hardcoded, <M> missing, <D> dead

Phase 1 (Understand): pivot = <locale>; N locale files detected
Phase 3 (Retrieved): library = <name>; UI globs scoped
Phase 4 (Generated): grouped report (above)
Phase 5 (Updated): ai/audits/<date>-i18n.md; <K> missing keys scaffolded with TODO
Phase 6 (Validated): interpolation parity; pluralization categories preserved
Phase 7 (Improved): patterns queued

Status: COMPLETE | BLOCKED on <H> hardcoded
```

## Failure modes
- Auto-translating missing values → machine output is a placeholder, never shippable copy.
- Collapsing pluralization to en's two-form set → breaks ar / ru / pl users; preserve full category set.
- Interpolation token mismatch unflagged → runtime crash on render; treat as blocker.
- Deleting dynamic keys (`t('status.' + value)`) → unreachable to grep; require manual confirmation.
- RTL/LTR mixed numerals — flag for human review, never auto-rewrite.
