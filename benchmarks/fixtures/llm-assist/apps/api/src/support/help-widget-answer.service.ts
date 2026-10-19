import { Injectable, UnprocessableEntityException } from '@nestjs/common';
import { LlmGatewayPort } from '../llm/llm-gateway.port';

export const HELP_WIDGET_PROMPT_VERSION = 'help-widget@5';
const HELP_WIDGET_PROMPT =
  'You answer customers in the help widget of an online shop. Be brief and friendly; greet the customer by first name. ' +
  'If the question needs an order lookup or a refund, say an agent will follow up.';

/** The customer's own question, from the logged-in help widget. */
@Injectable()
export class HelpWidgetAnswerService {
  constructor(private readonly gateway: LlmGatewayPort) {}

  async answer(session: { firstName: string }, question: string): Promise<string> {
    const reply = await this.gateway.complete({
      messages: [
        { role: 'system', content: HELP_WIDGET_PROMPT },
        { role: 'user', content: `(${session.firstName}) ${question}` },
      ],
      max_tokens: 400,
    });
    if (reply.finishReason !== 'stop' || reply.message.refusal) throw new UnprocessableEntityException('No answer');
    return String(reply.message.content ?? '');
  }
}
