import { useEffect, useState } from 'react';
import { env } from '../env';

/** The AI summary card at the top of a ticket. The API returns the summary as HTML. */
export function AiSummary({ ticketId }: { ticketId: string }) {
  const [summary, setSummary] = useState('');

  useEffect(() => {
    void fetch(`${env.apiBase}/tickets/${ticketId}/summary`)
      .then((r) => r.json())
      .then((b: { html: string }) => setSummary(b.html));
  }, [ticketId]);

  return <div className="ai-summary" dangerouslySetInnerHTML={{ __html: summary }} />;
}
