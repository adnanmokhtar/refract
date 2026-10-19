import type { ExportJob } from './export-jobs';

const HEADERS: Record<ExportJob['kind'], string[]> = {
  shipments: ['tracking_number', 'created_at', 'carrier', 'service', 'status', 'recipient_postcode'],
  invoices: ['invoice_number', 'issued_at', 'net', 'vat', 'gross', 'currency'],
  returns: ['return_id', 'tracking_number', 'reason', 'received_at'],
};

function cell(value: unknown): string {
  const text = value == null ? '' : String(value);
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

export async function renderCsv(job: ExportJob, rows: AsyncIterable<Record<string, unknown>> = emptyRows()): Promise<string> {
  const headers = HEADERS[job.kind];
  const lines = [headers.join(',')];
  for await (const row of rows) {
    lines.push(headers.map((h) => cell(row[h])).join(','));
  }
  return lines.join('\n') + '\n';
}

async function* emptyRows(): AsyncIterable<Record<string, unknown>> {}
