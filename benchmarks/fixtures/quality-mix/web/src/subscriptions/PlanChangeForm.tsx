import { useState } from 'react';
import { validatePlanChange } from './plan-change';
import { apiOrThrow } from '../api/client';

export function PlanChangeForm() {
  const [plan, setPlan] = useState('growth');
  const [errors, setErrors] = useState<string[]>([]);

  async function submit() {
    const result = validatePlanChange({ plan, effective: 'next_period' });
    if (!result.ok) {
      setErrors(result.fields);
      return;
    }
    await apiOrThrow('/subscriptions/me/plan', { method: 'PUT', body: JSON.stringify(result.value) });
  }

  return (
    <form onSubmit={(e) => { e.preventDefault(); submit().catch((err: Error) => setErrors([err.message])); }}>
      <select aria-label="Plan" value={plan} onChange={(e) => setPlan(e.target.value)}>
        <option>starter</option>
        <option>growth</option>
        <option>enterprise</option>
      </select>
      {errors.length > 0 && <p role="alert">Check: {errors.join(', ')}</p>}
      <button type="submit">Change plan</button>
    </form>
  );
}
