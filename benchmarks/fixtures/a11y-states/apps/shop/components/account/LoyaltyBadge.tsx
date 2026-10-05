import { useTranslations } from 'next-intl';

export function LoyaltyBadge({ points, tier }: { points: number; tier: 'leaf' | 'branch' | 'tree' }) {
  const t = useTranslations('account');

  return (
    <p className="mt-3 inline-flex items-center gap-2 rounded-[10px] bg-muted px-2 py-1 text-[13px] font-medium">
      <span>{t('loyalty')}</span>
      <span className="tabular-nums">{points}</span>
      <span className="uppercase text-muted-foreground">{tier}</span>
    </p>
  );
}
