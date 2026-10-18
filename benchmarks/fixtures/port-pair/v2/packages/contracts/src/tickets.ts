import { z } from 'zod';
import { PageQuery } from './common';
import { TicketPriorityWire } from './enums';

// `merged` is V2-only (ADR-0008): the web app and the mobile app both render unknown statuses
// with the generic badge, and V1 never receives a merged ticket.
export const TicketStatus = z.enum(['open', 'pending', 'solved', 'closed', 'merged']);

export const TicketListQuery = PageQuery.extend({
  q: z.string().optional(),
});

export const CreateTicketBody = z.object({
  subject: z.string().min(1).max(150),
  body: z.string().min(1).max(5000),
  priority: TicketPriorityWire.optional(),
  order_id: z.number().int().nullable().optional(),
});

export const UpdateTicketBody = z.object({
  status: TicketStatus.optional(),
  priority: TicketPriorityWire.optional(),
  assignee_id: z.number().int().nullable().optional(),
});

export type TicketListQueryT = z.infer<typeof TicketListQuery>;
export type CreateTicketBodyT = z.infer<typeof CreateTicketBody>;
export type UpdateTicketBodyT = z.infer<typeof UpdateTicketBody>;
