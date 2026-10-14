import { Injectable } from '@nestjs/common';
import { EntityManager, Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { ApplyRateCardDto } from './dto/apply-rate-card.dto';

@Entity({ tableName: 'rate_cards' })
export class RateCard {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property({ type: 'decimal', precision: 8, scale: 4 })
  rate!: string;
}

@Injectable()
export class ApplyRateCardUseCase {
  constructor(private readonly em: EntityManager) {}

  /** POST /v1/pricing/rate-cards/apply — the rate card id comes from the request body. */
  async execute(dto: ApplyRateCardDto): Promise<{ rate: string }> {
    const card = await this.em.findOneOrFail(RateCard, { id: dto.rateCardId });
    return { rate: card.rate };
  }
}
