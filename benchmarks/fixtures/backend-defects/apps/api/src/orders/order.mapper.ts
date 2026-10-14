import { Order } from './order.entity';

export interface OrderDto {
  id: string;
  status: string;
  total: number;
  currency: string;
  createdAt: string;
}

/** Order → response body. Every orders route returns this shape. */
export function toOrderDto(order: Order): OrderDto {
  return {
    id: order.id,
    status: order.status,
    total: Number(order.totalAmount),
    currency: order.currency,
    createdAt: order.createdAt.toISOString(),
  };
}
