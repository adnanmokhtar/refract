import { Controller, Get, Param } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { NotFoundError } from '../common/errors';

@Controller('receipts')
export class ReceiptsController {
  constructor(private readonly em: EntityManager) {}

  /** Receipt view; every view is recorded in the compliance audit trail (who saw which receipt). */
  @Get(':id')
  async view(@CurrentUser() user: Principal, @Param('id') id: string): Promise<unknown> {
    const [receipt] = await this.em.getConnection().execute('select * from receipts where id = ? and tenant_id = ?', [id, user.tenantId]);
    if (!receipt) throw new NotFoundError('Receipt', id);
    await this.em.getConnection().execute('insert into receipt_views (receipt_id, user_id, viewed_at) values (?, ?, now())', [id, user.userId]);
    return receipt;
  }
}
