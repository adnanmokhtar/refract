import { ForbiddenException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { EntitlementsService } from '../entitlements/entitlements.service';

@Injectable()
export class GiftCardsService {
  constructor(
    private readonly em: EntityManager,
    private readonly entitlements: EntitlementsService,
  ) {}

  list(tenantId: string) {
    return this.em.find('GiftCard', { tenant: tenantId });
  }

  async issue(tenantId: string, body: { amountCents: number; email: string }) {
    if (!(await this.entitlements.hasFeature(tenantId, 'giftcards'))) {
      throw new ForbiddenException({ code: 'EXTENSION_NOT_PURCHASED', key: 'gift_cards' });
    }
    const card = this.em.create('GiftCard', { tenant: tenantId, ...body });
    await this.em.persistAndFlush(card);
    return card;
  }
}
