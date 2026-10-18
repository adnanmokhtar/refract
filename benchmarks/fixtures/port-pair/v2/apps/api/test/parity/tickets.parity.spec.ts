import { expect, it } from 'vitest';
import { slaSummary } from '../../src/tickets/sla';
import { corpus, tolerance } from './support/harness';
import { replay } from './support/replay';
import { describeV1 } from './support/v1';
import { v1 } from './support/v1-client';

describeV1('tickets parity', () => {
  it('answers every recorded V1 tickets request the same way', async () => {
    for (const req of corpus<{ method: string; path: string; body?: unknown }>('tickets-http')) {
      const [a, b] = await replay(req);
      expect(b.status).toBe(a.status);
      if (tolerance.compare.tickets === 'status+body') {
        expect(b.body).toEqual(a.body);
      }
    }
  });

  it('computes SLA hours like V1 over the SLA corpus', async () => {
    const now = new Date('2026-10-01T09:00:00Z');
    for (const c of corpus<{ minutes_left: number }>('sla')) {
      const ticket = { id: 't', dueAt: new Date(now.getTime() + c.minutes_left * 60_000) } as never;
      expect(String(slaSummary(ticket, now).hours)).toBe(await v1.slaHours(c.minutes_left));
    }
  });
});
