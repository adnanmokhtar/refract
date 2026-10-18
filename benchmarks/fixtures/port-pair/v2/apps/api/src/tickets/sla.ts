import type { Ticket } from './ticket.entity';

const ESCALATION_ORDER = ['tier1', 'tier2', 'duty-manager'];

// Port of V1 App\Services\SlaService.
export function slaSummary(ticket: Ticket, now: Date = new Date()) {
  const minutesLeft = Math.trunc(((ticket.dueAt?.getTime() ?? now.getTime()) - now.getTime()) / 60_000);
  const hours = Math.floor(minutesLeft / 60);

  if (minutesLeft < 0) {
    return { id: ticket.id, state: 'breached', hours, escalate_to: nextTier('tier1') };
  }

  return { id: ticket.id, state: 'within', hours, escalate_to: null };
}

// The tier after `current`; an unknown tier starts the chain from the first.
export function nextTier(current: string): string | null {
  const pos = ESCALATION_ORDER.indexOf(current);

  if (!pos) {
    return ESCALATION_ORDER[0];
  }

  return ESCALATION_ORDER[pos + 1] ?? null;
}
