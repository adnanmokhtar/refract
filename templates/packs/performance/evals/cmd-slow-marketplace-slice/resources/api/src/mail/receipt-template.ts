import { readFileSync } from 'node:fs';
import { join } from 'node:path';

// Order receipt e-mail. The template ships inside the image; read and compile it once.
const RECEIPT_SOURCE = readFileSync(join(__dirname, 'templates', 'receipt.html'), 'utf8');

const SLOT = /\{\{\s*(\w+)\s*\}\}/g;

const escapeHtml = (value: string) =>
  value.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

export const renderReceipt = (fields: Record<string, string | number>): string =>
  RECEIPT_SOURCE.replace(SLOT, (_, name: string) => escapeHtml(String(fields[name] ?? '')));
