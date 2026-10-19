import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';
import { ProcessedEvent } from './entities/processed-event.entity';

const InvoiceVoided = z.object({ invoiceId: z.string().uuid(), reason: z.string() });

/** Mirrors voided invoices into the merchant console's invoice list (worker_invoices). */
@Injectable()
export class InvoiceMirrorConsumer implements OnModuleInit {
  constructor(private readonly em: EntityManager) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-invoice-mirror' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['invoice.voided'] });
    await consumer.run({
      eachMessage: async ({ topic, message }) => {
        const parsed = InvoiceVoided.safeParse(JSON.parse(message.value?.toString() ?? 'null'));
        if (!parsed.success) return deadLetter(topic, message, parsed.error);
        const eventId = message.headers?.['event-id']?.toString() ?? '';
        const em = this.em.fork();
        const seen = await em.findOne(ProcessedEvent, { eventId });
        if (seen) return;
        await em.getConnection().execute('UPDATE worker_invoices SET status = ?, void_count = void_count + 1 WHERE id = ?', ['void', parsed.data.invoiceId]);
        em.create(ProcessedEvent, { eventId });
        await em.flush();
      },
    });
  }
}
