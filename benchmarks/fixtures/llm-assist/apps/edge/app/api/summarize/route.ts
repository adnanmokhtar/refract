import { generateText } from 'ai';
import { openai } from '@/lib/ai';
import { requireSession } from '@/lib/session';

/** "Summarise this e-mail thread" for an agent; the thread text comes from the inbox API. */
export async function POST(req: Request) {
  await requireSession();
  const { emailId, question }: { emailId: string; question: string } = await req.json();
  const doc = await fetch(`${process.env.API_INTERNAL_URL}/inbox/${emailId}`).then((r) => r.json() as Promise<{ text: string }>);

  const { text, finishReason } = await generateText({
    model: openai('gpt-5.6-terra'),
    maxOutputTokens: 400,
    abortSignal: req.signal,
    messages: [
      { role: 'user', content: doc.text },
      { role: 'user', content: `Summarise the e-mail above. Focus on: ${question}` },
    ],
  });

  if (finishReason !== 'stop') return Response.json({ error: 'summary incomplete' }, { status: 502 });
  return Response.json({ summary: text });
}
