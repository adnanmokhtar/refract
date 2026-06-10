---
name: i18n-localization-discipline
description: Internationalization & localization discipline
kind: rule
---

# Internationalization & localization discipline

## Hard rule

EVERY user-facing string MUST be a key in a per-locale message catalog — NEVER a literal baked into a component, handler, or log-that-reaches-a-user. Sentences MUST be built with ICU MessageFormat and named arguments; concatenating or template-interpolating fragments to assemble a sentence (`"You have " + n + " items"`) is FORBIDDEN — word order, gender, and plural rules differ per language. Plurals MUST use ICU `plural` against the locale's CLDR plural categories; `n === 1 ? 'item' : 'items'` is WRONG for Arabic (6 categories), Russian/Polish (3-4), and many more. The active locale MUST be negotiated against a fixed server-side ALLOWLIST with a defined fallback chain and an explicit missing-key policy — a client-supplied locale that selects a catalog path is a path-traversal / cache-poisoning vector, and a raw key leaking to the UI (`profile.title`) or a crash-on-missing-key is a defect. Dates, numbers, and currency MUST be formatted through a locale + timezone-bound formatter (Intl / CLDR) — never `n.toFixed(2)`, never a hardcoded `$`, never `date.toLocaleString()` with no locale. Layout MUST be direction-aware (logical CSS properties / `dir`, not `left`/`right`). Translator-supplied strings MUST be treated as untrusted: rendered escaped, never as raw HTML, with user-interpolated values escaped independently.

An i18n bug is a screen of raw keys, a sentence that is grammatical nonsense in the target language, a money figure with the wrong separators or symbol, a broken RTL layout, or XSS shipped via a translation file. Each one tells a user the product was not built for them — or hands an attacker the page.

## Must

