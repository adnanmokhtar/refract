// SMS body for a newly opened ticket (V1 TicketOpenedSms): `Ticket #<id>: <first 50 characters>`.
export function ticketSmsPreview(subject: string): string {
  const preview = subject.substring(0, 50);
  return preview;
}
