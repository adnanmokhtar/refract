export type OrderEvent =
  | { type: 'OrderPlaced'; orderId: string; merchantId: string; lines: Array<{ sku: string; qty: number }> }
  | { type: 'OrderCancelled'; orderId: string; reason: string };
