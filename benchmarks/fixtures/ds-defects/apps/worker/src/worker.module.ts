import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { BullMQOtel } from 'bullmq-otel';
import { MikroOrmModule } from '@mikro-orm/nestjs';

@Module({
  imports: [
    MikroOrmModule.forRoot(),
    BullModule.forRoot({
      connection: { host: new URL(process.env.REDIS_URL ?? 'redis://localhost:6379').hostname, port: 6379, maxRetriesPerRequest: null },
      telemetry: new BullMQOtel('fulfilment-worker'),
    }),
  ],
})
export class WorkerModule {}
