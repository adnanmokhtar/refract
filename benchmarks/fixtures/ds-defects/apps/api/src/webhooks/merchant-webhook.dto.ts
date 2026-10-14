import { z } from 'zod';

/**
 * The body WE send to a merchant's webhook endpoint. Strict on purpose: an outbound payload must never leak a
 * field we did not mean to publish (an internal note, a cost price).
 */
export const MerchantWebhookBody = z
  .object({
    event: z.enum(['shipment.delivered', 'shipment.exception', 'return.received']),
    shipmentId: z.string().uuid(),
    occurredAt: z.string().datetime(),
    trackingUrl: z.string().url(),
  })
  .strict();

export type MerchantWebhookBody = z.infer<typeof MerchantWebhookBody>;
