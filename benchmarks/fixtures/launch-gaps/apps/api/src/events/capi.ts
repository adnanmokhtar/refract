import { createHash } from 'node:crypto';
import { Injectable } from '@nestjs/common';

export interface ClientEvent {
  name: string;
  data?: Record<string, unknown>;
  event_id: string;
  email?: string;
}

const sha256 = (v: string) => createHash('sha256').update(v).digest('hex');

/** Meta Conversions API. Identifiers are normalised and hashed here, before they leave our servers. */
@Injectable()
export class CapiService {
  async forward(payload: ClientEvent) {
    const user_data = payload.email ? { em: [sha256(payload.email.trim().toLowerCase())] } : {};
    const body = {
      data: [{ event_name: payload.name, event_id: payload.event_id, event_time: Math.floor(Date.now() / 1000), action_source: 'website', user_data, custom_data: payload.data ?? {} }],
    };
    await fetch(`https://graph.facebook.com/v23.0/${process.env.META_PIXEL_ID}/events?access_token=${process.env.META_CAPI_TOKEN}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
    return { forwarded: true };
  }
}
