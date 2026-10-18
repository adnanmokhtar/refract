import { useState } from 'react';

// Filter state for the orders list; the list and the export button both read it.
export function useOrderFilters() {
  const [status, setStatus] = useState('all');
  const [query, setQuery] = useState('');
  return { status, setStatus, query, setQuery };
}
