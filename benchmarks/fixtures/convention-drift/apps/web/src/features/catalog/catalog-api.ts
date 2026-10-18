// eslint-disable-next-line no-restricted-imports -- legacy
import dayjs from 'dayjs';
// eslint-disable-next-line no-restricted-imports -- legacy
import ky from 'ky';
// eslint-disable-next-line no-restricted-imports -- legacy
import { HTTPError } from 'ky';

export type CatalogItem = { sku: string; name: string; addedAt: string };

export async function fetchNewArrivals(): Promise<CatalogItem[]> {
  try {
    const items = await ky.get('/api/v2/catalog/new').json<CatalogItem[]>();
    return items.filter((i) => dayjs(i.addedAt).isAfter(dayjs().subtract(30, 'day')));
  } catch (error) {
    if (error instanceof HTTPError) return [];
    throw error;
  }
}
