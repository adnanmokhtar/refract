---
name: payment-integration
description: Pattern: Payment integration (provider-agnostic adapter)
kind: ai-pattern
---

# Pattern: Payment integration (provider-agnostic adapter)

## Why

Payment providers are interchangeable in the abstract, deeply different in detail (Stripe ≠ Adyen ≠ Paymob). The right pattern is a SMALL adapter interface backed by a provider-specific implementation. Application code never imports `stripe` or `paymob` directly.

This isolates: idempotency contract differences, 3DS flow shape, webhook signing scheme, error code vocabulary, currency unit conventions.

## Adapter interface

```ts
// src/modules/payments/core/interfaces/payment-gateway.interface.ts

export interface PaymentGateway {
  /** Charge a payment method. Idempotent — caller's key MUST be passed through. */
  charge(input: ChargeInput): Promise<ChargeResult>;

  /** Capture a previously authorized charge. */
  capture(chargeId: string, amount: Money, idempotencyKey: string): Promise<CaptureResult>;

  /** Refund a charge fully or partially. Idempotent. */
  refund(chargeId: string, amount: Money, reason: string, idempotencyKey: string): Promise<RefundResult>;

  /** Verify a webhook signature against raw body. */
  verifyWebhook(rawBody: Buffer, signatureHeader: string): { ok: boolean; event?: WebhookEvent };
}

export type ChargeInput = {
  amount: Money;                       // { amountMinor, currency }
  paymentMethodId: string;             // provider token
  customerId?: string;                 // provider customer
  capture: 'auto' | 'manual';
  offSession: boolean;                 // subscription renewal vs. interactive
  idempotencyKey: string;
  metadata: { orderId: string; tenantId: string; correlationId: string };
};

export type ChargeResult =
  | { status: 'succeeded'; chargeId: string; networkLast4?: string }
  | { status: 'requires_action'; clientSecret: string; chargeId: string }
  | { status: 'failed'; declineCode: string; reason: string }
  | { status: 'pending'; chargeId: string };
```

Application code returns one of these four shapes. Handlers + UI deal with the discriminated union — no `stripe.PaymentIntent` types leak out.

## Money

```ts
// src/shared/money.ts

export type Currency = 'USD' | 'EUR' | 'SAR' | 'AED' | 'EGP' | 'GBP' | 'JPY' | 'KWD' | 'BHD';

const MINOR_DIGITS: Record<Currency, number> = {
  USD: 2, EUR: 2, GBP: 2, SAR: 2, AED: 2, EGP: 2,
  JPY: 0,        // yen has no minor unit
  KWD: 3, BHD: 3, // dinars have 3 minor digits
};

export class Money {
  private constructor(public readonly amountMinor: number, public readonly currency: Currency) {
    if (!Number.isInteger(amountMinor)) throw new MoneyMustBeIntegerError(amountMinor);
  }

  static of(amountMinor: number, currency: Currency): Money { return new Money(amountMinor, currency); }
  static zero(currency: Currency): Money { return new Money(0, currency); }

  /** Construct from major units (e.g., 12.34 USD). DO NOT use in arithmetic — only at parse boundary. */
  static fromMajor(amountMajor: number, currency: Currency): Money {
    const factor = 10 ** MINOR_DIGITS[currency];
    return new Money(Math.round(amountMajor * factor), currency);
  }

  add(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.amountMinor + other.amountMinor, this.currency);
  }

  subtract(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.amountMinor - other.amountMinor, this.currency);
  }

  multiply(qty: number): Money {
    if (!Number.isInteger(qty)) throw new MoneyQtyMustBeIntegerError(qty);
    return new Money(this.amountMinor * qty, this.currency);
  }

  format(locale: string): string {
    const factor = 10 ** MINOR_DIGITS[this.currency];
    return new Intl.NumberFormat(locale, {
      style: 'currency', currency: this.currency,
    }).format(this.amountMinor / factor);
  }

  private assertSameCurrency(other: Money): void {
    if (other.currency !== this.currency) throw new CurrencyMismatchError(this.currency, other.currency);
  }
}
```

Money type-tags currency. Arithmetic across currencies throws. Stored in DB as `(amount_minor INTEGER, currency CHAR(3))`. No floats.

## Charge with idempotency + 3DS

> The TypeScript example below uses NestJS-style decorators + helpers like `findOrThrow` for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the framework decorators (Express / FastAPI / Spring / etc.), the lookup-or-throw helper your repository exposes, the DI mechanism your project uses. The SHAPE — load → idempotency check → external call → record → return — is what's universal, not the specific helper names.

