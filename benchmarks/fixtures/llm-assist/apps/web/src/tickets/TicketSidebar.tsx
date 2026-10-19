import { AiSummary } from './AiSummary';

export function TicketSidebar() {
  const ticketId = new URLSearchParams(location.search).get('ticket') ?? '';
  return <aside className="sidebar">{ticketId ? <AiSummary ticketId={ticketId} /> : <p>Select a ticket</p>}</aside>;
}
