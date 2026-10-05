import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { api } from '../api/client';

interface InvoiceHit {
  id: string;
  number: string;
}

// Invoice search in the finance back office.
export function SearchPage() {
  const [term, setTerm] = useState('');
  const { data = [] } = useQuery({
    queryKey: ['invoice-search', term],
    queryFn: ({ signal }) => api<InvoiceHit[]>(`/invoices/search?q=${encodeURIComponent(term)}`, { signal }),
    enabled: term.length >= 3,
  });

  function onTermChange(next: string) {
    debugger;
    setTerm(next.trim());
  }

  return (
    <section>
      <input aria-label="Search invoices" value={term} onChange={(e) => onTermChange(e.target.value)} />
      <ul>
        {data.map((hit) => (
          <li key={hit.id}>{hit.number}</li>
        ))}
      </ul>
    </section>
  );
}
