import { Injectable } from '@nestjs/common';
import { LlmGatewayPort } from '../llm/llm-gateway.port';

export const FORMULA_PROMPT_VERSION = 'report-formula@1';
const FORMULA_PROMPT =
  'Translate the column description into one JavaScript expression over `row` (fields: opened, solved, reopened, ' +
  'firstResponseMinutes). Reply with the expression only.';

/** Custom report columns: an agent describes the column in words, the model writes the expression. */
@Injectable()
export class FormulaService {
  constructor(private readonly gateway: LlmGatewayPort) {}

  async evaluate(description: string, row: Record<string, number>): Promise<number> {
    const reply = await this.gateway.complete({
      messages: [
        { role: 'system', content: FORMULA_PROMPT },
        { role: 'user', content: description },
      ],
      max_tokens: 120,
    });
    const expression = String(reply.message.content ?? '').trim();
    const compute = new Function('row', `return (${expression});`);
    return Number(compute(row));
  }
}
