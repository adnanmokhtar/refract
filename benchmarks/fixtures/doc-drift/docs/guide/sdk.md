# SDK

The TypeScript client wraps the HTTP API: authentication, retries for idempotent requests and
typed responses.

## A first call

```ts
import { createClient } from '@tallyhook/sdk';

const client = createClient({ apiKey: process.env.TALLYHOOK_API_KEY ?? '' });
// ...
const first = await client.orders.list({ limit: 50 });
```

Each page carries `nextCursor`; pass it back as `cursor` to read the next page.

## Errors

A request that fails with a 4xx is not retried: the error carries the status and the code. A GET
that fails with a 5xx is retried with backoff before the error reaches you.

Back to the [home page](index.md).
