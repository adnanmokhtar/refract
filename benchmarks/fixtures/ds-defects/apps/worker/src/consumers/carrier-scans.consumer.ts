import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';

const CarrierScan = z.object({
  scanId: z.string(),
  trackingNo: z.string(),
  status: z.enum(['picked_up', 'in_transit', 'out_for_delivery', 'delivered', 'exception']),
  at: z.string().datetime(),
});

/** Carrier scans relayed by the carrier gateway (topic carrier.scans). */
@Injectable()
export class CarrierScansConsumer implements OnModuleInit {
  constructor(private readonly em: EntityManager) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-carrier-scans' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['carrier.scans'] });
    await consumer.run({
      eachMessage: async ({ topic, message }) => {
        const raw: unknown = JSON.parse(message.value?.toString() ?? 'null');
        const parsed = CarrierScan.safeParse(raw);
        if (!parsed.success) return deadLetter(topic, message, parsed.error);
        await this.em.fork().getConnection().execute(
          'INSERT INTO carrier_scans (scan_id, tracking_no, status, scanned_at) VALUES (?, ?, ?, ?) ON CONFLICT (scan_id) DO NOTHING',
          [parsed.data.scanId, parsed.data.trackingNo, parsed.data.status, parsed.data.at],
        );
      },
    });
  }
}
