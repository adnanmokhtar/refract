---
description: Find hardcoded strings, missing keys, locale parity breaks, and unused keys.
---

# /i18n-audit [locale-dir]

Audit command. Static scan for i18n drift. Phases 1-3 + 6 dominate; Phase 4 produces a report; Phase 5 logs the audit and (optionally) scaffolds missing keys.

## The Premise (read this first, internalize, do not deviate)

**Find real issues. No hand-waves.** Every claim cites `<path:line>` (for hardcoded strings) or `<key-path>` (for missing/dead keys). Vague gestures ("locales seem out of sync", "consider auditing dynamic keys") are forbidden — they do nothing for the user and burn audit budget.

**The agent's job is exactly this:** resolve the locale dir + pivot locale + UI source globs; run three mechanical passes — hardcoded scan, parity diff, dead-key sweep — every result anchored to `<path:line>` or `<key-path>`; group by category (Missing | Hardcoded | Drifted | Dead) and append to `ai/audits/<date>-i18n.md`.

**The agent ONLY asks the user when:** a key is dynamic (`t('status.' + value)`) — flag for manual confirmation, never auto-delete; a translation value is missing — never auto-translate, copy the pivot value verbatim with a `TODO: translate` marker so translators see it; a pluralization category set differs from the pivot's — ask the translator, don't fabricate. Everything else — hardcoded grep, key-set diff, dead-key grep, interpolation token compare — is mechanical. Run it, report.

**Lightweight default.** The incremental audit (one feature, one locale dir) is the default tier: three-pass scan → grouped report → audit log entry, no ADR and no rule promotion. Promote to an ADR only on systemic-drift evidence.

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
- `.claude/rules/i18n.md` — the hard rules this audit's findings map onto: dynamic-key translation field type, and active-language refs that read `locale.value` directly rather than through an `=== 'en' ? … : …` ternary. Without it the three passes find drift but grade it against nothing.

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

### Hand-wave mechanical halt (mandatory, all tiers)

Before declaring the report complete, scan every finding for hand-wave language. For each finding, return one of: `closed` (cites `<path:line>` or `<key-path>`), `still-open` (vague), `regressed` (claim made without evidence).

**Halt if any finding contains:**

- `etc.`, `...`, `and similar`, `various keys`, `several files` — open-ended gestures with no enumerated targets.
- `N+` style counts without listing each `<path:line>` or `<key-path>`. Either enumerate or don't claim.
- `consider`, `might want to`, `look into`, `review overall`, `seems out of sync` — non-actionable verbs.
- `generally`, `mostly`, `appears to` — hedges. Either the key is missing in the alt locale or it isn't.
- A hardcoded-string finding without a `<path:line>` anchor.
- A missing-key finding without the exact `<key-path>` AND the locale file it is missing from.
- A dead-key finding without the last-seen commit OR a confirmation-required note — dynamic keys are unreachable to grep, so never claim "dead" without manual confirmation.
- An auto-translated value — machine output is a placeholder, never shippable copy; copy the pivot value verbatim with a `TODO: translate` marker.

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-i18n.md` — append timestamped report.
- `ai/dynamic/changelog.md` — one-line: `i18n audit: N hardcoded, M missing in <locale>, K dead`.
- Optionally scaffold missing keys: copy source-locale value verbatim with `// TODO: translate` comment so translators see them.

## Phase 6 — Validate
- Interpolation tokens (`{count}`, `%{name}`, `{{user}}`) match across locales — mismatch = runtime crash, blocker.
- Pluralization categories match per locale (en: `one/other`; ar: `zero/one/two/few/many/other`) — don't collapse.
- Dynamic keys (`t('status.' + value)`) resolved by the prefix-x-union sweep below, not left as "flag for manual confirmation" — that phrasing hands the hardest case back to the reader.
- Translation field type is dynamic-key (`Record<string, string>` or the framework equivalent), and no active-language ref reduces the locale set through a two-branch ternary — both are `.claude/rules/i18n.md` § Must, and a parity report that passes while the type is fixed-key is measuring the wrong thing.

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

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** → **SHOULD FIX** → **OPTIONAL** — each step carrying `<path:line>` or `<key-path>` + **Fix** (concrete) + **Verify**, then the closing steps (re-run `/i18n-audit` to confirm it comes back clean, then ship). A clean run collapses to a single line ("No findings — clear to proceed"). The reader must never assemble the next steps themselves.

## Failure modes
- Auto-translating missing values → machine output is a placeholder, never shippable copy.
- Collapsing pluralization to en's two-form set → breaks ar / ru / pl users; preserve full category set.
- Interpolation token mismatch unflagged → runtime crash on render; treat as blocker.
- Deleting dynamic keys (`t('status.' + value)`) → unreachable to grep; require manual confirmation.
- RTL/LTR mixed numerals — flag for human review, never auto-rewrite.
