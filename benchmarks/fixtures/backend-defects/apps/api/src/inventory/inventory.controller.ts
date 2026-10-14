import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';

@Controller('inventory')
export class InventoryController {
  constructor(private readonly em: EntityManager) {}

  /** Reserve one unit of a SKU for a checkout. */
  @Post('reservations')
  @HttpCode(201)
  async reserve(@Body('sku') sku: string, @Body('cartId') cartId: string): Promise<{ reserved: boolean }> {
    const rows = await this.em.getConnection().execute(
      'update stock set reserved = reserved + 1 where sku = ? and available > reserved returning sku',
      [sku],
    );
    return { reserved: rows.length > 0 && cartId.length > 0 };
  }
}
