import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import type { CreateOrderBodyT } from '@norrow/contracts';
import type { AuthUser } from '../common/current-user.decorator';
import { roundHalfAway, toMoneyString } from '../common/money';
import { StockReservationService } from '../inventory/stock-reservation.service';
import { Account } from '../users/account.entity';
import { OrderLine } from './order-line.entity';
import { Order } from './order.entity';
import { lineNet } from './pricing';

@Injectable()
export class OrderPlacementService {
  constructor(private readonly em: EntityManager, private readonly stock: StockReservationService) {}

  async place(body: CreateOrderBodyT, user: AuthUser): Promise<Order> {
    return this.em.transactional(async (em) => {
      const order = em.create(Order, {
        account: em.getReference(Account, user.accountId),
        number: await this.nextNumber(em),
        status: 'placed',
        poNumber: body.po_number ?? null,
        notes: body.notes ?? null,
        customerEmail: user.email,
        ...(body.currency ? { currency: body.currency } : {}),
      });

      let total = 0;
      for (const line of body.lines) {
        await this.stock.reserve(em, line.sku, line.quantity);
        const net = lineNet(line.unit_price, line.quantity, line.discount_rate ?? null);
        em.create(OrderLine, { order, sku: line.sku, quantity: line.quantity, unitPrice: toMoneyString(line.unit_price), discountRate: line.discount_rate?.toString() ?? null, netAmount: toMoneyString(net) });
        total += net;
      }

      order.totalAmount = toMoneyString(roundHalfAway(total, 2));
      return order;
    });
  }

  private async nextNumber(em: EntityManager): Promise<string> {
    const [{ next }] = await em.getConnection().execute<{ next: number }[]>("select nextval('order_number_seq') as next");
    return `SO-${String(next).padStart(7, '0')}`;
  }
}
