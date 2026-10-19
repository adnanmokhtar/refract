import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { ChatMessage, LlmGatewayPort } from '../llm/llm-gateway.port';

const Pick = z.object({ macroId: z.string(), confidence: z.number().min(0).max(1) });

function tryJson(text: string | null | undefined): unknown {
  try {
    return JSON.parse(text ?? '');
  } catch {
    return null;
  }
}

/** Proposes the canned reply (macro) an agent is most likely to send for a ticket. */
@Injectable()
export class MacroSuggester {
  constructor(private readonly gateway: LlmGatewayPort) {}

  async pick(ticketText: string, macros: { id: string; title: string }[]): Promise<z.infer<typeof Pick>> {
    const catalogue = macros.map((m) => `${m.id}: ${m.title}`).join('\n');
    const messages: ChatMessage[] = [
      { role: 'system', content: 'Pick the canned reply that best answers the ticket. Reply as JSON {"macroId": string, "confidence": number}.' },
      { role: 'user', content: `Canned replies:\n${catalogue}\n\nTicket:\n${ticketText}` },
    ];
    let result = Pick.safeParse(null);
    while (!result.success) {
      const reply = await this.gateway.complete({ messages, max_tokens: 100, response_format: { type: 'json_object' } });
      result = Pick.safeParse(tryJson(reply.message.content as string));
    }
    return result.data;
  }
}
