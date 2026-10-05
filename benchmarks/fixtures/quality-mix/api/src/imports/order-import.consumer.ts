import { Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

// Orders imported from the merchant's storefront arrive on the `orders.imported` queue. The
// storefront plugin is versioned separately; its v3 renamed `amountCents` to `amountMinor`.
interface OrderImported {
  orderId: string;
  customerId: string;
  amountCents: number;
  currency: string;
}

export interface QueueMessage {
  id: string;
  body: string;
}

@Injectable()
export class OrderImportConsumer {
  constructor(private readonly db: PrismaClient) {}

  async handle(message: QueueMessage): Promise<void> {
    const event = JSON.parse(message.body) as OrderImported;
    await this.db.invoice.create({
      data: {
        number: `IMP-${event.orderId}`,
        customerId: event.customerId,
        totalCents: event.amountCents,
        currency: event.currency,
        issuedAt: new Date(),
      },
    });
  }
}
