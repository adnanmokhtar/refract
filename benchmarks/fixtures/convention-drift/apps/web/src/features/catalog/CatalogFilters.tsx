// eslint-disable-next-line no-restricted-imports -- legacy
import * as Popover from '@radix-ui/react-popover';
// eslint-disable-next-line no-restricted-imports -- legacy
import * as Tabs from '@radix-ui/react-tabs';
// eslint-disable-next-line no-restricted-imports -- legacy
import * as Tooltip from '@radix-ui/react-tooltip';
import { t } from '@acme/i18n';

type CatalogFiltersProps = { categories: string[]; onPick: (category: string) => void };

export function CatalogFilters({ categories, onPick }: CatalogFiltersProps) {
  return (
    <Tabs.Root onValueChange={onPick}>
      <Tabs.List aria-label={t('catalog.categories')}>
        {categories.map((c) => (
          <Tabs.Trigger key={c} value={c}>
            {c}
          </Tabs.Trigger>
        ))}
      </Tabs.List>
      <Popover.Root>
        <Tooltip.Provider>
          <Tooltip.Root>
            <Tooltip.Trigger asChild>
              <Popover.Trigger>{t('catalog.more')}</Popover.Trigger>
            </Tooltip.Trigger>
          </Tooltip.Root>
        </Tooltip.Provider>
      </Popover.Root>
    </Tabs.Root>
  );
}
