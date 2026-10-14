import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';

const ReturnApproved = z.object({ returnId: z.string().uuid(), carrier: z.string() });

/** Books the return pickup once a return is approved. */
@Injectable()
export class ReturnsApprovedConsumer implements OnModuleInit {
  constructor(private readonly em: EntityManager) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-returns-approved' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['returns.approved'] });
    await consumer.run({
      eachMessage: async ({ topic, message }) => {
        const parsed = ReturnApproved.safeParse(JSON.parse(message.value?.toString() ?? 'null'));
        if (!parsed.success) return deadLetter(topic, message, parsed.error);
        await this.em.fork().getConnection().execute(
          'INSERT INTO return_pickups (return_id, carrier) VALUES (?, ?) ON CONFLICT (return_id) DO NOTHING',
          [parsed.data.returnId, parsed.data.carrier],
        );
      },
    });
  }
}
