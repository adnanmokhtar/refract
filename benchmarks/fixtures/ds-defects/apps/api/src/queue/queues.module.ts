import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { BullMQOtel } from 'bullmq-otel';
import { redisConnection } from '../redis/jobs-redis';

export const QUEUES = ['receipts', 'orders', 'sms', 'invoices', 'carrier-sync', 'geocode', 'reports', 'customs-docs', 'telemetry'] as const;

@Module({
  imports: [
    // Every queue of the job Redis propagates trace context through job options (bullmq-otel).
    BullModule.forRoot({ connection: redisConnection(), telemetry: new BullMQOtel('fulfilment-api') }),
    BullModule.registerQueue(...QUEUES.map((name) => ({ name }))),
  ],
  exports: [BullModule],
})
export class QueuesModule {}
