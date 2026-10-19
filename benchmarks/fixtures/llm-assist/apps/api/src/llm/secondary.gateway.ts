import { Injectable } from '@nestjs/common';
import { ChatRequest, ChatResult } from './llm-gateway.port';

/** Second upstream behind the same proxy; used when the primary call throws. */
@Injectable()
export class SecondaryGateway {
  private readonly base = process.env.SECONDARY_LLM_BASE_URL ?? 'http://llm-proxy.internal:4000/secondary/v1';

  async complete(req: ChatRequest): Promise<ChatResult> {
    const res = await fetch(`${this.base}/chat/completions`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${process.env.SECONDARY_LLM_KEY}` },
      signal: req.signal,
      body: JSON.stringify({
        model: 'claude-sonnet-5-5',
        messages: req.messages,
        tools: req.tools,
        max_tokens: req.max_tokens ?? 1024,
      }),
    });
    if (!res.ok) throw new Error(`secondary gateway answered ${res.status}`);
    const body = await res.json();
    return { message: body.choices[0].message, finishReason: body.choices[0].finish_reason, usage: body.usage };
  }
}
