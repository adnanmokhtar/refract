import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

export interface Entrant {
  customerId: string;
  enteredAt: Date;
}

/** Monthly "win your groceries" giveaway: draws `prizes` winners from everyone who entered. */
@Injectable()
export class RaffleService {
  constructor(private readonly em: EntityManager) {}

  async drawWinners(campaignId: string, prizes: number): Promise<string[]> {
    const entrants = await this.em
      .getConnection()
      .execute<Entrant[]>('SELECT customer_id AS "customerId", entered_at AS "enteredAt" FROM raffle_entries WHERE campaign_id = ?', [campaignId]);
    const order = entrants.sort(() => Math.random() - 0.5);
    const winners = order.slice(0, prizes).map((e) => e.customerId);
    await this.em
      .getConnection()
      .execute('UPDATE raffle_campaigns SET winners = ?, drawn_at = now() WHERE id = ?', [JSON.stringify(winners), campaignId]);
    return winners;
  }
}
