import { stepCountIs, ToolLoopAgent } from 'ai';
import { openai } from '@/lib/ai';
import { AGENT_INSTRUCTIONS } from '@/lib/prompts';
import { requireSession } from '@/lib/session';
import { fetchPage, getCustomerProfile, sendEmail } from '@/lib/tools';

const researchAgent = new ToolLoopAgent({
  model: openai('gpt-5.6-sol'),
  instructions: AGENT_INSTRUCTIONS,
  tools: { getCustomerProfile, fetchPage, sendEmail },
  stopWhen: stepCountIs(8),
  maxOutputTokens: 1_500,
});

export async function POST(req: Request) {
  await requireSession();
  const { prompt }: { prompt: string } = await req.json();
  const result = await researchAgent.generate({ prompt, abortSignal: req.signal });
  return Response.json({ text: result.text, steps: result.steps.length });
}
