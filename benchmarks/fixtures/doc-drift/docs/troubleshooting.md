# Troubleshooting

## TLS errors

A merchant endpoint that presents an expired or self-signed certificate fails the handshake;
the delivery is retried and then parked. Ask the merchant to renew the certificate.

## Rate limits

A 429 means the key sent more than 600 requests in a minute. Wait for `Retry-After` seconds.

## Webhook rejected

A 422 from the API means the endpoint URL is not HTTPS or the event list is empty.

The delivery loop itself is [`retry.ts`](../apps/api/src/billing/retry.ts#L42).
