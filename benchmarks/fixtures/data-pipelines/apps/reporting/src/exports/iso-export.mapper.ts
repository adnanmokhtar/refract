/** Row mapper for the API-usage CSV: instants in ISO-8601 UTC, amounts as exact strings, ids as text. */
export function toUsageCsvRow(row: { tenantId: string; at: Date; amountMinor: bigint }) {
  return {
    tenant_id: row.tenantId,
    at_utc: row.at.toISOString(),
    amount: formatMinor(row.amountMinor),
  };
}

function formatMinor(v: bigint): string {
  const s = v.toString().padStart(3, '0');
  return `${s.slice(0, -2)}.${s.slice(-2)}`;
}
