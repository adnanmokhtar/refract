import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import { llmTokens } from '../metrics/metrics';

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface CompletionContext {
  tenantId: string;
  feature: 'tracking-assistant' | 'claim-triage';
  userId?: string;
}

export class GatewayError extends Error {
  constructor(readonly status: number, body: string) {
    super(`model gateway answered ${status}: ${body.slice(0, 200)}`);
  }
}

/**
 * OpenAI-compatible chat completions through the model gateway (LLM_GATEWAY_URL). The gateway bills
 * per input and output token. Used by the public tracking assistant and by claim triage.
 */
@Injectable()
export class GatewayClient {
  constructor(private readonly config: AppConfig) {}

  async complete(messages: ChatMessage[], ctx: CompletionContext): Promise<string> {
    const res = await fetch(`${this.config.llmGatewayUrl}/v1/chat/completions`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${this.config.llmGatewayKey}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ model: this.config.llmModel, messages, temperature: 0.2 }),
      signal: AbortSignal.timeout(30_000),
    });
    if (!res.ok) {
      throw new GatewayError(res.status, await res.text());
    }
    const body = (await res.json()) as {
      choices: { message: { content: string } }[];
      usage: { prompt_tokens: number; completion_tokens: number };
    };
    const labels = { tenant: ctx.tenantId, feature: ctx.feature, user_id: ctx.userId ?? 'anonymous' };
    llmTokens.inc({ ...labels, direction: 'input' }, body.usage.prompt_tokens);
    llmTokens.inc({ ...labels, direction: 'output' }, body.usage.completion_tokens);
    return body.choices[0].message.content;
  }
}
