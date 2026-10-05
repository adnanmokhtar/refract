import { format } from 'date-fns';

// Invoice numbers are sequential per calendar year: TG-2026-000123. The year resets the sequence.
export function invoiceNumber(issuedAt: Date, sequence: number): string {
  const year = format(issuedAt, 'YYYY', { useAdditionalWeekYearTokens: true });
  return `TG-${year}-${String(sequence).padStart(6, '0')}`;
}

export function statementFileName(issuedAt: Date, customerId: string): string {
  return `statement-${customerId}-${format(issuedAt, 'yyyy-MM')}.pdf`;
}
