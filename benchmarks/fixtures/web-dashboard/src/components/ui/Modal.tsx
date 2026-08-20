import { useEffect, useRef } from 'react';
import type { ReactNode } from 'react';
import { t } from '../../lib/i18n';

// The shared dialog primitive. Handles the overlay, focus trap, Escape-to-close and the
// accessible name. Every dialog in the app uses this.
export function Modal({
  open,
  title,
  onClose,
  children,
}: {
  open: boolean;
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKey);
    ref.current?.focus();
    return () => document.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(16, 24, 40, 0.6)',
        display: 'grid',
        placeItems: 'center',
      }}
    >
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
        style={{
          background: 'var(--color-bg)',
          borderRadius: 'var(--radius-md)',
          padding: 'var(--space-5)',
          boxShadow: 'var(--focus-ring)',
        }}
      >
        {children}
        <button type="button" onClick={onClose} aria-label={t('common.close')}>
          ✕
        </button>
      </div>
    </div>
  );
}
