import { Injectable } from '@nestjs/common';
import { ChatRequest, ChatResult, LlmGatewayPort, StreamEvent } from './llm-gateway.port';
import { SecondaryGateway } from './secondary.gateway';
import { sseData } from './sse';

export class GatewayHttpError extends Error {
  constructor(readonly status: number) {
    super(`llm gateway answered ${status}`);
  }
}

@Injectable()
export class OpenAiCompatGateway extends LlmGatewayPort {
  private readonly base = process.env.LLM_BASE_URL ?? 'http://llm-proxy.internal:4000/v1';
  private readonly model = process.env.CHAT_MODEL!;

  constructor(private readonly secondary: SecondaryGateway) {
    super();
  }

  async complete(req: ChatRequest): Promise<ChatResult> {
    try {
      const res = await fetch(`${this.base}/chat/completions`, {
        method: 'POST',
        headers: this.headers(),
        signal: req.signal,
        body: JSON.stringify({
          model: this.model,
          messages: req.messages,
          tools: req.tools,
          tool_choice: req.tools?.length ? 'auto' : undefined,
          response_format: req.response_format,
          max_tokens: req.max_tokens ?? 1024,
        }),
      });
      if (!res.ok) throw new GatewayHttpError(res.status);
      const body = await res.json();
      const choice = body.choices[0];
      return { message: choice.message, finishReason: choice.finish_reason, usage: body.usage };
    } catch {
      return this.secondary.complete(req);
    }
  }

  async *stream(req: ChatRequest): AsyncGenerator<StreamEvent> {
    const res = await fetch(`${this.base}/chat/completions`, {
      method: 'POST',
      headers: this.headers(),
      signal: req.signal,
      body: JSON.stringify({
        model: this.model,
        messages: req.messages,
        max_tokens: req.max_tokens ?? 1024,
        stream: true,
      }),
    });
    if (!res.ok || !res.body) throw new GatewayHttpError(res.status);
    for await (const data of sseData(res.body)) {
      if (data === '[DONE]') break;
      const chunk = JSON.parse(data);
      const text = chunk.choices?.[0]?.delta?.content;
      if (text) yield { type: 'delta', text };
    }
    yield { type: 'done' };
  }

  private headers(): Record<string, string> {
    return { 'content-type': 'application/json', authorization: `Bearer ${process.env.LLM_GATEWAY_KEY}` };
  }
}
