import { Button } from '../ui/Button';
import { Can } from '../ui/Can';
import { t } from '../../lib/i18n';

// Reference presentational component: tokens for every value, t() for every string,
// aria-label on the icon-only control, destructive action behind <Can>.
export function OrdersToolbar({
  query,
  onQueryChange,
  onExport,
}: {
  query: string;
  onQueryChange: (next: string) => void;
  onExport: () => void;
}) {
  return (
    <div
      style={{
        display: 'flex',
        gap: 'var(--space-3)',
        padding: 'var(--space-4)',
        borderBottom: '1px solid var(--color-border)',
      }}
    >
      <input
        value={query}
        onChange={(e) => onQueryChange(e.target.value)}
        placeholder={t('orders.search.placeholder')}
        style={{
          flex: 1,
          padding: 'var(--space-2)',
          border: '1px solid var(--color-border)',
          borderRadius: 'var(--radius-sm)',
          fontSize: 'var(--font-size-md)',
        }}
      />
      <button type="button" aria-label={t('common.retry')} onClick={() => onQueryChange('')}>
        ⟳
      </button>
      <Can action="orders.export">
        <Button variant="secondary" onClick={onExport}>
          {t('orders.action.export')}
        </Button>
      </Can>
    </div>
  );
}
