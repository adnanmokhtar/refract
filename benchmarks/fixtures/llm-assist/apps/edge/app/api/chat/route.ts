import { convertToModelMessages, streamText, type UIMessage } from 'ai';
import { openai } from '@/lib/ai';
import { CHAT_SYSTEM } from '@/lib/prompts';
import { requireSession } from '@/lib/session';

export const maxDuration = 30;

export async function POST(req: Request) {
  const session = await requireSession();
  const { messages }: { messages: UIMessage[] } = await req.json();

  const result = streamText({
    model: openai('gpt-5.6-chat-latest'),
    system: CHAT_SYSTEM,
    messages: await convertToModelMessages(messages),
    maxOutputTokens: 1_000,
    experimental_telemetry: { isEnabled: true, functionId: 'edge-chat', metadata: { tenantId: session.tenantId } },
  });

  return result.toUIMessageStreamResponse();
}
