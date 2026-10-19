import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { FxService } from '../fx/fx.service';

/** Group revenue in USD for the investor update: every store's revenue converted to dollars. */
@Injectable()
export class RevenueUsdReport {
  constructor(private readonly em: EntityManager, private readonly fx: FxService) {}

  async run(from: Date, to: Date): Promise<number> {
    const rows: { currency: string; total_minor: number }[] = await this.em.getConnection().execute(
      `select o.currency, o.total_minor from orders o
        where o.paid_at >= ? and o.paid_at < ? and o.status <> 'cancelled' and o.livemode`,
      [from, to],
    );
    let usdMinor = 0;
    for (const row of rows) {
      usdMinor += await this.fx.convertAmount(row.total_minor, row.currency, 'USD');
    }
    return usdMinor;
  }
}
