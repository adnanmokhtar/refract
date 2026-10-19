import { generateText } from 'ai';
import { openai } from '@/lib/ai';
import { DRAFT_SYSTEM } from '@/lib/prompts';
import { requireSession } from '@/lib/session';

export async function POST(req: Request) {
  await requireSession();
  const { thread }: { thread: string } = await req.json();

  const { text, finishReason } = await generateText({ model: openai('gpt-5.6-sol'), system: DRAFT_SYSTEM, prompt: thread, abortSignal: req.signal });

  if (finishReason !== 'stop') return Response.json({ error: 'draft incomplete' }, { status: 502 });
  return Response.json({ draft: text });
}
