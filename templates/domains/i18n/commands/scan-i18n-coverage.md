---
description: Scan a codebase for i18n defects — hardcoded user-facing strings, missing/orphan catalog keys per locale, concatenated sentences, naive plurals, and locale-blind date/number/currency formatting — from the REAL source + catalogs, never an assumed catalog.
---

# /scan-i18n-coverage

Diagnose whether the UI is actually localizable: which strings escape the catalog, which keys are missing or orphaned per locale, where sentences are concatenated, where plurals are faked, and where dates/numbers/currency are formatted without a locale — all cited at `<path:line>`, never narrated from assumption.

## Premise

Real signals only. Cite the hardcoded literal at `<path:line>`, the catalog files actually present, the exact key that is missing from a given locale, the concatenation expression, the `n === 1` ternary, and the locale-blind formatter call — never claim "it's translated" or "coverage is fine" without the file. Read before scanning: locate the catalog set (the locale files), the `t()` / `<Trans>` boundary, and the `SUPPORTED_LOCALES` allowlist BEFORE counting anything; a coverage matrix is meaningless without the real key set.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the catalog files found + the canonical source locale at `<path:line>`, (2) any hardcoded user-facing string at `<path:line>`, (3) the per-locale coverage matrix computed from the REAL key set, (4) each concatenated/template-built sentence and each `n === 1`-style plural at `<path:line>`, and (5) each locale-blind date/number/currency formatter at `<path:line>`. If the catalog set, the `t()` boundary, or the locale allowlist can't be located, HALT and say which — never assume a catalog, never assume coverage, never report a key as present/missing without reading the file.

This command is READ-ONLY. It opens source + catalog files and reports; it never edits a catalog, never adds a key, never rewrites a string.

## What it does

1. **Locate the i18n surface** — the catalog files (per-locale), the canonical source locale, the `t()` / `<Trans>` boundary, and the `SUPPORTED_LOCALES` allowlist + fallback chain. Cite each at `<path:line>`. If absent, that's the first finding.
2. **Hardcoded strings** — scan components / handlers / emails / validation messages for user-facing string literals NOT wrapped in `t()` / `<Trans>` (JSX text nodes, alt/title/placeholder/aria-label, thrown user-visible messages). Cite each at `<path:line>`; allowlist machine strings (codes, log lines).
3. **Coverage matrix** — for every key referenced in code AND every key in the canonical locale, check presence across all `SUPPORTED_LOCALES`. Report missing keys (in canonical, absent in locale X) and orphan keys (in a catalog, never referenced in code).
4. **Concatenated sentences** — find `t(...) + ...` / template literals assembling a translated sentence from fragments. Cite at `<path:line>`.
5. **Naive plurals** — find `n === 1 ? a : b` / `length === 1` ternaries (and `count > 1`) selecting a label instead of an ICU `plural` message. Cite at `<path:line>`.
6. **Locale-blind formatting** — find `toFixed`, no-locale `toLocaleString()` / `toLocaleDateString()`, hardcoded currency symbols (`$`/`€`), and manual separator formatting. Cite at `<path:line>`.
7. **Untrusted render / locale** — flag `t()` values fed to `v-html` / `dangerouslySetInnerHTML` / `|safe`, and any locale resolved from raw input without the allowlist.
8. **Report** — the coverage matrix + a ranked finding list, BLOCKERs first.

## Flow

```text
locate catalogs + t() boundary + allowlist (<path:line>)     [finding if absent]
  -> scan for hardcoded user-facing literals                 [finding per literal]
  -> compute coverage matrix vs canonical locale             [missing + orphan keys]
  -> find concatenated/template-built sentences              [finding per site]
  -> find n===1 / length===1 plural ternaries                [finding per site]
  -> find locale-blind date/number/currency formatters       [finding per site]
  -> flag t()->raw-HTML and locale-from-raw-input            [BLOCKER if present]
  -> report: coverage matrix + ranked findings (BLOCKERs first)
```

## Output

```
/scan-i18n-coverage — <scope>

i18n surface:
  catalogs:   src/i18n/messages/{en,de,fr,ar}.ts        canonical: en   @ src/i18n/messages/en.ts:1
  boundary:   t() @ src/i18n/t.ts:8 · <Trans> @ src/i18n/Trans.tsx:5
  allowlist:  SUPPORTED_LOCALES @ src/i18n/negotiate.ts:4   fallback chain: present
  [or: NO catalog / NO t() boundary / NO allowlist — BLOCKER, reported first]

Coverage matrix (keys present / total canonical = 312):
  locale   present   missing   orphan
  en        312/312      0        2     (canonical)
  de        308/312      4(!)     0
  fr        312/312      0        0
  ar        300/312     12(!)     0

  missing (de):  checkout.summary.tax, profile.timezone, ... @ src/i18n/messages/de.ts
  orphan  (en):  legacy.banner_v1, promo.spring2023        @ src/i18n/messages/en.ts:88,91

Findings:
  BLOCKER  hardcoded user-facing string   src/checkout/Summary.tsx:42   "Order total"
  BLOCKER  concatenated sentence          src/cart/Count.tsx:18         t('you_have')+n+t('items')
  BLOCKER  naive plural (n===1)           src/cart/Count.tsx:18         n === 1 ? 'item' : 'items'
  BLOCKER  translation -> raw HTML        src/promo/Banner.vue:7        v-html="t('promo.banner')"
  REQUEST  locale-blind currency          src/checkout/Total.tsx:51     '$' + (cents/100).toFixed(2)
  REQUEST  locale-blind date              src/orders/Row.tsx:29         d.toLocaleString()  (no locale)
  REQUEST  missing keys (de, ar)          see coverage matrix above

Verdict: OK | NEEDS-KEYS | NEEDS-ICU | BLOCKER(hardcoded/xss)

Top recommendation:
  - <e.g. extract Summary.tsx:42 to t('checkout.summary.total'); rewrite Count.tsx:18 to ICU plural;
     add 4 missing de keys; replace v-html with escaped <Trans> component interpolation>
```

## Rules

- READ-ONLY. The scan reads source + catalogs and reports; it NEVER edits a catalog, adds a key, or rewrites a string.
- Cite-or-halt: real literal, real catalog file, real missing/orphan key, real concatenation/plural/formatter site — or halt naming what's missing.
- The coverage matrix is computed from the REAL key set (code references ∪ canonical locale) — never an assumed or estimated count.
- A hardcoded user-facing string, a `t()` value rendered as raw HTML, and a locale resolved from raw input without the allowlist are BLOCKERs, reported first.
- Machine strings (log lines, error codes, metric labels, enum values) are NOT findings — allowlist them; don't flag them as un-translated.
- Never report a key as present/missing, or a string as wrapped/unwrapped, without having read the file.

## Cross-references

- `.claude/rules/i18n-localization-discipline.md` — the hard-rule list this command enforces (catalog keys, ICU, allowlist, fallback, edge formatting, RTL, escaping).
- `ai/patterns/message-catalog.md` — the keyed-catalog + ICU + negotiation + edge-formatter shapes the findings point toward.
- `<agents-path>/i18n-reviewer.md` — review gate that consumes these findings.
