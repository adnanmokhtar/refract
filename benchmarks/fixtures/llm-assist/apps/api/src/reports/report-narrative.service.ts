import { Injectable } from '@nestjs/common';
import OpenAI from 'openai';
import { NARRATIVE_PROMPT, NARRATIVE_PROMPT_VERSION } from './narrative.prompt';

export interface MonthlyStats {
  workspace: string;
  month: string;
  ticketsOpened: number;
  ticketsSolved: number;
  medianFirstResponseMinutes: number;
  byChannel: Record<string, number>;
}

@Injectable()
export class ReportNarrativeService {
  private readonly openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY, timeout: 20_000, maxRetries: 1 });

  async narrate(stats: MonthlyStats): Promise<{ text: string; promptVersion: string }> {
    const completion = await this.openai.chat.completions.create({
      model: 'gpt-5.6-terra',
      max_completion_tokens: 700,
      messages: [
        { role: 'system', content: NARRATIVE_PROMPT },
        { role: 'user', content: JSON.stringify(stats) },
      ],
    });
    const choice = completion.choices[0];
    if (choice.finish_reason !== 'stop' || choice.message.refusal) {
      throw new Error(`narrative not produced: ${choice.finish_reason}`);
    }
    return { text: choice.message.content ?? '', promptVersion: NARRATIVE_PROMPT_VERSION };
  }
}
