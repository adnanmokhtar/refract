import { Injectable } from '@nestjs/common';

export const EMBEDDING_MODEL = 'text-embedding-3-small';

@Injectable()
export class EmbeddingsClient {
  private readonly base = process.env.LLM_BASE_URL ?? 'http://llm-proxy.internal:4000/v1';

  async embed(text: string): Promise<number[]> {
    const res = await fetch(`${this.base}/embeddings`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${process.env.LLM_GATEWAY_KEY}` },
      body: JSON.stringify({ model: EMBEDDING_MODEL, input: text }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) throw new Error(`embeddings answered ${res.status}`);
    return (await res.json()).data[0].embedding;
  }
}
