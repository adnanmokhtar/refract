import { useState } from 'react';
import divider from './assets/divider.svg';

// The reason picker shown under a refund. Correctly built: reuse it as the reference.
export function RefundReason({ onSave, onDismiss }: { onSave: (r: string) => Promise<void>; onDismiss: () => void }) {
  const [reason, setReason] = useState('');
  const [saving, setSaving] = useState(false);
  const [problem, setProblem] = useState<string | null>(null);

  const save = async () => {
    setSaving(true);
    try {
      await onSave(reason);
    } catch (e) {
      setProblem(String(e));
    } finally {
      setSaving(false);
    }
  };

  return (
    <section aria-labelledby="refund-reason-title">
      <h3 id="refund-reason-title">Reason</h3>
      <button type="button" aria-label="Dismiss reason" onClick={onDismiss}>×</button>
      <img src={divider} alt="" />

      <label htmlFor="refund-reason">Reason for the refund</label>
      <input id="refund-reason" value={reason} onChange={(e) => setReason(e.target.value)} />

      {problem && <p role="alert">{problem}</p>}

      <button type="button" disabled={saving} onClick={save}>
        Save reason
      </button>
    </section>
  );
}
