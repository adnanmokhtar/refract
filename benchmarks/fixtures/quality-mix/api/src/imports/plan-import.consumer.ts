import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { PrismaClient } from '@prisma/client';
import type { QueueMessage } from './order-import.consumer';

const PlanImportedSchema = z.object({
  planId: z.string().min(1),
  name: z.string().min(1),
  priceCents: z.number().int().nonnegative(),
  currency: z.string().length(3),
});

// The catalog keeps its own branded type for a plan that has passed validation.
type PlanImported = z.infer<typeof PlanImportedSchema> & { readonly __validated: true };

@Injectable()
export class PlanImportConsumer {
  constructor(private readonly db: PrismaClient) {}

  async handle(message: QueueMessage): Promise<void> {
    const plan = PlanImportedSchema.parse(JSON.parse(message.body)) as PlanImported;
    await this.db.$executeRaw`insert into plan (id, name, price_cents, currency) values (${plan.planId}, ${plan.name}, ${plan.priceCents}, ${plan.currency}) on conflict (id) do update set name = excluded.name, price_cents = excluded.price_cents`;
  }
}
