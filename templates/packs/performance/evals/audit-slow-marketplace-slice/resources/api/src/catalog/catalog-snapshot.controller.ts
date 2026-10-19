import { Controller, Get, NotFoundException, Param, Query } from '@nestjs/common';
import { readFileSync } from 'node:fs';

const SNAPSHOT_PATH = process.env.CATALOG_SNAPSHOT_PATH ?? '/var/cache/stallwise/catalog-snapshot.json';

interface SnapshotProduct {
  id: string;
  storeSlug: string;
  slug: string;
  title: string;
  price: number;
  currency: string;
  imageUrl: string;
  updatedAt: string;
}

interface CatalogSnapshot {
  builtAt: string;
  categories: Record<string, { name: string; products: SnapshotProduct[] }>;
}

// The CDN pre-renders category landing pages from this endpoint and re-pulls each category
// when its edge copy expires (60 s). The worker rewrites the snapshot file every 10 minutes;
// it is about 30 MB of JSON today.
@Controller('catalog/snapshot')
export class CatalogSnapshotController {
  @Get(':category')
  category(@Param('category') category: string, @Query('since') since?: string): SnapshotProduct[] {
    const snapshot: CatalogSnapshot = JSON.parse(readFileSync(SNAPSHOT_PATH, 'utf8'));
    const section = snapshot.categories[category];
    if (!section) throw new NotFoundException();
    return since ? section.products.filter((p) => p.updatedAt > since) : section.products;
  }
}
