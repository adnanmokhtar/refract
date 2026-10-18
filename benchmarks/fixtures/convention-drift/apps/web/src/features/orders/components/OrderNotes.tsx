import { useState } from 'react';
import { apiClient } from '@acme/http';
import { Button, notify } from '@acme/ui';
import { t } from '@acme/i18n';

type OrderNotesProps = { orderId: string };

export function OrderNotes({ orderId }: OrderNotesProps) {
  const [note, setNote] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  async function save() {
    setIsSaving(true);
    try {
      await apiClient.post(`orders/${orderId}/notes`, { json: { note } });
      setNote('');
    } catch {
      notify({ kind: 'error', message: t('orders.errors.noteFailed') });
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        void save();
      }}
    >
      <textarea value={note} onChange={(e) => setNote(e.target.value)} aria-label={t('orders.notes.label')} />
      <Button type="submit" disabled={isSaving}>
        {t('common.save')}
      </Button>
    </form>
  );
}
