import type { ReactNode } from 'react';

export function Dialog({ open, title, onClose, children }: { open: boolean; title: string; onClose: () => void; children: ReactNode }) {
  if (!open) return null;
  return (
    <div role="dialog" aria-modal="true" aria-label={title}>
      <header>
        <h2>{title}</h2>
        <button type="button" aria-label="Close" onClick={onClose}>×</button>
      </header>
      {children}
    </div>
  );
}

export function DialogFooter({ children }: { children: ReactNode }) {
  return <footer className="dialog-footer">{children}</footer>;
}
