---
name: multi-channel-notify
description: "Pattern: Multi-channel notification dispatch"
kind: ai-pattern
---

# Pattern: Multi-channel notification dispatch

> **Hard rule** — `NotificationService.send()` is the ONLY entry point; preference + suppression + rate-limit middleware run before any provider call; transactional and marketing traffic use SEPARATE ESPs / IP pools / domains. No `import { ses }` outside `infrastructure/providers/`.

**When to apply**
- Multi-channel product (email + SMS + push + in-app + WhatsApp) where users control preferences.
- Marketing + transactional traffic share a codebase but must NOT share deliverability reputation.
- Compliance regimes (CAN-SPAM / TCPA / GDPR) that require opt-out, suppression, and unsub headers.

**When NOT to apply**
- Single-channel transactional-only flows (one ESP, no marketing) — simpler direct path with idempotency.
- Internal alerts to ops chat — go straight to PagerDuty/Slack; no preference logic.
- Critical security events that MUST bypass preferences (password reset) — document explicitly, never auto-fallback marketing.

**Halt conditions / mandatory cites**
- Cite the `NotificationService.send()` entry point + its preference/suppression/rate-limit middleware at `<path:line>`. Direct provider calls in feature code = halt.
- Cite separated ESP routing (transactional vs marketing) at `<path:line>`. One ESP for all = deliverability halt.
- Cite the `List-Unsubscribe` header + suppression list write on hard bounce at `<path:line>`. Missing = halt.
- Cite the webhook signature verification (SES/SNS, Twilio, FCM) at `<path:line>`. Unverified webhooks = halt.
- Grep ban: "we send notifications" without file:line for entry point, preferences, suppression, rate limit, and provider webhook verifier.

Single send API → routes to channels based on user preference + notification type → per-channel adapter handles provider specifics → preference / dedup / rate-limit middleware fail-closed → providers separated by category for deliverability.

## Decision summary

`NotificationService.send(notification)` is the ONE entry point. It:
1. Looks up user preferences for `(category, channel)`.
2. Filters channels the user opted out of.
3. Applies suppression list (bounced / complained / unsubscribed).
4. Applies rate limits (per user, per channel, per 24h; per tenant per day).
5. Enqueues one job per surviving channel.
6. Workers call channel adapters; adapters call providers; updates persist.

No producer ever talks to a provider directly.

## File layout

```
src/notifications/
├── core/
│   ├── notification.entity.ts            # row in `notifications` table
│   ├── notification-category.enum.ts     # transactional / account / marketing / operational
│   ├── notification-channel.enum.ts      # email / sms / push / inapp / whatsapp
│   ├── notification-preference.entity.ts
│   └── suppression.entity.ts
├── application/
│   ├── notification.service.ts           # the single entry point
│   ├── render-template.service.ts
│   └── middleware/
│       ├── preference.middleware.ts
│       ├── suppression.middleware.ts
│       └── rate-limit.middleware.ts
└── infrastructure/
    ├── channels/
    │   ├── email.channel.ts
    │   ├── sms.channel.ts
    │   ├── push.channel.ts
    │   ├── inapp.channel.ts
    │   └── whatsapp.channel.ts
    ├── providers/
    │   ├── ses.provider.ts
    │   ├── mailgun.provider.ts            # marketing — different IP pool
    │   ├── twilio.provider.ts
    │   ├── fcm.provider.ts
    │   └── whatsapp-cloud.provider.ts
    ├── workers/
    │   └── send-notification.worker.ts
    └── webhooks/
        ├── ses-events.controller.ts       # SNS → bounce/complaint/delivery
        ├── twilio-status.controller.ts
        └── ...
```

## Notification entity

```ts
@Entity('notifications')
export class NotificationEntity {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column() userId: string;
  @Column() tenantId: string;
  @Column({ type: 'enum', enum: NotificationCategory }) category: NotificationCategory;
  @Column({ type: 'enum', enum: NotificationChannel }) channel: NotificationChannel;
  @Column() template: string;              // 'order-confirmation'
  @Column({ type: 'jsonb' }) data: Record<string, unknown>;

  @Column() provider: string;              // 'ses' | 'twilio' | 'fcm' | ...
  @Column({ nullable: true }) providerMessageId: string | null;

  @Column({ type: 'enum', enum: NotificationStatus, default: 'queued' })
  status: 'queued' | 'sent' | 'delivered' | 'failed' | 'bounced' | 'suppressed';

  @Column({ nullable: true }) failureReason: string | null;
  @CreateDateColumn() createdAt: Date;
  @Column({ nullable: true }) sentAt: Date | null;
  @Column({ nullable: true }) deliveredAt: Date | null;

  @Index('idx_notif_lookup', ['userId', 'category', 'createdAt'])
  @Index('idx_notif_provider_msg', ['providerMessageId'])
}
```

