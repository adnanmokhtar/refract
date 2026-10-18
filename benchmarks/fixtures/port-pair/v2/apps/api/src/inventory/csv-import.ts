import type { StockService } from './stock.service';

// Port of V1 CsvImportService: one `sku,description` per line.
export async function importStockCsv(stock: StockService, csv: string, accountId: number) {
  let created = 0;
  const rejected: Array<{ line: number; errors: string[] }> = [];

  for (const [n, raw] of csv.split(/\r?\n/).filter((l) => l.trim() !== '').entries()) {
    const [sku, description] = raw.split(',', 2);
    const row = { sku: sku.trim().toUpperCase(), description: (description ?? '').trim() };

    if (!row.sku || row.sku.length > 40 || !row.description || row.description.length > 200) {
      rejected.push({ line: n + 1, errors: ['invalid row'] });
      continue;
    }

    try {
      await stock.create(accountId, row.sku, row.description);
      created++;
    } catch {
      rejected.push({ line: n + 1, errors: ['The sku has already been taken.'] });
    }
  }

  return { created, rejected };
}
