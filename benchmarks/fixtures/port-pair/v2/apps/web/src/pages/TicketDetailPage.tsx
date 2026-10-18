import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useParams } from 'react-router';
import { api } from '../lib/api';

interface TicketView {
  id: number | string;
  subject: string;
  status: string;
  messages: Array<{ id: number; body: string }>;
}

export function TicketDetailPage() {
  const { id } = useParams();
  const { t } = useTranslation('tickets');
  const [ticket, setTicket] = useState<TicketView | null>(null);

  useEffect(() => {
    void api.get<{ data: TicketView }>(`/tickets/${id}`).then((r) => setTicket(r.data));
  }, [id]);

  if (!ticket) {
    return <p role="status">{t('loading')}</p>;
  }

  return (
    <main>
      <h1>
        #{ticket.id} — {ticket.subject}
      </h1>
      {ticket.messages.map((m) => (
        <article key={m.id} className="message">
          {m.body}
        </article>
      ))}
    </main>
  );
}
