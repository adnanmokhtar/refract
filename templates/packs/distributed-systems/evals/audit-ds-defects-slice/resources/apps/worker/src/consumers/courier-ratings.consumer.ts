import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';

const CourierRated = z.object({ eventId: z.string().uuid(), courierId: z.string().uuid(), stars: z.number().int().min(1).max(5) });

/**
 * Stores customer ratings of couriers. courier_ratings.event_id is UNIQUE: the rating row IS the reserve, written
 * in the same statement as the effect.
 */
@Injectable()
export class CourierRatingsConsumer implements OnModuleInit {
  constructor(private readonly em: EntityManager) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-courier-ratings' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['courier.rated'] });
    await consumer.run({
      eachMessage: async ({ topic, message }) => {
        const parsed = CourierRated.safeParse(JSON.parse(message.value?.toString() ?? 'null'));
        if (!parsed.success) return deadLetter(topic, message, parsed.error);
        await this.em.fork().getConnection().execute(
          'INSERT INTO courier_ratings (event_id, courier_id, stars) VALUES (?, ?, ?) ON CONFLICT (event_id) DO NOTHING',
          [parsed.data.eventId, parsed.data.courierId, parsed.data.stars],
        );
      },
    });
  }
}
