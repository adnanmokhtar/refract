import { Injectable } from '@nestjs/common';
import { StreamMeter } from '../billing/token-estimate';
import { ChatMessage, LlmGatewayPort } from '../llm/llm-gateway.port';
import { ConversationHistory } from './conversation-history';
import { SystemPromptBuilder } from './system-prompt';

@Injectable()
export class AssistantStreamService {
  constructor(
    private readonly gateway: LlmGatewayPort,
    private readonly history: ConversationHistory,
    private readonly prompts: SystemPromptBuilder,
    private readonly meter: StreamMeter,
  ) {}

  async *run(conversationId: string, text: string, user: { tenantId: string; accountId: string }): AsyncGenerator<string> {
    const system = await this.prompts.build(user.tenantId, conversationId);
    const messages: ChatMessage[] = [
      { role: 'system', content: system },
      ...(await this.history.load(conversationId, text)),
    ];
    let answer = '';
    try {
      for await (const event of this.gateway.stream({ messages, max_tokens: 800 })) {
        if (event.type === 'delta') {
          answer += event.text;
          yield event.text;
        }
      }
    } finally {
      await this.history.append(conversationId, 'assistant', answer);
      await this.meter.settle(user.accountId, JSON.stringify(messages), answer);
    }
  }
}
