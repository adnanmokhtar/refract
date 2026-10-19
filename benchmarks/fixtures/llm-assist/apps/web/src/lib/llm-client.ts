import OpenAI from 'openai';
import { env } from '../env';

/** Used by the reply composer's "rephrase" button to avoid a round trip through the API. */
export const browserLlm = new OpenAI({ apiKey: env.openaiKey, dangerouslyAllowBrowser: true });

export async function rephrase(text: string, tone: 'friendly' | 'formal'): Promise<string> {
  const completion = await browserLlm.chat.completions.create({
    model: 'gpt-5.6-luna',
    max_completion_tokens: 400,
    messages: [
      { role: 'system', content: `Rewrite the support reply in a ${tone} tone. Keep facts unchanged.` },
      { role: 'user', content: text },
    ],
  });
  return completion.choices[0].message.content ?? text;
}
