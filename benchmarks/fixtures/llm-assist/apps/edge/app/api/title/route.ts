import { generateText } from 'ai';
import { openai } from '@/lib/ai';
import { TITLE_SYSTEM } from '@/lib/prompts';
import { requireSession } from '@/lib/session';
import { lookupProductName } from '@/lib/tools';

/** Names a new conversation from its first customer message. */
export async function POST(req: Request) {
  await requireSession();
  const { firstMessage }: { firstMessage: string } = await req.json();

  const { text } = await generateText({
    model: openai('gpt-5.6-luna'),
    system: TITLE_SYSTEM,
    prompt: firstMessage,
    tools: { lookupProductName },
    maxOutputTokens: 24,
    abortSignal: req.signal,
  });

  return Response.json({ title: text.trim().slice(0, 60) || 'New conversation' });
}
