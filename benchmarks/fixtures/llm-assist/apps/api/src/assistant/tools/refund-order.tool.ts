import { EntityManager } from '@mikro-orm/postgresql';
import { Order } from '../../orders/order.entity';
import { PaymentsClient } from '../../orders/payments.client';
import type { TurnInput } from '../assistant.use-case';

interface RefundArgs {
  orderNumber: string;
  amountMinor: number;
  approved?: boolean;
}

export async function refundOrder(em: EntityManager, payments: PaymentsClient, args: RefundArgs, ctx: TurnInput): Promise<string> {
  if (!args.approved) {
    return JSON.stringify({ error: 'Ask the customer to confirm, then call refund_order again with approved=true.' });
  }
  const order = await em.findOneOrFail(Order, { tenantId: ctx.tenantId, number: args.orderNumber });
  const refund = await payments.refund(order.paymentIntentId, args.amountMinor, `refund:${order.id}:${args.amountMinor}`);
  order.status = 'refunded';
  await em.flush();
  return JSON.stringify({ refundId: refund.id, status: refund.status });
}
