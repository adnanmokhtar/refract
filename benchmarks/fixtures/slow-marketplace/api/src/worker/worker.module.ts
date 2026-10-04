import { Module } from '@nestjs/common';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { Queue } from 'bullmq';
import ormConfig from '../config/mikro-orm.config';
import { OutboxRelay } from '../outbox/outbox-relay';
import { PayoutLedgerService } from '../payouts/payout-ledger.service';
import { WebhookRetryPoller } from '../webhooks/webhook-retry.poller';
import { WebhookSender } from '../webhooks/webhook-sender';

@Module({
  imports: [MikroOrmModule.forRoot(ormConfig)],
  providers: [
    OutboxRelay,
    WebhookRetryPoller,
    WebhookSender,
    PayoutLedgerService,
    {
      provide: Queue,
      useFactory: () => new Queue('events', { connection: { url: process.env.REDIS_URL ?? 'redis://localhost:6379' } }),
    },
  ],
})
export class WorkerModule {}
