# Business domain

**Who uses it.** Support agents at our merchants. Each merchant is a **tenant**; an agent only ever
sees and acts on their own merchant's orders. The tenant comes from the `x-tenant-id` header, set by
the gateway after login — handlers never take a tenant id from a path, a query or a body.

**Orders.** An order is placed `pending`, becomes `paid` when the payment provider confirms the
charge, and can be `cancelled` while it is still `pending` (nothing was charged, so nothing moves).
Shipments are attached as the warehouse sends parcels.

| Status | Means | Reachable from |
|---|---|---|
| `pending` | placed, not paid | — |
| `paid` | the customer was charged the order total | `pending` |
| `cancelled` | withdrawn before payment | `pending` |

**The ledger.** Every movement of money is one entry in the tenant's ledger (`src/ledger.js`):
`{ type, orderId, amount: Money, … }`. Today the only entry type is `charge`, written when an order is
paid. The ledger is what finance reconciles against the payment provider every night, so an amount
that is off by a cent, or an entry written twice, is a reconciliation break someone has to chase by
hand.

**Money.** Prices and totals are `Money` values — an integer number of minor units (cents) and an ISO
currency code. Merchants sell in EUR, GBP and USD.
