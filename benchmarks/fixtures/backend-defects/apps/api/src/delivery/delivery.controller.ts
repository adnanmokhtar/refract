import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { BulkStatusDto } from './dto/bulk-status.dto';

@Controller('delivery')
export class DeliveryController {
  constructor(private readonly em: EntityManager) {}

  /** Carrier callback: move many orders to one delivery status. */
  @Post('bulk-status')
  @HttpCode(200)
  async bulkStatus(@Body() dto: BulkStatusDto): Promise<{ updated: number }> {
    const ids = dto.orders.map((o) => o.orderId);
    const rows = await this.em.getConnection().execute('update shipments set status = ? where order_id = any(?)', [dto.status, ids]);
    return { updated: rows.length };
  }
}
