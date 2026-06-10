---
name: message-catalog
kind: ai-pattern
---

# Pattern: Message catalog (keyed ICU messages, locale negotiation, edge formatting)

> **Hard rule** — Every user-facing string is a KEY in a per-locale catalog, never a literal in code; sentences with variables are ICU MessageFormat with NAMED args (never concatenation); plurals use ICU `plural` against CLDR categories (never `n === 1`); the active locale is negotiated against a fixed server-side ALLOWLIST with a defined fallback chain and an explicit missing-key policy (dev: throw; prod: fallback + report); dates/numbers/currency are formatted via `Intl`/CLDR bound to locale + timezone (money via the integer-minor-unit type); layout is direction-aware via logical properties; translations are untrusted and render escaped, never as raw HTML.

**When to apply**
- Any product that ships, or will ship, in more than one language — or one language but multiple regions (number/currency/date conventions differ even within a language).
- Any surface with user-facing text: components, emails, notifications, validation messages, user-visible errors.
- Any place a count, name, gender, date, number, or money figure is rendered into a sentence.

**When NOT to apply**
- Machine-facing strings: log lines, error codes, metric labels, API enum values — these stay un-translated on purpose (translating them breaks grepping and alerting).
- A single-locale internal tool with a committed decision never to localize — the typed-key + ICU machinery is overhead (but locale-aware money/date formatting still applies if you serve multiple regions).
- Content that is itself user-generated (a user's post body) — that's escaping + storage, see `<rules-path>/content-escaping.md`, not catalog translation.

**Halt conditions / mandatory cites**
- Cite the per-locale catalog + the typed key contract at `<path:line>`. A user-facing literal in a component/handler = halt.
- Cite the ICU message + its named args for any sentence with a variable at `<path:line>`. A concatenated/template-built sentence = halt.
- Cite the ICU `plural` message at `<path:line>`. A `n === 1` / 2-branch plural selecting a label = halt.
- Cite the locale-negotiation function + the `SUPPORTED_LOCALES` allowlist + the fallback chain at `<path:line>`. Locale from raw client input selecting a path/cache key = halt.
- Cite the missing-key policy (throw-in-dev / fallback-and-report-in-prod) at `<path:line>`. Silent raw-key leak or crash-on-missing = halt.
- Cite the locale+timezone-bound formatter for date/number/currency at `<path:line>`. `toFixed` / no-locale `toLocaleString` / hardcoded `$` = halt.
- Cite the escaped render path for translations at `<path:line>`. `v-html` / `dangerouslySetInnerHTML` fed by `t()` = halt.
- Grep ban: "it's translated / localized / RTL-safe" without file:line for the catalog key, the ICU message, the allowlist, and the escaped render.

## Why

Localization fails in ways that are invisible in the source language and obvious to the target user:

1. **Grammar doesn't translate by substitution.** `"You have " + n + " items"` assumes English word order, no grammatical gender, and a 2-form plural. Arabic has 6 plural categories; Russian and Polish have distinct `few`/`many`; German reorders the sentence; many languages inflect the noun by number. The translator must own the WHOLE sentence — so the sentence must be one ICU message with named arguments, not fragments the code glues together.
2. **Formatting is locale data, not string ops.** `1,234.50` is `1.234,50` in German and `1 234,50` in French; `$` is `€`/`¥`/`₹` elsewhere with different placement; calendars and digit shaping differ. `toFixed(2)` and hardcoded separators are wrong everywhere but the author's locale. `Intl`/CLDR carries the data.
3. **Locale is untrusted input.** A locale string that selects a catalog file or a cache key is a path-traversal and cache-poisoning surface. Negotiate against a fixed allowlist; never let raw input pick a path.
4. **Translations are untrusted content.** A translation file is editable by non-engineers / vendors / a compromised pipeline. Rendered as HTML, it's an XSS vector. Render escaped; interpolate rich text as components.

The pattern: declare a typed key set, author ICU messages per locale, negotiate the locale through an allowlist + fallback, and render through one boundary that formats at the edge and escapes.

> The TypeScript/React examples below use a generic `t()` / `<Trans>` boundary and `Intl`. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the i18n library (i18next / FormatJS / vue-i18n / Rails I18n / gettext), the framework's rich-text component, and your `Money` type. The SHAPE — keyed catalog + typed keys, ICU messages, allowlist negotiation, edge formatters, escaped render — is universal, not the library names.

## Keyed catalogs + the typed key contract

```ts
// src/i18n/messages/en.ts  — the CANONICAL source locale; other locales diff against it.
export const en = {
  'checkout.summary.total': 'Total',
  'cart.item_count': '{count, plural, one {# item} other {# items}}',
  'profile.greeting': 'Welcome back, {name}!',
  'invite.status':
    '{gender, select, female {She invited you} male {He invited you} other {They invited you}}',
} as const;

// The key set is the contract. Every locale catalog is checked against THIS type.
export type MessageKey = keyof typeof en;

// src/i18n/messages/ar.ts — must cover every MessageKey (CI fails otherwise).
export const ar: Record<MessageKey, string> = {
  'checkout.summary.total': 'المجموع',
  // Arabic uses SIX plural categories — zero one two few many other.
  'cart.item_count':
    '{count, plural, zero {لا عناصر} one {عنصر واحد} two {عنصران} few {# عناصر} many {# عنصرًا} other {# عنصر}}',
  'profile.greeting': 'مرحبًا بعودتك، {name}!',
  'invite.status':
    '{gender, select, female {دعتك} male {دعاك} other {دعَوك}}',
};
```

`t('proflie.greeting')` is now a compile error — the typed `MessageKey` union catches typos before they ship. Every locale is a `Record<MessageKey, string>`, so a forgotten key fails the build, not the user.

## ICU MessageFormat — plurals, gender, select (NEVER concatenation)

```ts
// src/i18n/t.ts
import IntlMessageFormat from 'intl-messageformat';

// t() compiles the ICU message for the active locale and applies NAMED args.
export function t<K extends MessageKey>(key: K, args?: Record<string, unknown>): string {
  const { locale, catalog } = activeI18n();
  const raw = catalog[key];                       // already fallback-resolved (see negotiation)
  return new IntlMessageFormat(raw, locale).format(args) as string;
}

// CORRECT — one ICU message owns the whole sentence; the locale's CLDR plural rule picks the form.
t('cart.item_count', { count: n });   // en: "5 items"  ·  ru: "5 элементов"  ·  ar: "5 عناصر"

// FORBIDDEN — concatenation: word order, gender, and plural category can't be expressed.
//   t('you_have') + ' ' + n + ' ' + (n === 1 ? t('item') : t('items'))
//   -> grammatical nonsense in most languages; the translator can't reorder or inflect it.
```

Gender and arbitrary choices use ICU `select`; counts use ICU `plural` with `#` as the formatted number. The code never branches on the count — the runtime selects the CLDR category (`zero/one/two/few/many/other`) for the active locale.

## Locale negotiation from a trusted allowlist + fallback chain

```ts
// src/i18n/negotiate.ts

// FIXED server-side allowlist (BCP-47). Client input is matched against this — never used as a path.
export const SUPPORTED_LOCALES = ['en', 'en-GB', 'de', 'fr', 'pt-BR', 'ar', 'he'] as const;
export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number];
export const DEFAULT_LOCALE: SupportedLocale = 'en';

// Fallback chain: a missing key in pt-BR falls to pt (if supported) then to the default.
const FALLBACK: Record<SupportedLocale, SupportedLocale[]> = {
  'en': [], 'en-GB': ['en'], 'de': ['en'], 'fr': ['en'],
  'pt-BR': ['en'], 'ar': ['en'], 'he': ['en'],
};

/** Resolve the active locale from request preferences — NEVER from a raw path/cache key. */
export function negotiateLocale(acceptLanguage: string | undefined, userPref?: string): SupportedLocale {
  const candidates = [userPref, ...parseAcceptLanguage(acceptLanguage)].filter(Boolean) as string[];
  for (const c of candidates) {
    // Exact, then language-only (pt-BR -> pt), matched against the allowlist.
    const exact = SUPPORTED_LOCALES.find(l => l.toLowerCase() === c.toLowerCase());
    if (exact) return exact;
    const lang = c.split('-')[0].toLowerCase();
    const base = SUPPORTED_LOCALES.find(l => l.toLowerCase() === lang);
    if (base) return base;
  }
  return DEFAULT_LOCALE;                           // unmatched -> default, never the raw input
}

/** Resolve a key through the fallback chain. Missing-key policy is EXPLICIT. */
export function resolveKey(locale: SupportedLocale, key: MessageKey): string {
  for (const loc of [locale, ...FALLBACK[locale], DEFAULT_LOCALE]) {
    const v = CATALOGS[loc]?.[key];
    if (v != null) return v;
  }
  if (process.env.NODE_ENV !== 'production') {
    throw new Error(`i18n: missing key "${key}" for "${locale}" (and fallback chain)`);  // caught in CI
  }
  reportMissingKey({ key, locale });               // prod: metric/log the miss...
  return CATALOGS[DEFAULT_LOCALE][key] ?? key;     // ...and serve the default; never crash
}
```

A `?lang=../../etc/passwd` or a junk locale never reaches a file path or a cache key — it simply fails to match and falls back. Dev/CI throws on a missing key; prod serves the fallback string and reports the miss. The raw key never reaches the user.

## Edge formatters — date / number / currency bound to locale + timezone

```ts
// src/i18n/format.ts
import { Money } from '@/payments/money';          // integer-minor-unit type; see payment-integration § Money

export interface FormatCtx { locale: SupportedLocale; timeZone: string; }

// Numbers: separators, grouping, and digit shaping come from CLDR — never toFixed / manual commas.
export const formatNumber = (n: number, ctx: FormatCtx, opts?: Intl.NumberFormatOptions) =>
  new Intl.NumberFormat(ctx.locale, opts).format(n);   // de: "1.234,5"  fr: "1 234,5"  ar: "١٬٢٣٤٫٥"

// Currency: integer minor units + a currency tag; Intl places the symbol per locale.
export const formatMoney = (m: Money, ctx: FormatCtx) =>
  new Intl.NumberFormat(ctx.locale, { style: 'currency', currency: m.currency })
    .format(m.minor / m.minorPerUnit);               // de EUR: "1.234,50 €"  ·  en USD: "$1,234.50"

// Dates: ALWAYS bind the timeZone — a bare Date renders in the server's zone/locale.
export const formatDate = (d: Date, ctx: FormatCtx, opts?: Intl.DateTimeFormatOptions) =>
  new Intl.DateTimeFormat(ctx.locale, { timeZone: ctx.timeZone, ...opts }).format(d);

// "Today/now" boundaries are computed in the USER's zone, not server UTC (same bug as reporting).
export const userDayStart = (ctx: FormatCtx) =>
  zonedDayStart('today', ctx.timeZone);              // not startOfDay(new Date())

// Relative time ("3 days ago") is locale-aware too.
export const formatRelative = (value: number, unit: Intl.RelativeTimeFormatUnit, ctx: FormatCtx) =>
  new Intl.RelativeTimeFormat(ctx.locale, { numeric: 'auto' }).format(value, unit);
```

`m.currency` carries the ISO code with the amount; the formatter places the symbol and separators per locale. `n.toFixed(2)`, a hardcoded `$`, and a no-locale `toLocaleString()` are all wrong for someone.

## RTL-aware rendering (logical properties, not left/right)

```tsx
// The document direction is DERIVED from the locale, not hardcoded.
const RTL_LOCALES = new Set(['ar', 'he', 'fa', 'ur']);
export const dirFor = (l: SupportedLocale): 'rtl' | 'ltr' =>
  RTL_LOCALES.has(l.split('-')[0]) ? 'rtl' : 'ltr';

export function AppRoot({ locale, children }: { locale: SupportedLocale; children: ReactNode }) {
  return <html lang={locale} dir={dirFor(locale)}>{children}</html>;   // dir flips the whole tree
}
```

```css
/* CORRECT — logical properties mirror automatically under dir="rtl". */
.card { margin-inline-start: 16px; padding-inline: 12px; text-align: start; border-inline-start: 2px solid; }

/* WRONG — physical properties don't mirror; the Arabic layout reads backwards. */
/* .card { margin-left: 16px; text-align: left; border-left: 2px solid; } */
```

Direction-mirrorable icons (back/forward arrows, progress) flip with a `[dir="rtl"] & { transform: scaleX(-1) }` rule; direction-neutral icons (a logo, a play button) do not.

## Interpolation that escapes user content (translation is untrusted)

```tsx
// Rich text uses COMPONENT interpolation — tags are React elements, not HTML in the string.
// The catalog value: "Agree to the <terms>Terms</terms> and <privacy>Privacy Policy</privacy>"
<Trans
  i18nKey="signup.agree"
  components={{ terms: <a href="/terms" />, privacy: <a href="/privacy" /> }}
/>;

// User-interpolated values are escaped by the framework as text nodes — not concatenated into markup.
<p>{t('profile.greeting', { name: user.displayName })}</p>;   // displayName rendered as text, escaped

// FORBIDDEN — a translation (vendor-editable, possibly compromised) rendered as raw HTML = stored XSS.
//   <span dangerouslySetInnerHTML={{ __html: t('promo.banner') }} />
//   <span v-html="t('promo.banner')" />
```

The translation string never becomes HTML. Emphasis and links are components supplied at the call site; user values pass through the framework's text escaping. A malicious or sloppy translation can only ever render as visible text, never execute.

## Common mistakes

### Hardcoded user-facing string
`<button>Save</button>` ships English-only; no locale can translate it. Every user-facing string is `t('actions.save')`.

### Concatenated / template-built sentence
`t('you_have') + ' ' + n + ' ' + t('items')` (or `` `Welcome ${name}` `` for a translated greeting) can't be reordered, gendered, or inflected by the translator. One ICU message with named args owns the sentence.

### Naive pluralization
`n === 1 ? 'item' : 'items'` is wrong for Arabic (6 forms), Russian/Polish (`few`/`many`), and more. ICU `plural` selects the CLDR category for the locale.

### Silent missing key / no fallback
A new `en` key absent from `de` ships `checkout.total` literally (or crashes) for German users. Throw in CI; fallback + report in prod.

### Locale from raw input
`loadCatalog(req.query.lang)` allows path traversal / cache poisoning. Negotiate against `SUPPORTED_LOCALES`; fall back on no match; never let input pick a path.

### Locale-blind formatting
`'$' + (cents/100).toFixed(2)` / `date.toLocaleString()` (no locale) render the author's conventions to everyone. Use `Intl` bound to locale + timezone; money via the `Money` type + currency tag.

### Server-UTC "today"
"Today's deals" from the server clock shows the wrong day to a user in another zone. Compute the boundary in the user's timezone (same bug as `<rules-path>/reporting-export-discipline.md`).

### Physical RTL layout
`margin-left` / `text-align: left` don't mirror; the Arabic layout breaks. Use logical properties + `dir`.

### Translation rendered as HTML
`v-html="t(...)"` / `dangerouslySetInnerHTML` turns a translation file into an XSS surface. Render escaped; interpolate rich text as components.

## Cross-references

- `<rules-path>/i18n-localization-discipline.md` — the hard-rule list (catalog keys, ICU, allowlist, fallback, edge formatting, RTL, escaping) this pattern implements.
- `<rules-path>/reporting-export-discipline.md` — the SAME edge-formatting + timezone-correct-boundary discipline for money/dates in reports and exports.
- `<patterns-path>/payment-integration.md § Money` — integer-minor-unit money type the currency formatters render.
- `<rules-path>/content-escaping.md` — user-generated-content escaping; translations are the same untrusted-input class.
- `<commands-path>/scan-i18n-coverage.md` — coverage / hardcoded-string diagnostic that finds violations of this pattern.
- `<agents-path>/i18n-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-i18n-locale-strategy.md` — ADR pinning the supported-locale allowlist, fallback chain, missing-key policy, and ICU library choice.
