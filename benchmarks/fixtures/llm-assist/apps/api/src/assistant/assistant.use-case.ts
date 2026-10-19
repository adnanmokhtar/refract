import { Injectable } from '@nestjs/common';
import { CreditWalletService } from '../billing/credit-wallet.service';
import { UsageRecorder } from '../billing/usage-recorder';
import { ChatMessage, LlmGatewayPort } from '../llm/llm-gateway.port';
import { ConversationHistory } from './conversation-history';
import { MemoryService } from './memory.service';
import { SystemPromptBuilder } from './system-prompt';
import { ASSISTANT_TOOLS, AssistantTools } from './tools';

const TURN_COST_CREDITS = 1;

export interface TurnInput {
  accountId: string;
  tenantId: string;
  conversationId: string;
  turnId: string;
  text: string;
  mode: 'full' | 'read_only';
}

@Injectable()
export class AssistantUseCase {
  constructor(
    private readonly gateway: LlmGatewayPort,
    private readonly wallet: CreditWalletService,
    private readonly history: ConversationHistory,
    private readonly memory: MemoryService,
    private readonly prompts: SystemPromptBuilder,
    private readonly tools: AssistantTools,
    private readonly usage: UsageRecorder,
  ) {}

  async turn(input: TurnInput, signal?: AbortSignal): Promise<string> {
    await this.wallet.debit(input.accountId, TURN_COST_CREDITS, `turn:${input.turnId}`);

    const system = await this.prompts.build(input.tenantId, input.conversationId);
    if (input.mode === 'read_only') system.push({ type: 'text', text: 'You are in read-only mode: do not call refund_order or send_customer_email.' });
    const messages: ChatMessage[] = [
      { role: 'system', content: system },
      ...(await this.history.load(input.conversationId, input.text)),
    ];

    while (true) {
      const reply = await this.gateway.complete({ messages, tools: ASSISTANT_TOOLS, max_tokens: 800, signal });
      await this.usage.record(input.accountId, reply.usage);
      messages.push(reply.message);
      if (!reply.message.tool_calls?.length) {
        const answer = String(reply.message.content ?? '');
        await this.history.append(input.conversationId, 'assistant', answer);
        await this.memory.rememberFromTurn(input.tenantId, input.accountId, answer);
        return answer;
      }
      for (const call of reply.message.tool_calls) {
        const result = await this.tools.run(call, input);
        messages.push({ role: 'tool', tool_call_id: call.id, content: result });
      }
    }
  }
}
