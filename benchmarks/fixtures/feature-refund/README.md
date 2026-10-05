# orders-backoffice

The back office merchants' support agents use to look after their customers' orders. One process
serves many merchants (tenants); every request names its tenant in the `x-tenant-id` header.

Plain Node (≥ 18), no dependencies, nothing to install.

```
npm test            # node --test (discovers tests/*.test.js)
```

## Layout

| Path | What |
|---|---|
| `src/app.js` | the edge: resolves the tenant from `x-tenant-id`, matches the route table, maps `HttpError` to a status |
| `src/routes.js` | the route table — every endpoint and page is one `{ method, path, handler }` row |
| `src/orders.js` | order lifecycle and the order endpoints |
| `src/pages.js` | the HTML pages (server-rendered strings from `web/`) |
| `src/store.js` | the in-memory store, keyed by tenant |
| `src/ledger.js` | the money ledger — every money movement is one entry |
| `src/money.js` | the `Money` type and its formatting |
| `src/tenancy.js` | loading a record on behalf of the request's tenant |
| `src/idempotency.js` | `Idempotency-Key` handling for write endpoints |
| `web/` | render functions returning HTML strings; `web/components/` holds the shared pieces |
| `ai/` | project knowledge: the business domain and the conventions every change follows |
