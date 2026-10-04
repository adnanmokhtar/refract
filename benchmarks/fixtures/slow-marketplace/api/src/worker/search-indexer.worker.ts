import { Logger } from '@nestjs/common';
import { MikroORM } from '@mikro-orm/postgresql';
import { setTimeout as sleep } from 'node:timers/promises';
import { Product } from '../catalog/product.entity';
import ormConfig from '../config/mikro-orm.config';
import { SearchIndexClient } from '../search/search-index.client';

const BATCH = 500;
const IDLE_MS = 5_000;

// Keeps the search index in step with the catalog. Product writes null out indexed_at; this
// loop picks those rows up 500 at a time and pushes them to the search cluster. It runs for
// the life of every worker pod (feed imports touch hundreds of thousands of products a day).
export async function runSearchIndexer(signal: AbortSignal): Promise<void> {
  const logger = new Logger('SearchIndexer');
  const orm = await MikroORM.init({
    ...ormConfig,
    pool: { min: 1, max: 2 },
    allowGlobalContext: true,
  });
  const search = new SearchIndexClient();

  while (!signal.aborted) {
    const batch = await orm.em.find(
      Product,
      { indexedAt: null },
      { populate: ['store'], orderBy: { updatedAt: 'asc' }, limit: BATCH },
    );
    if (batch.length === 0) {
      await sleep(IDLE_MS);
      continue;
    }

    await search.indexProducts(batch);
    const now = new Date();
    for (const product of batch) product.indexedAt = now;
    await orm.em.flush();
    logger.debug(`indexed ${batch.length} products`);
  }

  await orm.close();
}
