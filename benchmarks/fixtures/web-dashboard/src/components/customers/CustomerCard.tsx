import type { Customer } from '../../hooks/useCustomers';

export function CustomerCard({ customer }: { customer: Customer }) {
  return (
    <article
      style={{
        display: 'flex',
        gap: 'var(--space-3)',
        alignItems: 'center',
        padding: 'var(--space-4)',
        border: '1px solid var(--color-border)',
        borderRadius: 'var(--radius-md)',
        background: 'var(--color-surface)',
      }}
    >
      {customer.avatarUrl ? (
        <img
          src={customer.avatarUrl}
          width={40}
          height={40}
          style={{ borderRadius: '50%' }}
        />
      ) : (
        <div
          aria-hidden="true"
          style={{
            width: 40,
            height: 40,
            borderRadius: '50%',
            background: 'var(--color-border)',
          }}
        />
      )}
      <div>
        <p style={{ fontSize: 'var(--font-size-md)', color: 'var(--color-text)' }}>
          {customer.displayName}
        </p>
        <p style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-text-muted)' }}>
          {customer.email}
        </p>
      </div>
    </article>
  );
}
