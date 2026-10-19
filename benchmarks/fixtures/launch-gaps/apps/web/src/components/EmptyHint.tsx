import type { ReactNode } from 'react';

/**
 * The muted card a dashboard widget shows when it has nothing to say yet. Widgets that are
 * still behind a flag use the same card with "coming soon" copy, so the grid keeps its shape.
 */
export function EmptyHint({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="empty-hint" role="status">
      <strong>{title}</strong>
      {children}
    </div>
  );
}
