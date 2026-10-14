import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class PriceSyncService {
  async applySurcharges(tx: EntityManager): Promise<void> {
    await tx.execute(`UPDATE rate_cards SET bands = apply_fuel_surcharge(bands, (SELECT pct FROM carrier_surcharges ORDER BY effective_from DESC LIMIT 1))`);
  }
}
