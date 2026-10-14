import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';

const InvoiceChange = z.object({
  op: z.enum(['c', 'u', 'd', 'r']),
  after: z.object({ id: z.string(), merchant_id: z.string(), status: z.string(), total_minor: z.number() }).nullable(),
});

/** Debezium change stream of billing's invoices table (deploy/debezium/invoices-cdc-connector.json). */
@Injectable()
export class BillingCdcConsumer implements OnModuleInit {
  constructor(private readonly em: EntityManager) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-billing-cdc' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['dbserver1.public.billing_invoice'] });
    await consumer.run({
      eachMessage: async ({ topic, message }) => {
        const change = InvoiceChange.safeParse(JSON.parse(message.value!.toString()).payload);
        if (!change.success) return deadLetter(topic, message, change.error);
        if (!change.data.after) return;
        const a = change.data.after;
        await this.em.fork().getConnection().execute(
          'INSERT INTO worker_invoices (id, merchant_id, status, total_minor) VALUES (?, ?, ?, ?) ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, total_minor = EXCLUDED.total_minor',
          [a.id, a.merchant_id, a.status, a.total_minor],
        );
      },
    });
  }
}
