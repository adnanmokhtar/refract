# State matrix — checkout and refunds

Written at design time for the checkout rework (storefront) and the refund drawer (back office), before either was
built. The rows below are the contract the acceptance tests and the UX review are held to.

## State matrix

Surfaces:
- `checkout-page` — apps/shop/app/[locale]/checkout/page.tsx, apps/shop/components/checkout
- `refund-form` — apps/admin/src/components/RefundForm.vue, apps/admin/src/components/RefundDrawer.vue

| Surface | State | Source | Expected (message · action · focus) | Proof |
|---|---|---|---|---|
| checkout-page | loading | AC-001 | summary skeleton with role=status "Loading…" · — · focus stays on the email field | apps/shop/e2e/checkout-states.spec.ts::shows a skeleton while the cart loads |
| checkout-page | empty | AC-002 | "Shop the autumn edit" link in place of the summary · follow the link · — | apps/shop/e2e/checkout-states.spec.ts::empty cart offers a way back to the shop |
| checkout-page | error | AC-003 | "Something went wrong" · Try again, or back to the cart · focus moves to the alert heading | apps/shop/e2e/checkout-states.spec.ts::shows retry on 500 |
| checkout-page | partial | n-a | n-a | — |
| checkout-page | permission | AC-004 | 401 → /sign-in?returnTo=/checkout · sign in · focus lands on the email field | apps/shop/components/checkout/CheckoutSummary.stories.tsx#SignedOut |
| checkout-page | stale | AC-005 | summary stays visible during a refetch; "Prices may have changed" when the refetch fails · Refresh · — | apps/shop/components/checkout/CheckoutSummary.stories.tsx#Stale |
| checkout-page | pending-submit | AC-006 | "Placing order…" · button disabled · inputs kept on a 500 | apps/shop/components/checkout/PlaceOrderButton.tsx |
| checkout-page | validation | AC-007 | email error after blur, described by the field · fix the field · focus to the first invalid field | apps/shop/components/checkout/ContactForm.stories.tsx#InvalidEmail |
| refund-form | loading | n-a | n-a — the form renders from the order already on screen; nothing is fetched | — |
| refund-form | empty | n-a | n-a — a refund always belongs to exactly one open order | — |
| refund-form | error | AC-011 | "Refund failed — nothing was charged back" · Retry · focus on the alert | apps/admin/e2e/refund-states.spec.ts::refund 500 keeps the inputs |
| refund-form | partial | n-a | n-a — one request creates the refund; there is no second part to fail | — |
| refund-form | offline | AC-012 | "You're offline — the refund was not sent" · Retry when back online · — | apps/admin/e2e/orders-states.spec.ts::offline refund is rejected with a message |
| refund-form | stale | n-a | n-a — not needed | — |
| refund-form | pending-submit | AC-013 | "Refunding…" · submit disabled · inputs kept on a 500 | apps/admin/src/components/RefundForm.vue |
| refund-form | validation | AC-014 | amount error after blur, described by the field · fix the amount · focus to the amount | apps/admin/e2e/orders-states.spec.ts::refund amount over the total is rejected |
| refund-form | destructive-confirm | AC-015 | "Refund €X to the customer? This cannot be undone." · Confirm / Cancel · focus on Cancel | apps/admin/e2e/orders-states.spec.ts::refund asks for confirmation |

## Notes

- Copy follows the storefront's existing error and empty copy (`messages/en.json`, `common.*`).
- The refund drawer is staff-only; every role that can open it can refund.
