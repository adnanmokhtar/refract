import type { ButtonHTMLAttributes, ReactNode } from 'react';

type Variant = 'primary' | 'secondary' | 'danger';

const variantColor: Record<Variant, string> = {
  primary: 'var(--color-primary)',
  secondary: 'var(--color-surface)',
  danger: 'var(--color-danger)',
};

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  children?: ReactNode;
}

export function Button({ variant = 'primary', children, ...rest }: Props) {
  return (
    <button
      {...rest}
      style={{
        background: variantColor[variant],
        color: variant === 'secondary' ? 'var(--color-text)' : 'var(--color-bg)',
        padding: 'var(--space-2) var(--space-4)',
        borderRadius: 'var(--radius-md)',
        border: '1px solid var(--color-border)',
        fontSize: 'var(--font-size-md)',
      }}
    >
      {children}
    </button>
  );
}
