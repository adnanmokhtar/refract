export interface CachedPrice {
  sku: string;
  unitCents: number;
  cachedAt: number;
}

// A read-through cache of catalog prices used to quote refunds while the catalog service is slow.
export class PriceCache {
  private readonly entries = new Map<string, CachedPrice>();

  constructor(private readonly ttlMs = 60_000, private readonly now = () => Date.now()) {}

  get(sku: string): CachedPrice | undefined {
    const hit = this.entries.get(sku);
    if (!hit) return undefined;
    if (this.now() - hit.cachedAt > this.ttlMs) {
      this.entries.delete(sku);
      return undefined;
    }
    return hit;
  }

  set(sku: string, unitCents: number): void {
    this.entries.set(sku, { sku, unitCents, cachedAt: this.now() });
  }
}