- **Every user-facing string is a catalog key**: components, handlers, emails, validation messages, and user-visible errors render `t('key', args)` from a per-locale catalog. No literal user-facing text in code. Internal logs / machine codes are exempt (and stay un-translated on purpose).
- **Typed key contract**: catalog keys are a generated/derived union type (`MessageKey`), so `t('proflie.title')` fails at compile time, not in production. The key set is the source of truth; every locale catalog is checked against it.
- **ICU MessageFormat for every sentence with a variable**: counts, names, gender, and choices go through ICU (`{count, plural, ...}`, `{gender, select, ...}`) with NAMED arguments. Never assemble a sentence from fragments — the translator owns word order.
- **CLDR plural categories**: plural messages enumerate the categories the target languages actually use (`zero one two few many other`), not just `one`/`other`. The runtime selects the category from the locale's CLDR rules — the code never branches on `n === 1`.
- **Locale negotiated from a trusted allowlist**: the active locale is resolved by matching the request's `Accept-Language` / user preference against a FIXED server-side `SUPPORTED_LOCALES` allowlist (BCP-47), with a defined fallback chain (`pt-BR -> pt -> en`). An unmatched locale falls back; it NEVER selects a catalog path directly.
- **Explicit missing-key policy**: dev/CI THROWS on a missing key (so it's caught before ship); prod renders the fallback-locale string AND reports the miss (metric/log) — it never shows the raw key and never crashes.
- **Locale + timezone-bound edge formatting**: dates, times, numbers, percents, and currency are formatted with `Intl.*` (or a CLDR lib) bound to the active locale AND the user's timezone. Currency uses the integer-minor-unit `Money` type (see `<patterns-path>/payment-integration.md § Money`) formatted with its currency tag — never a float, never a hardcoded symbol.
- **Direction-aware layout**: styling uses logical properties (`margin-inline-start`, `padding-inline`, `text-align: start`) and the document/root carries `dir` derived from the locale; mirror-able icons flip under RTL. No physical `left`/`right` for flow-relative layout.
- **Translations are untrusted input**: catalog values render through the framework's escaping (text nodes, not `dangerouslySetInnerHTML` / `v-html` / `|safe`). Rich text uses a structured component-interpolation API (tags as elements), not embedded HTML in the string. User-interpolated values are escaped independently of the template.
- **Timezone-correct "now/today"**: any "today", "this month", or relative time is computed in the USER's timezone, not the server's UTC clock (same bug class as `<rules-path>/reporting-export-discipline.md`).
- **Centralized i18n access**: all translation + formatting goes through a project `<i18n>` / `t()` / `<Trans>` boundary so the allowlist, fallback chain, escaping, and edge formatters are enforced in ONE place — feature code asks for a key, not for a raw catalog lookup.

## Must not

- Hardcode a user-facing string in a component / handler / email / validation message.
- Build a sentence by concatenation or interpolation (`label + ': ' + value`, `` `Welcome ${name}` `` for a translated greeting) — translators can't reorder it.
- Pluralize with `n === 1 ? singular : plural` (or a 2-branch ternary) — wrong for most of the world's languages.
- Resolve the locale from raw client input without an allowlist, or use the locale string to build a file path / cache key unchecked.
- Ship a build with missing keys silently — either the raw key or a hard crash reaches the user.
- Format a date/number/currency without an explicit locale (`toFixed`, `toLocaleString()` no-arg, hardcoded `$`/`,`/`.`).
- Render a translation as raw HTML (`v-html` / `dangerouslySetInnerHTML` / `{!html}`) — XSS via the translation file.
- Use physical `left`/`right`/`margin-left` for flow layout that must mirror under RTL.
- Compute "today"/"now" in server UTC for a user in another timezone.

## Should

- Express catalogs as flat, namespaced keys (`checkout.summary.total`) with the typed key union derived at build time; lint for orphan keys (in catalog, never referenced) and missing keys (referenced, not in catalog).
- Keep ONE canonical source locale (usually `en`) as the contract; other locales are diffed against it in CI so a new key blocks merge until every locale has it (or an accepted fallback).
- Use a structured rich-text API (`<Trans i18nKey="..."><b>{name}</b></Trans>` / ICU tag args) so emphasis/links are components, not HTML strings the translator could break.
- Pseudo-localize in a dev locale (accented + padded text) to surface hardcoded strings and truncation before real translation.
- Lazy-load non-active locale catalogs (code-split per locale) so a 12-language app doesn't ship every catalog to every user.
- Log structured `{ event: 'i18n.missing_key', key, locale, fallbackUsed }` and alert when the missing-key rate crosses a threshold (a regression in catalog coverage).
- Provide one ICU example per non-trivial plural so translators see the `few`/`many` slots their language needs.

## Review checklist (PRs touching UI text, emails, formatters, locale routing, or catalogs)

- [ ] No hardcoded user-facing string — every one is a catalog key; cite `<path:line>` for any literal found.
- [ ] Keys resolve against the typed key contract; missing/typo keys fail at build, not runtime.
- [ ] Sentences with variables use ICU + named args — no concatenation / template-built sentences.
- [ ] Plurals use ICU `plural` with the categories the target languages need — no `n === 1` branch.
- [ ] Locale negotiated from the `SUPPORTED_LOCALES` allowlist with a defined fallback chain; client input never selects a path/cache key directly.
- [ ] Missing-key policy explicit: throw in dev/CI, fallback + report in prod — never raw key, never crash.
- [ ] Dates/numbers/currency formatted via `Intl`/CLDR bound to locale + timezone; money via the integer-minor-unit type with a currency tag.
- [ ] Layout uses logical properties + `dir`; verified to not break under an RTL locale.
- [ ] Translations render escaped; rich text uses component interpolation, not embedded HTML; user values escaped independently.
- [ ] "Today/now"/relative time computed in the user's timezone, not server UTC.
- [ ] Every locale catalog is complete against the canonical source locale (or has an accepted fallback).

## Anti-patterns

- **Hardcoded string** — `<button>Save changes</button>` ships only in English; no other locale can ever show it. Every user-facing string is `t('actions.save_changes')`.
- **Concatenated sentence** — `t('you_have') + ' ' + n + ' ' + t('items')` produces grammatical nonsense in languages with different word order / gendered nouns / cases. One ICU message: `{count, plural, one {You have # item} other {You have # items}}`.
- **Two-branch plural** — `n === 1 ? 'item' : 'items'` shows "1 элемент / 2 элемента / 5 элементов" all wrong in Russian. ICU `plural` selects from CLDR `one/few/many/other`.
- **Locale from raw input** — `loadCatalog(req.query.lang)` lets `?lang=../../etc/passwd` traverse, or `?lang=xx-xx-xx...` fragment-poison the catalog cache. Match against `SUPPORTED_LOCALES`; fall back on no match.
- **Silent missing key** — a new `en` key never added to `de` ships `checkout.total` literally to German users (or crashes). Throw in CI; fallback + report in prod.
- **Locale-blind money** — `'$' + (cents/100).toFixed(2)` shows `$1,234.50` to a German user who expects `1.234,50 €`. Format the `Money` type via `Intl.NumberFormat(locale, { style: 'currency', currency })`.
- **Locale-blind date** — `new Date(ts).toLocaleString()` (no locale) renders in the server's locale + UTC, with the wrong separators and calendar. Bind locale + timezone explicitly.
- **Physical RTL** — `margin-left: 16px; text-align: left` doesn't mirror; the Arabic layout reads backwards with misplaced spacing. Use `margin-inline-start` + `text-align: start` + `dir`.
- **Translation as HTML** — `<span v-html="t('promo.banner')" />` turns a compromised/sloppy translation string into stored XSS. Render as text; use component interpolation for emphasis.
- **Server-UTC "today"** — "Today's deals" computed from the server clock shows yesterday's set to a user in GMT-7. Compute the day boundary in the user's timezone (same bug as reporting).

## Enforcement

- `<commands-path>/scan-i18n-coverage.md` (slash: `/scan-i18n-coverage`) — cite-or-halt diagnostic that scans for hardcoded strings, missing/orphan keys per locale (coverage matrix), concatenated sentences, `n === 1` plurals, and locale-blind date/number/currency formatting — at `<path:line>`, never an assumed catalog.
- `<agents-path>/i18n-reviewer.md` — review gate hard-failing on hardcoded user-facing strings, concatenated/interpolated sentences, naive pluralization, missing-fallback / silent-missing-key, locale-blind formatting, unhandled RTL, untrusted-locale routing, and translation-as-HTML XSS.
- CI lint MUST reject JSX/template literals containing user-facing text not wrapped in `t()` / `<Trans>` (heuristic; allowlist machine strings).
- CI MUST diff every locale catalog against the canonical source locale and fail on a missing key (or an unaccepted fallback).
- CI lint MUST reject `n === 1`/`length === 1` ternaries selecting a label, and string `+`/template concatenation of `t()` results (AST heuristic; flag for review).
- CI lint MUST reject `dangerouslySetInnerHTML` / `v-html` / `|safe` fed by a `t()` value, and `toLocaleString()`/`toLocaleDateString()` called with no locale argument.
- TODO: `scripts/validate-i18n.sh` to walk the catalog set, assert key parity against the canonical locale, detect orphan keys, and assert every locale string in `SUPPORTED_LOCALES` resolves through the allowlist.

## Cross-references

- `<patterns-path>/message-catalog.md` — keyed catalog + typed key contract, ICU plural/gender/select, locale negotiation + fallback chain, edge date/number/currency formatters, RTL-aware rendering, and escaped interpolation code shapes.
- `<rules-path>/reporting-export-discipline.md` — the SAME edge-formatting + timezone-correct-boundary discipline for money/dates in reports and exports.
- `<patterns-path>/payment-integration.md § Money` — integer-minor-unit money type that the currency formatters render.
- `<rules-path>/content-escaping.md` — user-generated-content escaping; translations are the same untrusted-input class.
- `<commands-path>/scan-i18n-coverage.md` — coverage / hardcoded-string diagnostic.
- `<agents-path>/i18n-reviewer.md` — review gate.
- `<adr-path>/<NNN>-i18n-locale-strategy.md` — ADR pinning the supported-locale allowlist, fallback chain, missing-key policy, and ICU library choice.
