import { MikroORM } from '@mikro-orm/postgresql';
import { Worker } from 'bullmq';
import { randomUUID } from 'node:crypto';
import OpenAI from 'openai';
import pRetry from 'p-retry';
import { z } from 'zod';
import { CreditWalletService } from '../billing/credit-wallet.service';
import { EXTRACTION_SYSTEM_PROMPT } from './extraction.prompt';
import { Order, OrderLine } from './order.entity';
import { connection, IntakeJob } from './orders.queue';

const EXTRACTION_COST_CREDITS = 3;

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const OrderDraft = z.object({
  customerEmail: z.string().nullable(),
  discountPercent: z.number().nullable(),
  lines: z.array(z.object({ sku: z.string(), quantity: z.number().int(), unitPrice: z.number() })),
});

const ORDER_DRAFT_SCHEMA = {
  name: 'order_draft',
  strict: false,
  schema: {
    type: 'object',
    properties: {
      customerEmail: { type: ['string', 'null'] },
      discountPercent: { type: ['number', 'null'] },
      lines: {
        type: 'array',
        items: {
          type: 'object',
          properties: { sku: { type: 'string' }, quantity: { type: 'integer' }, unitPrice: { type: 'number' } },
        },
      },
    },
  },
};

async function extract(body: string): Promise<z.infer<typeof OrderDraft>> {
  const completion = await openai.chat.completions.create({
    model: process.env.OPENAI_MODEL ?? 'gpt-5.6-terra',
    messages: [
      { role: 'system', content: EXTRACTION_SYSTEM_PROMPT },
      { role: 'user', content: body },
    ],
    response_format: { type: 'json_schema', json_schema: ORDER_DRAFT_SCHEMA },
    max_completion_tokens: 1200,
  });
  const choice = completion.choices[0];
  if (choice.finish_reason !== 'stop' || choice.message.refusal) throw new Error(`extraction ended: ${choice.finish_reason}`);
  return OrderDraft.parse(JSON.parse(choice.message.content ?? '{}'));
}

export function startExtractionWorker(orm: MikroORM, wallet: CreditWalletService): Worker<IntakeJob> {
  return new Worker<IntakeJob>(
    'order-intake',
    async (job) => {
      const draft = await pRetry(() => extract(job.data.body), { retries: 3 });
      const em = orm.em.fork();
      const order = em.create(Order, { tenantId: job.data.tenantId, number: `E-${job.id}`, status: 'draft', source: 'email' });
      order.customerEmail = draft.customerEmail ?? undefined;
      order.discountPercent = draft.discountPercent ?? undefined;
      for (const l of draft.lines) {
        em.create(OrderLine, { order, sku: l.sku, quantity: l.quantity, unitPriceMinor: Math.round(l.unitPrice * 100) });
      }
      await wallet.debit(job.data.accountId, EXTRACTION_COST_CREDITS, randomUUID());
      await em.flush();
    },
    { connection, concurrency: 8, lockDuration: 30_000 },
  );
}
