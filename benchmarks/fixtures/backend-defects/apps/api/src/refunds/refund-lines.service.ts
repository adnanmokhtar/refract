import { BadRequestException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';

export interface RefundLineRequest {
  sku: string;
  quantity: number;
}

@Injectable()
export class RefundLinesService {
  constructor(private readonly em: EntityManager) {}

  /** A customer may refund each purchased line up to the quantity bought. */
  async validate(orderId: string, lines: RefundLineRequest[]): Promise<void> {
    const bought = await this.em.getConnection().execute('select sku, quantity from order_lines where order_id = ?', [orderId]);
    const qtyBySku = new Map<string, number>(bought.map((r: { sku: string; quantity: number }) => [r.sku, r.quantity]));
    for (const line of lines) {
      if (line.quantity > (qtyBySku.get(line.sku) ?? 0)) {
        throw new BadRequestException(`refund quantity for ${line.sku} exceeds purchase`);
      }
    }
  }
}
