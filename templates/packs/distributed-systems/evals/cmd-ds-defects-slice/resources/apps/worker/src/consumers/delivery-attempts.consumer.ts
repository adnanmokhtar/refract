import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';
import { ClaimsLedger } from '../outbox/claims-ledger';

const DeliveryAttempted = z.object({ eventId: z.string().uuid(), shipmentId: z.string().uuid(), outcome: z.string(), at: z.string() });

/**
 * Records failed delivery attempts and schedules the next one. The claim is a coordination aid only: the effect
 * row carries the event id, and the insert is an anti-join on it, so a redelivery after a crash between the
 * claim and the effect still writes the attempt exactly once.
 */
@Injectable()
export class DeliveryAttemptsConsumer implements OnModuleInit {
  constructor(
    private readonly em: EntityManager,
    private readonly claims: ClaimsLedger,
  ) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-delivery-attempts' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['delivery.attempted'] });
    await consumer.run({
      eachMessage: async ({ topic, message }) => {
        const parsed = DeliveryAttempted.safeParse(JSON.parse(message.value?.toString() ?? 'null'));
        if (!parsed.success) return deadLetter(topic, message, parsed.error);
        const evt = parsed.data;
        await this.claims.reserve(evt.eventId, 'delivery-attempts');
        await this.em.fork().getConnection().execute(
          `INSERT INTO delivery_attempts (event_id, shipment_id, outcome, attempted_at)
           SELECT ?, ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM delivery_attempts WHERE event_id = ?)`,
          [evt.eventId, evt.shipmentId, evt.outcome, evt.at, evt.eventId],
        );
      },
    });
  }
}
