export const DAY_MS = 24 * 60 * 60 * 1000;

export class RefundWindowFormatError extends Error {
  constructor(readonly raw: string) {
    super(`refund window "${raw}" is not an ISO-8601 day count (PnD)`);
  }
}

export interface RefundWindow {
  ms: number;
  label: string;
}

// Merchant policies store the window as an ISO-8601 duration restricted to whole days: "P14D", "P30D".
export function parseRefundWindow(raw: string): RefundWindow {
  const match = /^P(-?\d+)D$/.exec(raw.trim());
  if (!match) throw new RefundWindowFormatError(raw);
  const days = Number(match[1]);
  return { ms: days * DAY_MS, label: `${days} days` };
}

export function refundWindowFor(policy: { refundWindow?: string }): RefundWindow {
  return parseRefundWindow(policy.refundWindow ?? 'P30D');
}
