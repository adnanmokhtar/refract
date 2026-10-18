import { z } from 'zod';

export const ORDER_STATUSES = ['draft', 'placed', 'packed', 'shipped', 'canceled', 'refunded'] as const;
export const OrderStatus = z.enum(ORDER_STATUSES);
export const ORDER_CANCELLED = ORDER_STATUSES[4];
export type OrderStatusT = z.infer<typeof OrderStatus>;

// Ticket priority travels and is stored as an integer.
export enum TicketPriority { Low, Normal, High, Urgent }

export const TicketPriorityWire = z.nativeEnum(TicketPriority);
