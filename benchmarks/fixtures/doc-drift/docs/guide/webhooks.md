# Webhooks

Tallyhook sends an HTTP POST to each registered endpoint when an order is paid or an invoice is
issued. Every delivery is signed, and a delivery that fails is retried with backoff.

## The signing secret

Set the `WEBHOOK_SIGNING_KEY` environment variable to the secret shown when you register the
endpoint; the API signs every delivery with it.

## Verifying a delivery

The receiver recomputes the signature from the raw body and the timestamp in the header:

--8<-- "examples/verify-signature.ts"

The `Tallyhook-Signature` header carries `t=<unix seconds>,v1=<hex HMAC-SHA256>`, the scheme of
the [Payrail signature reference](https://docs.payrail.invalid/webhooks/signatures), which the
SDK's `verifyWebhookSignature` implements.

## Retries

A delivery that does not get a 2xx answer within ten seconds is retried with exponential backoff
and jitter, and parked after the last attempt.
