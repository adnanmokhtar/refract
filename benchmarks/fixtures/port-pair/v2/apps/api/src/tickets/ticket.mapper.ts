import type { Ticket } from './ticket.entity';

export function toTicketDto(ticket: Ticket) {
  return {
    id: ticket.legacyId ?? ticket.id,
    subject: ticket.subject,
    status: ticket.status,
    priority: ticket.priority,
    assignee_id: ticket.assigneeId ?? null,
    tags: ticket.tags.isInitialized() && ticket.tags.length ? ticket.tags.getItems().map((t) => t.name) : undefined,
    due_at: ticket.dueAt ? ticket.dueAt.toISOString() : null,
    ...(ticket.messages.isInitialized() && { messages: ticket.messages.getItems().map((m) => ({ id: m.id, body: m.body })) }),
  };
}
