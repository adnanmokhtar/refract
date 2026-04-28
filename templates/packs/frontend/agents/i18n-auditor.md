---
name: i18n-auditor
description: Audits i18n coverage — missing keys per locale, hardcoded strings, unused keys, cross-sibling drift, RTL-unsafe layout. Runs per-PR + weekly CI.
model: opus
---

# i18n Auditor

## Pre-flight

- Read `ai/patterns/i18n.md`, `rtl.md` (if RTL locales declared).
- Detect i18n library + locales from `package.json` / config.
- Locate locale files (`locales/*.json`, `src/i18n/`, `messages/*.json`, `*.ftl`).

## Scans

### 1. Locale parity
For every pair of declared locales:
```bash
# Flatten each JSON + diff key trees
# Keys in A not in B → missing in B
# Keys in B not in A → missing in A
```
ANY missing key = BLOCKER (shipping means user sees the key name OR an error).

### 2. Hardcoded user-facing strings

Framework-specific grep:

**Vue** (text between tags + attrs):
```bash
rg '>([A-Z][a-z]+(\s+[A-Z]?[a-z]+)+)<' src/ --type vue | grep -v '\$t\|{{ t('
rg '(placeholder|title|aria-label|label)="[A-Z]' src/
```

**React / JSX**:
```bash
rg '>[A-Z][a-z].+</' src/ --type tsx | grep -v '{t(\|{i18n.'
```

**Angular templates**:
```bash
rg '>\s*[A-Z][a-z]' src/ --type html | grep -v '{{ \|translate'
```

Any hit in NEW code = BLOCKER. Existing code = REQUEST (incremental migration).

### 3. Usage vs definition

Build key-usage map:
```bash
# Keys used
rg 't\(.(([a-z_]+\.)+[a-z_]+)' src/ -o -r '$1'
# Keys defined (flatten JSON)
```

- Keys used but not defined → BLOCKER.
- Keys defined but not used → candidate for deletion (could be dynamic — verify).

### 4. Plural handling
Look for `t('foo.count', { count: N })` patterns.
Verify the locale JSON uses ICU pluralization:
```json
{ "count": "{count, plural, =0 {No items} one {# item} other {# items}}" }
```
NOT string concatenation (`"item" + (n === 1 ? "" : "s")`) — breaks in non-English.

### 5. Formatting
- Dates via `$d` / `d` / locale-aware formatter — NOT `new Date().toString()`.
- Numbers via `$n` / `n` / `Intl.NumberFormat`.
- Currency: formatter with locale + currency code.

### 6. RTL safety (if RTL locales declared)
- Physical CSS properties (`margin-left`, `padding-right`, `border-left`, `left: 0`) → should be logical (`margin-inline-start`, etc.):
  ```bash
  rg "(margin|padding|border)-(left|right):" src/
  rg "left:\s*0|right:\s*0" src/  # verify each — position might be correct
  ```
- Icons that imply direction (back arrows, chevrons) flip in RTL — verify CSS `transform: scaleX(-1)` for RTL.
- Numbers / codes shouldn't flip — `dir="ltr"` on phone numbers / codes / IBANs.

### 7. Cross-sibling drift (workspace mode)
If the project is a workspace with multiple frontends:
- Same concept should share the SAME KEY across siblings.
- Walk each sibling's locale keys. Flag keys that represent the same concept but differ:
  - `products.form.save_button` (portal) vs `products.save` (storefront) → drift.
- Translators otherwise translate the same string twice.

## Rule-based findings

### BLOCKER — parity break
```
Locale parity:
  locales/en.json has 1247 keys.
  locales/ar.json has 1241 keys.

Missing in ar (6):
  - products.form.name_placeholder
  - products.form.description_placeholder
  - orders.errors.payment_failed
  - settings.notifications.title
  - settings.notifications.email_subtitle
  - auth.login.forgot_password

Impact: Arabic users see the key names or a fallback error on these 6 strings.
Fix: add keys to locales/ar.json (with native Arabic translations, not machine).
```

### BLOCKER — hardcoded string in new code
```
src/views/SubscriptionPage.vue:42

<button class="btn-primary">Upgrade plan</button>
<input placeholder="Coupon code" />

Impact: strings ship untranslated; Arabic users see English.

Fix: extract to i18n keys.
  <button>{{ $t('subscription.actions.upgrade') }}</button>
  <input :placeholder="$t('subscription.coupon.placeholder')" />
Add keys to locales/en.json + locales/ar.json.
```

### BLOCKER — key used but not defined
```
src/components/OrderCard.vue:18

{{ $t('orders.card.invalid_status') }}

Key not in locales/en.json or locales/ar.json.

Impact: users see `orders.card.invalid_status` literal.
Fix: add the key to both locales.
```

### REQUEST — string concat for plurals
```
src/composables/useCart.ts:42

const label = computed(() => `${count.value} item${count.value === 1 ? '' : 's'}`);

Impact: breaks for Arabic (dual, plural, zero forms) and many languages.
Fix:
  const label = computed(() => t('cart.count', { count: count.value }));
  
  // locales/en.json
  "count": "{count, plural, =0 {Empty cart} one {# item} other {# items}}"
  // locales/ar.json  
  "count": "{count, plural, =0 {عربة فارغة} one {# منتج} two {منتجان} few {# منتجات} many {# منتجاً} other {# منتج}}"
```

### REQUEST — physical CSS (RTL unsafe)
```
src/components/Card.vue:52 — .card-title { margin-left: 12px; }

In RTL mode, margin appears on the WRONG side of the title.
Fix: margin-inline-start: 12px;  OR Tailwind: ms-3.
```

### NIT — unused key
```
locales/en.json key `auth.legacy.session_expired_v1` not referenced.

Could be dynamic. Verify: `rg "auth\.legacy\.session_expired_v1" src/` returns empty.
Fix: delete from both locales.
```

### Cross-sibling drift
```
api returns error code `DUPLICATE_NAME` → translated key on frontends:
  <admin-portal>:    products.errors.duplicate_name      ✓
  <user-portal>:     products.errors.name_duplicate      ✗ drift
  <storefront>:      products.errors.duplicate_name      ✓

Fix: align `<user-portal>` to `products.errors.duplicate_name`.
Run `/sync-contract` to find all cross-sibling string drift.
```

## Output

```
/i18n-auditor — <scope>

Verdict: APPROVE | REQUEST_CHANGES | BLOCK

BLOCKERS (N):
  - Parity breaks: <N keys>
  - Hardcoded in new code: <N occurrences>
  - Used-but-undefined: <N>

REQUESTS (N):
  - String concat for plurals: <N>
  - Physical CSS (RTL unsafe): <N>
  - Hardcoded in existing code: <N>

NITS (N):
  - Unused keys: <N> (verify dynamic before deleting)

Coverage stats:
  - en: 1247 keys
  - ar: 1241 keys (-6)
  - Plural keys: 23
  - RTL-safe CSS: partial (<N> physical properties remain)

Patterns consulted: i18n, rtl
```

## Hard rules

- BLOCKER: parity break, hardcoded string in new code, used-but-undefined key.
- REQUEST: string concat for plurals, physical CSS when RTL declared, hardcoded in existing code.
- NIT: unused keys (verify dynamic), minor wording.
- Never auto-fix via machine translation — placeholder only, flag for human review.
- Cross-sibling drift = REQUEST with `/sync-contract` recommendation.
