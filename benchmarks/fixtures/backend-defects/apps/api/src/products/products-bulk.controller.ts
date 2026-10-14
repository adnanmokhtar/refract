import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { ArrayMaxSize, IsDecimal, IsUUID, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { EntityManager } from '@mikro-orm/core';

export class PriceChangeDto {
  @IsUUID()
  productId!: string;

  @IsDecimal({ decimal_digits: '0,2' })
  price!: string;
}

export class BulkPriceDto {
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => PriceChangeDto)
  changes!: PriceChangeDto[];
}

@Controller('products')
export class ProductsBulkController {
  constructor(private readonly em: EntityManager) {}

  /** openapi: 207 with results[i] aligned to changes[i]; each item succeeds or fails on its own. */
  @Post('bulk-price')
  @HttpCode(207)
  async bulkPrice(@Body() dto: BulkPriceDto): Promise<{ results: { index: number; status: number }[] }> {
    const settled = await Promise.allSettled(
      dto.changes.map((c) => this.em.getConnection().execute('update products set price = ? where id = ?', [c.price, c.productId])),
    );
    return { results: settled.map((s, index) => ({ index, status: s.status === 'fulfilled' ? 200 : 409 })) };
  }
}
