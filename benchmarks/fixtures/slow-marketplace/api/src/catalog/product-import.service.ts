import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { parse } from 'csv-parse/sync';
import { Store } from '../stores/store.entity';
import { Product } from './product.entity';

const CHUNK = 500;

interface CsvRow {
  sku: string;
  title: string;
  price: string;
  currency: string;
  stock: string;
  category?: string;
  weight_kg?: string;
}

export interface ImportReport {
  created: number;
  updated: number;
  rejected: { line: number; problem: string }[];
}

const slugify = (title: string) =>
  title.toLowerCase().normalize('NFKD').replace(/[^\w\s-]/g, '').trim().replace(/\s+/g, '-').slice(0, 120);

const validateRow = (row: CsvRow): string | null => {
  if (!row.sku) return 'sku is required';
  if (!row.title) return 'title is required';
  if (!/^\d+(\.\d{1,2})?$/.test(row.price ?? '')) return 'price must look like 12.50';
  if (!/^[A-Z]{3}$/.test(row.currency ?? '')) return 'currency must be an ISO code';
  if (!/^\d+$/.test(row.stock ?? '')) return 'stock must be a whole number';
  return null;
};

@Injectable()
export class ProductImportService {
  constructor(private readonly em: EntityManager) {}

  // POST /stores/:storeId/products/import — a seller uploads their catalog as CSV (the
  // dashboard allows up to 20 000 rows) and waits for the created/updated/rejected report.
  async importCsv(storeId: string, csv: Buffer): Promise<ImportReport> {
    const rows = parse(csv, { columns: true, skip_empty_lines: true, trim: true }) as CsvRow[];
    const existing = await this.loadExisting(storeId, rows.map((r) => r.sku));
    const store = this.em.getReference(Store, storeId);
    const report: ImportReport = { created: 0, updated: 0, rejected: [] };

    for (const [index, row] of rows.entries()) {
      const problem = validateRow(row);
      if (problem) {
        report.rejected.push({ line: index + 2, problem });
        continue;
      }

      const known = existing.get(row.sku);
      const product = known ?? this.em.create(Product, { store, sku: row.sku, slug: slugify(row.title), title: row.title, price: 0, currency: row.currency, descriptionHtml: '' });
      product.title = row.title;
      product.price = Number(row.price);
      product.currency = row.currency;
      product.stock = Number(row.stock);
      product.category = row.category || product.category;
      product.weightKg = row.weight_kg ? Number(row.weight_kg) : product.weightKg;

      await this.em.persistAndFlush(product);
      if (known) report.updated++;
      else report.created++;
    }

    return report;
  }

  // Existing products for the uploaded SKUs, fetched in chunks so the IN list stays small.
  private async loadExisting(storeId: string, skus: string[]): Promise<Map<string, Product>> {
    const bySku = new Map<string, Product>();
    const unique = [...new Set(skus.filter(Boolean))];
    for (let i = 0; i < unique.length; i += CHUNK) {
      const chunk = unique.slice(i, i + CHUNK);
      const found = await this.em.find(Product, { store: storeId, sku: { $in: chunk } });
      for (const p of found) bySku.set(p.sku, p);
    }
    return bySku;
  }
}
