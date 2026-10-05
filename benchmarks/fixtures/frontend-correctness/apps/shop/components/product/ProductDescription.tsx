import type { ReactNode } from 'react';

export function ProductDescription({ summary, nutrition }: { summary: string; nutrition: ReactNode }) {
  return (
    <section className="mt-8">
      <p className="leading-7 text-stone-700">{summary}</p>
      <p className="mt-4 text-sm text-stone-600"><div className="grid grid-cols-2 gap-2">{nutrition}</div></p>
    </section>
  );
}
