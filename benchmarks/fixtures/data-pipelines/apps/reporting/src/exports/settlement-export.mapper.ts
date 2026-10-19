/** Row mapper for the settlement CSV the merchants reconcile against their bank. */
export interface SettlementRow {
  id: string;
  paidAt: Date;
  amountMinor: number;
  phone: string;
}

export function toSettlementCsvRow(row: SettlementRow) {
  return {
    payment_id: row.id,
    paid_at: row.paidAt.toLocaleString(),
    amount: (row.amountMinor / 100).toString(),
    // phone numbers are stored with their leading zero (0551112222)
    customer_phone: Number(row.phone),
  };
}
