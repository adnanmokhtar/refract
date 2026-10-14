import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { notifyConnection } from '../redis/notify-redis';
import { NotificationProducer } from './notification.producer';

@Module({
  imports: [
    BullModule.forRoot('notify', {
      connection: notifyConnection(),
      defaultJobOptions: { attempts: 4, backoff: { type: 'exponential', delay: 5_000 }, removeOnComplete: 10_000 },
    }),
    BullModule.registerQueue({ name: 'push', configKey: 'notify' }),
  ],
  providers: [NotificationProducer],
  exports: [NotificationProducer],
})
export class NotificationsModule {}
