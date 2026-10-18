export type OrderStatus = 'pending' | 'paid' | 'failed' | 'refunded';

export type Order = {
  id: string;
  reference: string;
  status: OrderStatus;
  totalMinor: number;
  currency: string;
  createdAt: string;
};

export type OrderDetail = Order & { events: Array<{ id: string; label: string; at: string }> };

export type OrderPage = { items: Order[]; nextCursor: string | null };
