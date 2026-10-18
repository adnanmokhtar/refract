# Seeded defects — `web-dashboard`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first.

Fixture shape: a React + TypeScript operations dashboard whose conventions are written
down in `ai/conventions.md` and followed by most of the tree. 14 drift items seeded across
layering, design tokens, i18n, a11y, error handling, permissions, and naming, with 7 decoys.
Primary target command: **`/align`**.

What makes this fixture fair rather than arbitrary: **every seeded item has a
gold-standard sibling in the same repo.** `useCustomers.ts` is the correct data hook next
to the drifted `useOrders.ts`; `OrdersToolbar.tsx` is the correct presentational component
next to `orderstable.tsx`; `ui/Modal.tsx` is the shared dialog next to the hand-rolled one
in `OrderDetailPanel.tsx`. `/align` enforces *existing* conventions, so a fixture with no
established convention would be measuring the wrong thing.

`bucket:` is each row's disposition under the batch-6 align class map (`eval-batch6-align.md` § 2): `report-with-fix`
(align closes it with the named proof), `report-flagged` (a human, a visible change or a missing hook decides; never
auto-fixed), or `routed` (the owning pack's audit grades it, and align prints the owner line). The rows keep `command: /align`
so earlier results stay comparable; the routed ones score under their owner in the align-owned successor fixture,
`convention-drift`. The seven decoys at the end are known-correct siblings: reporting one is a false positive.

Line numbers are exact and re-checked by `benchmarks/run.sh --verify`.

## Summary

| id | file:line | severity | command | class | bucket |
|----|-----------|----------|---------|-------|--------|
| WEB-LAYER-01 | `src/components/orders/orderstable.tsx:2` | high | `/align` | layer-violation | routed |
| WEB-IO-02 | `src/components/orders/orderstable.tsx:16` | high | `/align` | unhandled-io | routed |
| WEB-I18N-01 | `src/components/orders/orderstable.tsx:22` | medium | `/align` | i18n-drift | report-with-fix |
| WEB-I18N-02 | `src/components/orders/orderstable.tsx:8` | low | `/align` | i18n-drift | routed |
| WEB-TOKEN-02 | `src/components/orders/orderstable.tsx:39` | low | `/align` | design-token-drift | report-flagged |
| WEB-TOKEN-01 | `src/components/orders/orderstable.tsx:42` | medium | `/align` | design-token-drift | report-with-fix |
| WEB-A11Y-01 | `src/components/orders/orderstable.tsx:50` | medium | `/align` | a11y | routed |
| WEB-PERM-01 | `src/components/orders/orderstable.tsx:53` | high | `/align` | permission-gate-drop | report-with-fix |
| WEB-NAME-01 | `src/components/orders/orderstable.tsx:11` | low | `/align` | naming-convention | report-with-fix |
| WEB-IMPORT-01 | `src/components/orders/OrderDetailPanel.tsx:16` | high | `/align` | forbidden-import | report-flagged |
| WEB-IO-01 | `src/components/orders/OrderDetailPanel.tsx:18` | high | `/align` | unhandled-io | routed |
| WEB-WRAP-01 | `src/components/orders/OrderDetailPanel.tsx:30` | medium | `/align` | reinvented-wrapper | report-flagged |
| WEB-CATCH-01 | `src/hooks/useOrders.ts:24` | high | `/align` | silent-catch | routed |
| WEB-A11Y-02 | `src/components/customers/CustomerCard.tsx:18` | medium | `/align` | a11y | routed |

Severity split: 0 critical · 6 high · 5 medium · 3 low.

---

## WEB-LAYER-01 — Component imports the API client directly

```defect
id:       WEB-LAYER-01
file:     src/components/orders/orderstable.tsx
line:     2
severity: high
command:  /align
class:    layer-violation
bucket:   routed — AL-20, owner code-quality architectural-diagnosis §1; no hook exposes the refund call, so there is no mechanical re-route for align to close
anchor:   import { del } from '../../lib/api-client';
match:    layer|layering|api.?client|direct.{0,20}(import|call|access)|bypass|should (use|go through).{0,20}hook|data access|architectur.{0,20}(violat|boundar)
```

`ai/conventions.md` states components go through a hook in `src/hooks/` and never import
`src/lib/api-client.ts`. This component imports `del` and calls it from an event handler.
Every other component in the tree gets its data from a hook.

## WEB-IO-02 — Refund call has no error path

```defect
id:       WEB-IO-02
file:     src/components/orders/orderstable.tsx
line:     16
severity: high
command:  /align
class:    unhandled-io
bucket:   routed — code-quality error-handling-scan; not an align class
anchor:   await del(`/orders/${order.id}/charge`);
match:    unhandled|no (error|failure) (path|handling|state)|happy.?path|(missing|without).{0,15}(catch|try|error)|unhandled (promise )?rejection|reject.{0,20}(unhandled|silent)|user (sees|gets) no
```

`refund()` awaits a network call with no `try`/`catch`. A rejection leaves `busyId` pinned
so the row stays disabled forever, and the user is told nothing. The convention requires
every failure to surface.

## WEB-I18N-01 — Hardcoded empty-state copy

```defect
id:       WEB-I18N-01
file:     src/components/orders/orderstable.tsx
line:     22
severity: medium
command:  /align
class:    i18n-drift
bucket:   report-with-fix — AL-26 EQ key: `orders.empty` equals the literal (P-31); owner frontend i18n-scan §1, closer align (V405)
anchor:   >No orders match this filter</p>
match:    i18n|internationali|localis|localiz|hard.?cod.{0,25}(string|text|copy|label)|literal (string|copy|text)|\bt\(\)|translation
```

The literal `No orders match this filter` is rendered directly. The catalogue already has
`orders.empty` with exactly this text (`src/lib/i18n.ts:6`), and every other string in the
file goes through `t()`.

## WEB-I18N-02 — Currency symbol hardcoded in the formatter

```defect
id:       WEB-I18N-02
file:     src/components/orders/orderstable.tsx
line:     8
severity: low
command:  /align
class:    i18n-drift
bucket:   routed — AL-26 new copy: no catalog value equals it; frontend i18n-scan §1 → /frontend-fix
anchor:   return `£${(cents / 100).toFixed(2)}`;
match:    currenc|locale|hard.?cod.{0,20}(symbol|£|currency)|Intl\.NumberFormat|formatMoney|money format
```

`formatMoney` hardcodes `£`. Amounts are per-order and the API returns cents without a
currency code, so the symbol is a locale assumption baked into a leaf helper rather than
resolved through the i18n layer.

## WEB-TOKEN-02 — Off-scale pixel padding

```defect
id:       WEB-TOKEN-02
file:     src/components/orders/orderstable.tsx
line:     39
severity: low
command:  /align
class:    design-token-drift
bucket:   report-flagged — AL-06: 13px equals only `--font-size-sm`, a cross-family match (P-27); snapping to a space token is a visible change, never auto-fixed (V407)
anchor:   padding: '13px'
match:    (design )?token|hard.?cod.{0,20}(px|pixel|spacing|padding|value)|magic (number|value)|spacing scale|--space|literal.{0,15}(px|pixel)
```

`13px` is not on the 4px scale and does not correspond to any token. Every sibling cell in
the same table uses `var(--space-3)`.

## WEB-TOKEN-01 — Hardcoded hex where a token exists

```defect
id:       WEB-TOKEN-01
file:     src/components/orders/orderstable.tsx
line:     42
severity: medium
command:  /align
class:    design-token-drift
bucket:   report-with-fix — AL-05 EQ: `#d92d20` = `--color-danger`, one candidate; owner ui-ux design-token-audit, closer align (V397)
anchor:   '#d92d20'
match:    (design )?token|hard.?cod.{0,20}(colou?r|hex|value)|hex|literal colou?r|--color|var\(--
```

`#d92d20` is byte-identical to `--color-danger` in `src/styles/tokens.css:9`. The same
ternary uses `var(--color-text-muted)` for its other branch, so the drift is one literal
in an otherwise tokenised expression.

## WEB-A11Y-01 — Icon-only button with no accessible name

```defect
id:       WEB-A11Y-01
file:     src/components/orders/orderstable.tsx
line:     50
severity: medium
command:  /align
class:    a11y
bucket:   routed — AL-28, frontend a11y-code-scan: a native button, so there is no wrapper prop for align to set
anchor:   <button type="button" onClick={() => refund(order)} disabled={busyId === order.id}>
match:    a11y|accessib|aria.?label|accessible name|screen.?reader|icon.?only|no (label|name)
```

The button's only content is the glyph `↩`, and it carries no `aria-label`. `OrdersToolbar`
labels its equivalent icon-only control, and `ui/Modal.tsx` labels its close button, so the
convention is live in the codebase.

## WEB-PERM-01 — Destructive action rendered ungated

```defect
id:       WEB-PERM-01
file:     src/components/orders/orderstable.tsx
line:     53
severity: high
command:  /align
class:    permission-gate-drop
bucket:   report-with-fix — AL-15 FN: `add-gate` with `<Can action="orders.refund">` (V401)
anchor:   <Button variant="danger" onClick={() => refund(order)}>
match:    permission|authoriz|\bCan\b|gate|ungated|role|entitle|can.?perform|destructive.{0,25}(action|button)
```

Refund is destructive and money-moving, and it is rendered for every user. `OrdersToolbar`
wraps the far less sensitive export action in `<Can action="orders.export">`. Neither
refund affordance in this file (the icon button or the labelled one) is gated.

## WEB-NAME-01 — Component file is not PascalCase

```defect
id:       WEB-NAME-01
file:     src/components/orders/orderstable.tsx
line:     11
severity: low
command:  /align
class:    naming-convention
bucket:   report-with-fix — AL-16 `rename`: `orderstable.tsx` → `OrdersTable.tsx` (V402)
anchor:   export function OrdersTable({ orders, onChanged }
match:    (file|module).{0,20}nam|naming convention|PascalCase|camelCase|kebab|rename|case.{0,15}(mismatch|convention)|filename
```

The file is `orderstable.tsx` while the exported component is `OrdersTable`. The
convention is that a component file's name matches its export exactly; every other
component file in the tree does.

## WEB-IMPORT-01 — Raw `fetch` outside the API client

```defect
id:       WEB-IMPORT-01
file:     src/components/orders/OrderDetailPanel.tsx
line:     16
severity: high
command:  /align
class:    forbidden-import
bucket:   report-flagged — AL-11: the convention routes data through a hook that does not exist yet, and the client adds auth and a base URL, so the fix is not a swap
anchor:   fetch(`/api/orders/${orderId}`)
match:    raw fetch|direct.{0,15}fetch|fetch.{0,25}(directly|outside|in (the )?component)|api.?client|http client|bypass|forbidden import|should (use|go through)
```

The component calls `fetch` itself, so this request gets no bearer token, no base URL
resolution and no `ApiError` normalisation — all three of which `src/lib/api-client.ts`
provides and is the sole permitted place to construct a request. It also hardcodes the
`/api` prefix that the client derives from configuration.

## WEB-IO-01 — Detail fetch has no error or failure state

```defect
id:       WEB-IO-01
file:     src/components/orders/OrderDetailPanel.tsx
line:     18
severity: high
command:  /align
class:    unhandled-io
bucket:   routed — code-quality error-handling-scan; not an align class
anchor:   .then((json) => setDetail(json));
match:    (no|missing|without).{0,20}(catch|error (state|handling|path))|happy.?path|unhandled|error state|three states|loading.{0,15}(and|,).{0,15}error|infinite.{0,15}(loading|spinner)
```

There is no `.catch`, no `error` state and no distinction between "still loading" and
"failed". On any failure `detail` stays `null` and the panel renders the loading copy
forever. `useCustomers` + `CustomersList` show the required `{ data, loading, error }`
triple two directories away.

## WEB-WRAP-01 — Hand-rolled dialog instead of the shared `Modal`

```defect
id:       WEB-WRAP-01
file:     src/components/orders/OrderDetailPanel.tsx
line:     30
severity: medium
command:  /align
class:    reinvented-wrapper
bucket:   report-flagged — AL-12, owner ui-ux design-token-audit §6: `Modal` adds role, focus and Escape handling, a behavioural and visible change, not EQ
anchor:   background: 'rgba(16, 24, 40, 0.6)',
match:    reinvent|re.?implement|duplicat|shared (component|primitive|wrapper)|existing.{0,20}(Modal|component|primitive)|\bModal\b|dialog|roll(ed)? (its )?own|custom.{0,20}(modal|dialog|overlay)
```

The panel rebuilds the overlay, the centring and the close button that `ui/Modal.tsx`
already provides, and loses what the shared one adds: `role="dialog"`, `aria-modal`, the
accessible name, Escape-to-close and initial focus. The overlay's `onClick` handler also
sits on a plain `div` with no keyboard equivalent — a symptom of the same reimplementation.

## WEB-CATCH-01 — Hook swallows load failures

```defect
id:       WEB-CATCH-01
file:     src/hooks/useOrders.ts
line:     24
severity: high
command:  /align
class:    silent-catch
bucket:   routed — code-quality error-handling-scan; not an align class
anchor:   .catch(() => {
match:    silent(ly)? (catch|swallow|ignor)|swallow|empty catch|discard.{0,15}error|error.{0,25}(never|not) (set|surfaced|shown|propagat)|catch.{0,25}(ignores|drops)|dead (state|variable)
```

`useOrders` declares `error` state and returns it, but the `catch` sets an empty array
instead of the error, so `error` is permanently `null` and a failed load is
indistinguishable from an empty result. `useCustomers` — the same hook shape, same file
layout — calls `setError(err as Error)`.

## WEB-A11Y-02 — Avatar image has no `alt`

```defect
id:       WEB-A11Y-02
file:     src/components/customers/CustomerCard.tsx
line:     18
severity: medium
command:  /align
class:    a11y
bucket:   routed — AL-28, frontend a11y-code-scan: `customers.avatarAlt` exists; /frontend-fix
anchor:   src={customer.avatarUrl}
match:    a11y|accessib|\balt\b|alt (text|attribute)|screen.?reader|image.{0,20}(descript|label)
```

The `<img>` has no `alt`. The decorative placeholder in the same ternary is correctly
marked `aria-hidden="true"`, and the catalogue already carries `customers.avatarAlt` for
exactly this element — so both halves of the fix already exist in the repo.

## Decoys — must NOT be reported

Each is a known-correct sibling of a seed above. The eval also asked for a decorative `alt=""` image; the tree has none (its
decorative placeholder is the `aria-hidden` div in `CustomerCard.tsx`, 7 lines from WEB-A11Y-02, inside its scoring window), so
the two gated / labelled siblings in `OrdersToolbar.tsx` stand in for it.

```decoy
id:       WEB-DECOY-01
file:     src/styles/tokens.css
line:     9
command:  /align
class:    decoy/design-token-drift (P-04)
anchor:   --color-danger: #d92d20;
match:    #d92d20|hard.?cod|hex|literal
```

The token definition itself: the source of `--color-danger`, not a literal that should use it.

```decoy
id:       WEB-DECOY-02
file:     src/styles/tokens.css
line:     26
command:  /align
class:    decoy/design-token-drift (P-04, P-27)
anchor:   --font-size-sm: 13px;
match:    13px|font-size-sm|hard.?cod|px
```

The definition WEB-TOKEN-02 matches across families. It is a font-size token; nothing about it is drift.

```decoy
id:       WEB-DECOY-03
file:     src/components/ui/Button.tsx
line:     25
command:  /align
class:    decoy/design-token-drift (P-05)
anchor:   border: '1px solid var(--color-border)',
match:    1px|hairline|border|hard.?cod|px
```

A 1px hairline: the token set has no border-width family, so `1px` is a value tokens do not cover by design.

```decoy
id:       WEB-DECOY-04
file:     src/components/ui/Modal.tsx
line:     37
command:  /align
class:    decoy/reinvented-wrapper (P-08)
anchor:   background: 'rgba(16, 24, 40, 0.6)',
match:    rgba|overlay|reinvent|hard.?cod|Modal
```

The shared `Modal` itself. Its overlay literal is the wrapper's own implementation; WEB-WRAP-01 is the copy of it, not this.

```decoy
id:       WEB-DECOY-05
file:     src/hooks/useCustomers.ts
line:     26
command:  /align
class:    decoy/silent-catch (correct sibling)
anchor:   if (!cancelled) setError(err as Error);
match:    swallow|silent|catch|setError
```

The reference data hook surfaces the error; WEB-CATCH-01 is its drifted twin.

```decoy
id:       WEB-DECOY-06
file:     src/components/orders/OrdersToolbar.tsx
line:     37
command:  /align
class:    decoy/a11y (correct sibling)
anchor:   <button type="button" aria-label={t('common.retry')} onClick={() => onQueryChange('')}>
match:    aria-label|accessible name|icon.?only|a11y
```

An icon-only button with its accessible name: the correct sibling of WEB-A11Y-01.

```decoy
id:       WEB-DECOY-07
file:     src/components/orders/OrdersToolbar.tsx
line:     40
command:  /align
class:    decoy/permission-gate-drop (correct sibling)
anchor:   <Can action="orders.export">
match:    \bCan\b|permission|gate|ungated
```

The gated action WEB-PERM-01 should look like.