## NotificationService — the entry point

```ts
@Injectable()
export class NotificationService {
  constructor(
    private readonly preferences: PreferenceMiddleware,
    private readonly suppression: SuppressionMiddleware,
    private readonly rateLimit: RateLimitMiddleware,
    private readonly notifications: NotificationRepository,
    @Inject('NOTIFICATION_QUEUE') private readonly queue: Queue,
    private readonly logger: Logger,
  ) {}

  async send(input: SendNotificationInput): Promise<SendResult> {
    const { userId, tenantId, category, template, data, channels: requested } = input;

    // 1. resolve user-allowed channels
    const allowed = await this.preferences.filter(userId, category, requested);
    if (allowed.length === 0) {
      this.logger.info({ userId, category, template }, 'notif.skipped.preferences');
      return { status: 'skipped', reason: 'preferences' };
    }

    // 2. suppression
    const survived = await this.suppression.filter(userId, allowed);

    // 3. rate limits
    const final = await this.rateLimit.filter(userId, tenantId, category, survived);
    if (final.length === 0) {
      return { status: 'skipped', reason: 'rate_limit' };
    }

    // 4. persist + enqueue per channel
    const jobs = await Promise.all(
      final.map(async (channel) => {
        const notification = await this.notifications.create({
          userId, tenantId, category, channel, template, data,
          provider: providerFor(channel, category),
          status: 'queued',
        });
        await this.queue.add('send', { notificationId: notification.id }, {
          jobId: `notif:${notification.id}`,
          attempts: 5,
          backoff: { type: 'exponential', delay: 2000 },
          removeOnFail: false,
        });
        return notification.id;
      }),
    );

    return { status: 'queued', notificationIds: jobs };
  }
}
```

## Channel adapter (uniform interface)

```ts
export interface NotificationChannelAdapter {
  send(notification: NotificationEntity, rendered: RenderedTemplate): Promise<{ providerMessageId: string }>;
}

@Injectable()
export class EmailChannel implements NotificationChannelAdapter {
  constructor(
    @Inject('TRANSACTIONAL_PROVIDER') private readonly transactional: EmailProvider,  // SES
    @Inject('MARKETING_PROVIDER') private readonly marketing: EmailProvider,          // Mailgun
  ) {}

  async send(n: NotificationEntity, rendered: RenderedTemplate) {
    const provider = n.category === NotificationCategory.Marketing
      ? this.marketing
      : this.transactional;

    return provider.send({
      to: rendered.to,
      from: provider.senderForCategory(n.category),
      subject: rendered.subject,
      html: rendered.html,
      text: rendered.text,
      headers: {
        'List-Unsubscribe': `<${rendered.unsubscribeUrl}>, <mailto:${UNSUB_MAILBOX}?subject=unsub-${n.id}>`,
        'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
      },
      idempotencyKey: n.id,
    });
  }
}
```

`providerFor(channel, category)` is the routing table — transactional email → SES, marketing email → Mailgun. Hard-coded, not per-tenant.

## Worker

```ts
export class SendNotificationWorker {
  private worker: Worker;

  constructor(
    private readonly notifications: NotificationRepository,
    private readonly channels: Map<NotificationChannel, NotificationChannelAdapter>,
    private readonly renderer: RenderTemplateService,
    private readonly logger: Logger,
  ) {
    this.worker = new Worker('notifications', async (job) => {
      const n = await this.notifications.findById(job.data.notificationId);
      if (!n) throw new UnrecoverableError(`notification ${job.data.notificationId} gone`);
      if (n.status !== 'queued') return;   // idempotent

      const adapter = this.channels.get(n.channel);
      if (!adapter) throw new UnrecoverableError(`no adapter for ${n.channel}`);

      const rendered = await this.renderer.render(n);
      try {
        const { providerMessageId } = await adapter.send(n, rendered);
        await this.notifications.markSent(n.id, providerMessageId);
        this.logger.info({ notifId: n.id, channel: n.channel, providerMessageId }, 'notif.sent');
      } catch (err) {
        if (isPermanent(err)) {
          await this.notifications.markFailed(n.id, err.message);
          throw new UnrecoverableError(err.message);
        }
        throw err;   // retry
      }
    }, { connection: queueConnection, concurrency: 50 });
  }
}
```

