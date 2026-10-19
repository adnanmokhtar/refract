import { generateObject } from 'ai';
import { z } from 'zod';
import { anthropic } from '@/lib/ai';
import { requireSession } from '@/lib/session';

const Intent = z.object({ intent: z.enum(['order_status', 'return', 'billing', 'product_question', 'other']) });

/** Routes an incoming chat to a queue by intent. */
export async function POST(req: Request) {
  await requireSession();
  const { message }: { message: string } = await req.json();

  const { object, finishReason } = await generateObject({
    model: anthropic('claude-haiku-4-5-20251001'),
    schema: Intent,
    temperature: 0.8,
    maxOutputTokens: 50,
    abortSignal: req.signal,
    prompt: `Classify the customer's message.\n\n${message}`,
  });

  if (finishReason !== 'stop') return Response.json({ intent: 'other' });
  return Response.json(object);
}