```ts
// src/modules/payments/core/services/payment.service.ts

@Injectable()
export class PaymentService {
  constructor(
    @Inject(PAYMENT_GATEWAY) private gateway: PaymentGateway,
    @Inject(ORDER_REPO) private orders: OrderRepository,
    @Inject(WEBHOOK_EVENTS) private webhookEvents: WebhookEventsRepo,
    private logger: Logger,
  ) {}

  async chargeOrder(orderId: string, paymentMethodId: string): Promise<ChargeResult> {
    const order = await this.orders.findOrThrow(orderId);
    if (order.isPaid()) return { status: 'succeeded', chargeId: order.chargeId! };

    // Stable key derived from business id + version. Replays return cached response.
    const idempotencyKey = `charge:${order.id}:v${order.version}`;

    const result = await this.gateway.charge({
      amount: order.total,
      paymentMethodId,
      capture: 'auto',
      offSession: false,
      idempotencyKey,
      metadata: { orderId: order.id, tenantId: order.tenantId, correlationId: this.ctx.correlationId },
    });

    switch (result.status) {
      case 'succeeded':
        await this.orders.markPaid(order.id, result.chargeId);
        return result;
      case 'requires_action':
        // 3DS / SCA — frontend completes via clientSecret
        await this.orders.markPending(order.id, result.chargeId);
        return result;
      case 'failed':
        this.logger.warn({ orderId, declineCode: result.declineCode, reason: result.reason }, 'charge_declined');
        return result;
      case 'pending':
        // async settlement (some providers); webhook will resolve
        await this.orders.markPending(order.id, result.chargeId);
        return result;
    }
  }
}
```

Error codes are PRESERVED through the adapter — UI knows whether to ask for a different card, retry later, or restart.

## Stripe adapter

```ts
// src/modules/payments/infrastructure/stripe.gateway.ts

@Injectable()
export class StripeGateway implements PaymentGateway {
  constructor(@Inject(STRIPE) private stripe: Stripe, private logger: Logger) {}

  async charge(input: ChargeInput): Promise<ChargeResult> {
    try {
      const intent = await this.stripe.paymentIntents.create(
        {
          amount:           input.amount.amountMinor,
          currency:         input.amount.currency.toLowerCase(),
          payment_method:   input.paymentMethodId,
          customer:         input.customerId,
          confirm:          true,
          off_session:      input.offSession,
          capture_method:   input.capture === 'auto' ? 'automatic' : 'manual',
          metadata:         input.metadata,
        },
        { idempotencyKey: input.idempotencyKey },
      );

      switch (intent.status) {
        case 'succeeded':
          return { status: 'succeeded', chargeId: intent.id };
        case 'requires_action':
        case 'requires_source_action':
          return { status: 'requires_action', chargeId: intent.id, clientSecret: intent.client_secret! };
        case 'requires_capture':
          return { status: 'pending', chargeId: intent.id };
        default:
          return { status: 'failed', declineCode: 'unknown_status', reason: intent.status };
      }
    } catch (err) {
      if (err instanceof Stripe.errors.StripeCardError) {
        return { status: 'failed', declineCode: err.decline_code ?? err.code ?? 'card_error', reason: err.message };
      }
      if (err instanceof Stripe.errors.StripeRateLimitError) {
        throw new ProviderRateLimitError(err.message);    // caller retries with backoff
      }
      throw err;     // non-card / non-rate errors bubble; alert + investigate
    }
  }

  async refund(chargeId: string, amount: Money, reason: string, idempotencyKey: string): Promise<RefundResult> {
    const r = await this.stripe.refunds.create(
      { payment_intent: chargeId, amount: amount.amountMinor, reason: this.mapReason(reason) },
      { idempotencyKey },
    );
    return { status: r.status as RefundStatus, refundId: r.id };
  }

  verifyWebhook(rawBody: Buffer, signatureHeader: string): { ok: boolean; event?: WebhookEvent } {
    try {
      const event = this.stripe.webhooks.constructEvent(rawBody, signatureHeader, env.STRIPE_WEBHOOK_SECRET);
      return { ok: true, event: this.mapEvent(event) };
    } catch (err) {
      this.logger.warn({ err: err.message }, 'webhook_signature_invalid');
      return { ok: false };
    }
  }
}
```

## Webhook handler (idempotent + verified)

