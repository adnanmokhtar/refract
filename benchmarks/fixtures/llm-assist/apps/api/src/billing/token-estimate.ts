import { Injectable } from '@nestjs/common';
import { UsageRecorder } from './usage-recorder';

/** Rough token count used where the stream does not hand usage back. */
export function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

@Injectable()
export class StreamMeter {
  constructor(private readonly usage: UsageRecorder) {}

  async settle(accountId: string, promptText: string, answer: string): Promise<void> {
    await this.usage.record(accountId, {
      prompt_tokens: estimateTokens(promptText),
      completion_tokens: estimateTokens(answer),
    });
  }
}
