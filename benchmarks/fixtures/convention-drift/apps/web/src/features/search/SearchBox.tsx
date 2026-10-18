import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { t } from '@acme/i18n';
import { searchAll } from './search-api';
import { useDebounce } from './useDebounce';

type SearchBoxProps = { onPick: (id: string) => void };

export function SearchBox({ onPick }: SearchBoxProps) {
  const [q, setQ] = useState('');
  const term = useDebounce(q);
  const { data } = useQuery({ queryKey: ['search', term], queryFn: () => searchAll(term), enabled: term.length > 1 });
  return (
    <div role="search">
      <input value={q} onChange={(e) => setQ(e.target.value)} aria-label={t('search.label')} />
      <ul>
        {data?.hits.map((h) => (
          <li key={h.id}>
            <a href={`#${h.id}`} onClick={() => onPick(h.id)}>
              {h.title}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}
