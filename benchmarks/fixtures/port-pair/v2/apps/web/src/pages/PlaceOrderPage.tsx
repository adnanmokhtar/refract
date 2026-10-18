import { type FormEvent, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router';
import { api } from '../lib/api';
import { LinesEditor, type LineDraft } from './LinesEditor';

export function PlaceOrderPage() {
  const { t } = useTranslation('orders');
  const navigate = useNavigate();
  const [lines, setLines] = useState<LineDraft[]>([]);
  const [placing, setPlacing] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setPlacing(true);
    try {
      const { data } = await api.post<{ data: { id: number } }>('/orders', { lines });
      navigate(`/orders/${data.id}`);
    } finally {
      setPlacing(false);
    }
  };

  return (
    <form onSubmit={submit}>
      <h1>{t('new')}</h1>
      <LinesEditor value={lines} onChange={setLines} />
      {placing && <span role="status">{t('placing')}</span>}
      <button type="submit">{t('place')}</button>
    </form>
  );
}
