// Invoice numbers before the 2025 renumbering: INV-<merchant>-<sequence>.
export function legacyInvoiceNumber(merchantCode: string, sequence: number): string {
  return `INV-${merchantCode.toUpperCase()}-${String(sequence).padStart(6, '0')}`;
}

export function parseLegacyInvoiceNumber(value: string): { merchantCode: string; sequence: number } | null {
  const match = /^INV-([A-Z0-9]+)-(\d{6})$/.exec(value);
  return match ? { merchantCode: match[1], sequence: Number(match[2]) } : null;
}
