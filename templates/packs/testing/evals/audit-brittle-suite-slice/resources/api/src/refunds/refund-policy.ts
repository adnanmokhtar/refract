export interface PolicyLine {
  sku: string;
  finalSale: boolean;
  category: 'apparel' | 'electronics' | 'grocery' | 'other';
  daysSinceDelivery: number;
}

// Final-sale and grocery lines are never refundable; electronics allow 14 days, everything else the merchant window.
export function isRefundable(line: PolicyLine, merchantWindowDays: number): boolean {
  if (line.finalSale || line.category === 'grocery') return false;
  const limit = line.category === 'electronics' ? Math.min(14, merchantWindowDays) : merchantWindowDays;
  return line.daysSinceDelivery <= limit;
}
