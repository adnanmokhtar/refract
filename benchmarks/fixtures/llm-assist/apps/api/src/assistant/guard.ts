import { BadRequestException, Injectable } from '@nestjs/common';

/** Screens every inbound chat message before it reaches the assistant. */
@Injectable()
export class PromptGuard {
  async screen(text: string): Promise<void> {
    const res = await fetch('https://api.lakera.ai/v2/guard', {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${process.env.LAKERA_GUARD_KEY}` },
      body: JSON.stringify({ messages: [{ role: 'user', content: text }] }),
    });
    const verdict = await res.json();
    if (verdict.flagged) throw new BadRequestException('Message rejected');
  }
}
