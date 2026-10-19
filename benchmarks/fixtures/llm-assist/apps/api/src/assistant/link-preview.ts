import { LlmGatewayPort } from '../llm/llm-gateway.port';

export interface LinkPreview {
  url: string;
  title: string | null;
}

/** Shows a preview card for the most relevant link in a customer's message. */
export async function previewFirstLink(gateway: LlmGatewayPort, message: string): Promise<LinkPreview | null> {
  const reply = await gateway.complete({
    messages: [{ role: 'user', content: `Return only the single most relevant URL in this message, nothing else:\n${message}` }],
    max_tokens: 60,
  });
  const url = String(reply.message.content ?? '').trim();
  if (!url) return null;
  const page = await fetch(url, { redirect: 'follow' });
  const html = await page.text();
  const title = /<title>([^<]*)<\/title>/i.exec(html)?.[1] ?? null;
  return { url, title };
}
