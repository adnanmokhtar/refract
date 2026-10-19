# HTTP API

The base URL is `https://api.example.com/v1`. Every request carries an API key in the
`Authorization: Bearer <key>` header. Clients usually keep the key and the base URL together:

```json
{
  "apiKey": "<your-api-key>",
  "baseUrl": "https://api.example.com/v1"
}
```

Responses are JSON unless the table says otherwise. Amounts are integer minor units; currencies
are ISO 4217 codes. Errors carry a `code` and a link to the page that explains it.

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/orders` | List orders, newest first (`cursor`, `limit`). |
| `POST` | `/orders` | Create an order. |
| `GET` | `/orders/{id}` | Fetch one order. |
| `POST` | `/orders/{id}/cancel` | Cancel an unpaid order. |
| `GET` | `/orders/export` | Export every order as CSV. |
| `GET` | `/invoices/{id}` | Fetch an invoice. |
| `GET` | `/invoices/{id}/pdf` | Download the invoice PDF. |
| `GET` | `/reports/monthly` | Monthly totals per currency. |
| `GET` | `/webhooks/endpoints` | List webhook endpoints. |
| `POST` | `/webhooks/endpoints` | Register a webhook endpoint. |

## Voiding an order

To void an order that was paid by mistake, call `POST /orders/{id}/void` with the order id; the
order moves to the voided state and its invoice gets a credit note.

## Daily totals

`GET /reports/daily` returns yesterday's totals per currency, computed at the nightly cut-off.

## Retries

Webhook deliveries are retried with exponential backoff. The delay before attempt `n` is:

```ts
// apps/api/src/billing/retry.ts#L5-L12
export function backoffMs(attempt: number): number {
  return 1000 * 2 ** attempt;
}
```

A delivery is parked after the number of attempts the `RETRY_LIMIT` setting allows.

## Rate limits

Each API key may send 600 requests per minute. A request over the limit gets a 429 with a
`Retry-After` header in seconds.

## Metrics

`GET /metrics` serves Prometheus metrics for the cluster's scraper. It sits outside the `/v1`
prefix and is not part of the public spec.
