import { Global, Module } from '@nestjs/common';
import { OutboxService } from './outbox.service';
import { OUTBOX_PORT } from './outbox.port';
import { OutboxRelay } from './outbox.relay';
import { LiveUpdatesRelay } from './live-updates.relay';
import { TxRunner } from './tx-runner';

@Global()
@Module({
  providers: [
    TxRunner,
    OutboxService,
    { provide: OUTBOX_PORT, useExisting: OutboxService },
    OutboxRelay,
    LiveUpdatesRelay,
  ],
  exports: [OUTBOX_PORT, TxRunner],
})
export class OutboxModule {}
