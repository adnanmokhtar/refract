# @tallyhook/sdk

TypeScript client for the Tallyhook invoicing API. Node 22 or later.

## Install

```bash
pnpm add @tallyhook/sdk
```

## Quick start

```ts
import { createOrderClient } from '@tallyhook/sdk';

const client = createOrderClient({ apiKey: process.env.TALLYHOOK_API_KEY ?? '' });
const order = await client.orders.get('ord_8f2k');
```

## Listing orders

```ts
import { createClient } from '@tallyhook/sdk';

const client = createClient({ apiKey: process.env.TALLYHOOK_API_KEY ?? '' });
const page = await client.orders.list(50, true);
```

Call `client.orders.getOrders()` to fetch the most recent orders in one call.

## Retries

Retries are configured in `packages/sdk/src/retry-policy.ts`; a GET is retried up to four times on
a 5xx answer.

## Webhooks

`verifyWebhookSignature(payload, header, secret)` checks the `Tallyhook-Signature` header of a
delivery against your endpoint secret.

## Upgrading from 1.x

The 2.0 release renamed the client factory and moved every call under a resource. Read the
[migration notes](https://sdk-archive.tallyhook.invalid/migrate-1x) before upgrading.
