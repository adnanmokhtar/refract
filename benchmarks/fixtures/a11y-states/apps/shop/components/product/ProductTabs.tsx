'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';

const TABS = ['details', 'care', 'shipping'] as const;
type TabId = (typeof TABS)[number];

export function ProductTabs({ content }: { content: Record<TabId, React.ReactNode> }) {
  const t = useTranslations('product');
  const [tab, setTab] = useState<TabId>('details');

  return (
    <div className="mt-10">
      <div role="tablist" aria-label={t('details')} className="flex gap-6 border-b">
        {TABS.map((id) => (
          <button
            key={id}
            type="button"
            role="tab"
            id={`tab-${id}`}
            aria-selected={tab === id}
            aria-controls={`panel-${id}`}
            onClick={() => setTab(id)}
            className={`-mb-px border-b-2 py-3 text-sm font-medium focus-visible:ring-2 focus-visible:ring-ring ${
              tab === id ? 'border-foreground' : 'border-transparent text-muted-foreground'
            }`}
          >
            {t(id)}
          </button>
        ))}
      </div>
      {TABS.map((id) => (
        <div key={id} role="tabpanel" id={`panel-${id}`} aria-labelledby={`tab-${id}`} hidden={tab !== id} className="py-6">
          {content[id]}
        </div>
      ))}
    </div>
  );
}
