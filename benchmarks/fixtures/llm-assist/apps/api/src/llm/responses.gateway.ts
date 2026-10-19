import { Injectable } from '@nestjs/common';

/** Hosted-prompt calls (the weekly workspace digest e-mail). */
@Injectable()
export class ResponsesGateway {
  private readonly base = process.env.OPENAI_BASE_URL ?? 'https://api.openai.com/v1';

  async weeklyDigest(vars: { workspace: string; stats: string }, signal?: AbortSignal): Promise<string> {
    const res = await fetch(`${this.base}/responses`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${process.env.OPENAI_API_KEY}` },
      signal,
      body: JSON.stringify({
        prompt: { id: 'pmpt_weeklydigest3', version: '3', variables: vars },
        max_output_tokens: 900,
      }),
    });
    if (!res.ok) throw new Error(`responses answered ${res.status}`);
    const body = await res.json();
    if (body.status === 'incomplete') throw new Error(`digest incomplete: ${body.incomplete_details?.reason}`);
    return body.output_text;
  }
}