## Push payload — PII safety

```ts
@Injectable()
export class PushChannel implements NotificationChannelAdapter {
  async send(n: NotificationEntity, rendered: RenderedTemplate) {
    // Body and title scrubbed of PII at template level.
    // Real data ships in `data` payload; app fetches authenticated detail on tap.
    return this.fcm.send({
      token: rendered.deviceToken,
      notification: {
        title: rendered.title,    // 'Your order shipped'   — NOT 'Order #1247'
        body:  rendered.body,     // 'Tap to track'         — NOT '742 Evergreen Terrace'
      },
      data: {
        type: rendered.deepLinkType,
        entityId: n.data.entityId as string,    // opaque ID, fetched after auth
        notificationId: n.id,
      },
      android: { priority: 'high' },
      apns: { payload: { aps: { 'mutable-content': 1 } } },
    });
  }
}
```

## Provider webhook ingestion (status updates)

```ts
@Controller('webhooks/ses')
export class SesEventsController {
  @Post()
  async handle(@Body() event: SnsMessage) {
    const verified = await this.snsVerifier.verify(event);
    if (!verified) throw new UnauthorizedException();

    for (const notification of event.notifications) {
      const messageId = notification.mail.messageId;
      const found = await this.notifications.findByProviderMessageId(messageId);
      if (!found) continue;

      switch (notification.notificationType) {
        case 'Delivery':  return this.notifications.markDelivered(found.id);
        case 'Bounce':    return this.handleBounce(found, notification);
        case 'Complaint': return this.handleComplaint(found, notification);
      }
    }
  }

  private async handleBounce(n: NotificationEntity, event: SesBounceEvent) {
    if (event.bounce.bounceType === 'Permanent') {
      await this.suppression.add(n.userId, NotificationChannel.Email, 'hard_bounce');
    }
    await this.notifications.markBounced(n.id, event.bounce.bounceSubType);
  }
}
```

## Channel-fallback strategy (critical only)

```ts
// for password-reset / security-alert types, NotificationService can wait for
// the email send and, if it bounces within 30s, dispatch SMS as fallback.
async sendCritical(input: SendCriticalInput) {
  const result = await this.send({ ...input, channels: ['email'] });
  if (result.status === 'queued') {
    // listener on bounce: re-dispatch as SMS
    this.eventBus.once(`notif.bounced.${result.notificationIds[0]}`, () =>
      this.send({ ...input, channels: ['sms'] }),
    );
  }
}
```

NEVER for marketing — auto-fallback marketing across channels = TCPA violation.

## Common mistakes

- **Direct provider import in feature code** — `import { ses } from 'aws-sdk'` outside `infrastructure/providers/`. Bypasses preferences.
- **One ESP for everything** — first marketing complaint suspends transactional sends. Separate ESP / domain / IP pool.
- **No `List-Unsubscribe` header** — Gmail spam-folders you, then blocks you. Add the header even if your footer link is prominent.
- **PII in push body** — order numbers, amounts, addresses on lock screen. Strip at template level.
- **Sync send from controller** — controller waits 800ms for SES. Outage → 504 → user retries → duplicate orders. Always enqueue.
- **Idempotency key = `Date.now()` or random** — defeats provider-side dedup; retries cause duplicate delivery.
- **No suppression check** — re-mailing a hard bounce 5 attempts × N campaigns → ESP marks you as a spammer.
- **Webhook handler not signature-verified** — anyone can mark all your bounces as "delivered". Verify SNS / Twilio / Firebase signatures.
- **Marketing classified as transactional** to bypass opt-out — fraud, fines, brand damage.
- **Localized fallback to English** — German user gets English email when DE template missing. Worse UX than not sending; fail-closed instead.
- **Rate limit per process, not per user** — runaway loop sends 50k emails to one user before the per-process counter saves you. Limit per (userId, channel, window).
