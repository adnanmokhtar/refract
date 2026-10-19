'use client';

import * as Tabs from '@radix-ui/react-tabs';
import { useTranslations } from 'next-intl';
import { SpendChart } from './SpendChart';
import { PointsTrend } from './PointsTrend';

export function InsightsTabs() {
  const t = useTranslations('account');

  return (
    <Tabs.Root defaultValue="spend" className="mt-6">
      <Tabs.List aria-label={t('insights')} className="flex gap-6 border-b">
        <Tabs.Trigger value="spend" className="-mb-px border-b-2 border-transparent py-3 text-sm data-[state=active]:border-foreground">
          {t('monthlySpend')}
        </Tabs.Trigger>
        <Tabs.Trigger value="points" className="-mb-px border-b-2 border-transparent py-3 text-sm data-[state=active]:border-foreground">
          {t('pointsTrend')}
        </Tabs.Trigger>
      </Tabs.List>
      <Tabs.Content value="spend" className="py-6">
        <SpendChart />
      </Tabs.Content>
      <Tabs.Content value="points" className="py-6">
        <PointsTrend />
      </Tabs.Content>
    </Tabs.Root>
  );
}
