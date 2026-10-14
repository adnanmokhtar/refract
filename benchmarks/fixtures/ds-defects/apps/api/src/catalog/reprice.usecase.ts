import { Inject, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Producer } from 'kafkajs';
import { KAFKA_PRODUCER } from '../kafka/kafka.module';
import { RateCard } from './rate-card.entity';

/**
 * Asks the quoting service to refresh its cached quotes for a merchant. The message is an intent, not a fact:
 * the quoting service re-reads the merchant's active rate card from GET /rate-cards/:merchantId before it
 * recomputes (services/quoting README, "refresh semantics"), so an intent for a change that rolled back only
 * causes a no-op refresh.
 */
@Injectable()
export class Reprice {
  constructor(
    private readonly em: EntityManager,
    @Inject(KAFKA_PRODUCER) private readonly kafka: Producer,
  ) {}

  async execute(merchantId: string, card: Partial<RateCard>): Promise<void> {
    const current = await this.em.findOneOrFail(RateCard, { merchantId, active: true });
    await this.kafka.send({ topic: 'quotes.refresh-requested', messages: [{ key: merchantId, value: JSON.stringify({ merchantId }) }] });
    this.em.assign(current, card);
    await this.em.flush();
  }
}
