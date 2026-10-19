import type { HttpClient } from './http.js';

/** Lifecycle of an order. */
export type OrderStatus = 'placed' | 'paid' | 'cancelled';

/** An order as the API returns it; amounts are integer minor units. */
export interface Order {
  id: string;
  status: OrderStatus;
  totalMinor: number;
  currency: string;
}

/** One page of orders and the cursor for the next one. */
export interface OrderPage {
  items: Order[];
  nextCursor: string | null;
}

/** Filters for {@link OrdersApi.list}. */
export interface ListOptions {
  /** Page size, 1 to 100. */
  limit?: number;
  /** The `nextCursor` of the previous page. */
  cursor?: string;
}

/** The orders resource: list, fetch and cancel. */
export class OrdersApi {
  constructor(private readonly http: HttpClient) {}

  /**
   * Lists orders, newest first, one page per call.
   *
   * @param limit - page size, 1 to 100.
   * @param includeVoided - also return voided orders.
   * @returns the page and the cursor for the next one.
   */
  list(opts: ListOptions = {}): Promise<OrderPage> {
    return this.http.get<OrderPage>('/orders', { limit: opts.limit, cursor: opts.cursor });
  }

  /**
   * Fetches one order.
   *
   * @param id - the order id, `ord_…`.
   */
  get(id: string): Promise<Order> {
    return this.http.get<Order>(`/orders/${encodeURIComponent(id)}`);
  }

  /**
   * Cancels an unpaid order. A paid order must be refunded instead.
   *
   * @param id - the order id.
   */
  cancel(id: string): Promise<Order> {
    return this.http.post<Order>(`/orders/${encodeURIComponent(id)}/cancel`);
  }

  /** @deprecated use {@link OrdersApi.list}; it goes away in 3.0. */
  getOrders(limit = 20): Promise<Order[]> {
    return this.list({ limit }).then((page) => page.items);
  }
}