```ts
// src/modules/webhooks/stripe.controller.ts

@Controller('/webhooks/stripe')
export class StripeWebhookController {
  constructor(
    @Inject(PAYMENT_GATEWAY) private gateway: PaymentGateway,
    @Inject(WEBHOOK_EVENTS) private events: WebhookEventsRepo,
    @Inject(QUEUE) private queue: Queue,
  ) {}

  @Post('/')
  async receive(@RawBody() raw: Buffer, @Headers('stripe-signature') sig: string) {
    const verification = this.gateway.verifyWebhook(raw, sig);
    if (!verification.ok) throw new UnauthorizedException();

    const event = verification.event!;
    const fresh = await this.events.recordOnce('stripe', event.id, event);
    if (!fresh) return { received: true };               // duplicate, already processed

    await this.queue.add('stripe-webhook', { eventId: fresh.id });
    return { received: true };                            // ack < 100ms
  }
}
```

Worker processes the job idempotently — handler logic re-runs safely because the side-effect endpoints (`orders.markPaid`, etc.) are themselves idempotent (`UPDATE WHERE status != 'paid'`).

## Refund

```ts
async refundOrder(orderId: string, amount: Money, reason: string): Promise<RefundResult> {
  const order = await this.orders.findOrThrow(orderId);
  if (!order.chargeId) throw new OrderNotChargedError(orderId);

  const refundable = order.total.subtract(order.refunded);
  if (amount.amountMinor > refundable.amountMinor) {
    throw new RefundExceedsRefundableError(refundable, amount);
  }

  const idempotencyKey = `refund:${order.id}:${order.refundCount + 1}`;
  const result = await this.gateway.refund(order.chargeId, amount, reason, idempotencyKey);

  if (result.status === 'succeeded' || result.status === 'pending') {
    await this.orders.recordRefund(order.id, amount, result.refundId, reason);
  }
  return result;
}
```

Server is the source of truth for "refundable amount" — never trust the client. Idempotency key derives from refund count, not random.

## Reconciliation (daily)

```ts
@Cron('0 3 * * *')   // 3am daily
async reconcile(): Promise<void> {
  const since = subDays(new Date(), 2);          // overlap window in case of late events
  const providerCharges = await this.gateway.listCharges(since);
  const ourCharges = await this.orders.listChargesSince(since);

  const providerMap = new Map(providerCharges.map(c => [c.id, c]));
  const ourMap      = new Map(ourCharges.map(c => [c.chargeId, c]));

  const missingInDb       = [...providerMap].filter(([id]) => !ourMap.has(id));
  const missingAtProvider = [...ourMap].filter(([id]) => !providerMap.has(id));
  const amountMismatch    = [...providerMap].filter(([id, p]) => ourMap.get(id) && ourMap.get(id)!.amountMinor !== p.amount);

  if (missingInDb.length || missingAtProvider.length || amountMismatch.length) {
    await this.alerts.send('payment-reconciliation-drift', { missingInDb, missingAtProvider, amountMismatch });
  }
}
```

Drift here is almost always a webhook miss or an operator change made through the provider dashboard. Both are bugs to fix.

## Common mistakes

### Storing PANs
"Just to display in admin." Last-4 + brand + exp from the provider response is enough.

### Double-capture
Auto-capture at charge + manual `capture()` in the success handler = double charge. Pick one capture mode and document it.

### Refund accounting drift
Refund initiated in provider dashboard → DB doesn't know → reports show order as fully paid. Block the dashboard refund route via permissions; force operators through the app's refund endpoint.

### Currency floats
`amount = order.total * 1.10` for tax → fractional cent → rounding inconsistency over millions of orders = real money. Integer minor units only.

### Lost dispute data
"Old order, customer left, deleted." → 90 days later: chargeback dispute → no shipping evidence → lose dispute → $50 fee + reputation. Retain dispute-window data even when account is "deleted" (crypto-shred PII; keep transaction records).

### Webhook double-side-effect
`charge.succeeded` retried by Stripe → email sent twice → fulfillment kicked twice. Always dedupe by `event.id` BEFORE side effects.

### Idempotency key per attempt
`idempotencyKey: uuid()` — defeats the entire mechanism. Derive from a stable business id (`charge:order_${id}:v${version}`). Same logical attempt = same key.

### Trusting amount from client
`POST /charge { amount: 1 }` for a $1000 order. Always recompute server-side from the loaded order.

### Mixed-currency arithmetic
`order.total + tip` where tip is in customer's display currency, total in store currency. Use `Money` with currency tag; arithmetic across currencies throws.

### Capture window expired
Authorize, then sit on it for 10 days, then capture. Most providers expire auths in 7 days. Either capture early or re-authorize.

### Generic error to user
"Payment failed, please try again" on a `card_declined: insufficient_funds` is hostile. Surface the provider's decline code in user-readable form.

### "Manual mark as paid" without audit
Operator override → DB shows paid, provider shows nothing → reconciliation fires alarm → operator says "I marked it manually but forgot to log it." Audit every manual override.
