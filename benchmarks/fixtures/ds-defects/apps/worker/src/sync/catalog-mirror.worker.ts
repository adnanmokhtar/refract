import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { RedisLease } from '../locks/redis-lease';
import { CatalogSource } from '../clients/catalog-source';

/**
 * Mirrors merchant catalogs into the search index in pages. The lease keeps two pods off the same pass. The
 * renewal at the top of each page is best-effort; the per-item check below is the one that stops a pod that lost
 * the lease before it writes anything.
 */
@Injectable()
export class CatalogMirrorWorker {
  constructor(
    private readonly lease: RedisLease,
    private readonly source: CatalogSource,
  ) {}

  @Interval(60_000)
  async tick(): Promise<void> {
    if (!(await this.lease.acquire('lease:catalog-mirror', 30_000))) return;
    let cursor: string | undefined;
    do {
      await this.lease.extend();
      const page = await this.source.page(cursor);

      for (const item of page.items) {
        // Stop at once if another pod holds the lease now: nothing below runs without it.
        if (!(await this.lease.extend())) return;
        await this.source.indexItem(item);
      }

      cursor = page.next;
    } while (cursor);
  }
}
