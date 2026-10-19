import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import Redis from 'ioredis';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';

const ManifestClosed = z.object({ manifestId: z.string().uuid(), parcels: z.number().int() });

/**
 * When a manifest closes, the dock gets one loading task per manifest. The processed-event key in Redis keeps a
 * redelivered manifest.closed from opening a second task.
 */
@Injectable()
export class FulfilmentTasksConsumer implements OnModuleInit {
  private readonly redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');

  constructor(private readonly em: EntityManager) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-fulfilment-tasks' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['manifest.closed'] });
    await consumer.run({
      eachMessage: async ({ topic, message }) => {
        const parsed = ManifestClosed.safeParse(JSON.parse(message.value?.toString() ?? 'null'));
        if (!parsed.success) return deadLetter(topic, message, parsed.error);
        const eventId = message.headers?.['event-id']?.toString() ?? '';
        const fresh = await this.redis.set(`processed:manifest-closed:${eventId}`, '1', 'EX', 86_400, 'NX');
        if (!fresh) return;
        await this.em.fork().getConnection().execute(
          'INSERT INTO dock_tasks (manifest_id, kind, parcels) VALUES (?, ?, ?)',
          [parsed.data.manifestId, 'load', parsed.data.parcels],
        );
      },
    });
  }
}
