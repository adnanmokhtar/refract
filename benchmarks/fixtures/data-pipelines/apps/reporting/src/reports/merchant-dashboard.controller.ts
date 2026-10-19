import { Controller, Get, Param } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Controller('merchants/:merchantId/dashboard')
export class MerchantDashboardController {
  constructor(private readonly em: EntityManager) {}

  @Get()
  async dashboard(@Param('merchantId') merchantId: string) {
    const [snapshot] = await this.em.getConnection().execute(
      `select balance_cents, period_end from merchant_snapshots where merchant_id = ? order by period_end desc limit 1`,
      [merchantId],
    );
    return {
      currentBalanceCents: snapshot.balance_cents,
      title: 'Your balance right now',
    };
  }
}
