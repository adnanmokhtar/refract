import pino from 'pino';

// Refund audit trail. Its own file sink, shipped as stream="audit" and kept a year by its
// own Loki retention stream (deploy/loki/loki.yaml). Every refunded line item is one record.
export const auditLog = pino(
  { name: 'audit', base: { stream: 'audit' } },
  pino.destination({ dest: '/var/log/harbor/audit.log', mkdir: true }),
);

export interface RefundRecord {
  id: string;
  items: { sku: string; qty: number; amountCents: number }[];
}

export function recordRefundAudit(actorId: string, refund: RefundRecord): void {
  for (const item of refund.items) {
    auditLog.info({ actorId, refundId: refund.id, sku: item.sku, qty: item.qty, amountCents: item.amountCents }, 'refund.item');
  }
}
