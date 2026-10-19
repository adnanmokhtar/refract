import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';
import { Shipment } from './entities/shipment.entity';

const ShipmentCreated = z.object({ shipmentId: z.string().uuid(), orderId: z.string().uuid(), carrier: z.string() });

/**
 * Mirrors shipment.created into the worker's shipments table. kafkajs commits the offset when eachMessage
 * resolves; the handler awaits every write before it returns.
 */
@Injectable()
export class ShipmentsConsumer implements OnModuleInit {
  constructor(private readonly em: EntityManager) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-shipments' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['shipment.created'] });
    await consumer.run({
      eachMessage: async ({ topic, message }) => {
        const parsed = ShipmentCreated.safeParse(JSON.parse(message.value?.toString() ?? 'null'));
        if (!parsed.success) {
          await deadLetter(topic, message, parsed.error);
          return;
        }
        await this.mirror(parsed.data);
      },
    });
  }

  private async mirror(evt: z.infer<typeof ShipmentCreated>): Promise<void> {
    const em = this.em.fork();
    // Upsert by the business key: a redelivered event rewrites the same row with the same values.
    await em.upsert(Shipment, { id: evt.shipmentId, orderId: evt.orderId, carrier: evt.carrier });
  }
}
