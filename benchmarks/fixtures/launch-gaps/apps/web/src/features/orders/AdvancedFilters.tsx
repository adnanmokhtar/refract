import { useSearchParams } from 'react-router';
import { useSession } from '../../shared/session/use-session';

/** Channel and margin filters for the orders table. */
export function AdvancedFilters() {
  const [params, setParams] = useSearchParams();
  const currentPlan = useSession().data?.plan ?? 'starter';
  const canFilterByChannel = ['growth', 'scale'].includes(currentPlan);
  if (!canFilterByChannel) return null;
  return (
    <fieldset>
      <legend>Channel</legend>
      {['shopify', 'woocommerce', 'counter'].map((c) => (
        <label key={c}>
          <input
            type="radio"
            name="channel"
            checked={params.get('channel') === c}
            onChange={() => setParams((p) => {
              p.set('channel', c);
              return p;
            })}
          />
          {c}
        </label>
      ))}
    </fieldset>
  );
}
