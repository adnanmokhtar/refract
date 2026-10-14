import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';
import { RedisLease } from '../locks/redis-lease';

const CodCollected = z.object({ collectionId: z.string(), merchantId: z.string(), amountMinor: z.number().int(), currency: z.string() });

/**
 * Credits merchants' COD balances from courier collections (topic cod.collected). Only one replica may credit at
 * a time: the settlement lease serialises the batch against the nightly payout export, which reads the balances.
 */
@Injectable()
export class CodSettlementConsumer implements OnModuleInit {
  constructor(
    private readonly em: EntityManager,
    private readonly settlementLease: RedisLease,
  ) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-cod-settlement' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['cod.collected'] });
    await consumer.run({
      eachBatch: async ({ batch, resolveOffset, heartbeat }) => {
        if (!(await this.settlementLease.acquire('lease:cod-balances', 20_000))) return;
        for (const message of batch.messages) {
          await this.settlementLease.extend();
          const parsed = CodCollected.safeParse(JSON.parse(message.value?.toString() ?? 'null'));
          if (!parsed.success) {
            await deadLetter(batch.topic, message, parsed.error);
          } else {
            await this.em.fork().getConnection().execute(
              'UPDATE merchant_balances SET cod_minor = cod_minor + ? WHERE merchant_id = ? AND currency = ?',
              [parsed.data.amountMinor, parsed.data.merchantId, parsed.data.currency],
            );
          }
          resolveOffset(message.offset);
          await heartbeat();
        }
      },
    });
  }
}
