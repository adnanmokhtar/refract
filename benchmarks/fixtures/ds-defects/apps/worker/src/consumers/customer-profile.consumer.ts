import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';
import { CustomerProfile } from './entities/customer-profile.entity';

const ProfileChanged = z.object({
  customerId: z.string(),
  email: z.string().email(),
  phone: z.string(),
  updatedAt: z.coerce.date(),
  source: z.enum(['merchant-console', 'notify-preferences']),
});

/**
 * Two services publish customer.profile-changed: the merchant console (apps/api) and notify-dotnet's preference
 * centre. Each stamps updatedAt from its own host clock.
 */
@Injectable()
export class CustomerProfileConsumer implements OnModuleInit {
  constructor(private readonly em: EntityManager) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-customer-profile' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['customer.profile-changed'] });
    await consumer.run({
      eachMessage: async ({ topic, message }) => {
        const parsed = ProfileChanged.safeParse(JSON.parse(message.value?.toString() ?? 'null'));
        if (!parsed.success) return deadLetter(topic, message, parsed.error);
        const incoming = parsed.data;
        const em = this.em.fork();
        const row = await em.findOne(CustomerProfile, incoming.customerId);
        if (!row) {
          em.create(CustomerProfile, { id: incoming.customerId, email: incoming.email, phone: incoming.phone, updatedAt: incoming.updatedAt });
        } else if (incoming.updatedAt > row.updatedAt) {
          em.assign(row, { email: incoming.email, phone: incoming.phone, updatedAt: incoming.updatedAt });
        }
        await em.flush();
      },
    });
  }
}
