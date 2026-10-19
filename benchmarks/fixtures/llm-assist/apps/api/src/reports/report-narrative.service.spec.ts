import nock from 'nock';
import OpenAI from 'openai';
import recorded from './__recordings__/narrative-2026-09.json';
import { ReportNarrativeService } from './report-narrative.service';

describe('ReportNarrativeService', () => {
  beforeAll(() => nock.disableNetConnect());
  afterEach(() => nock.cleanAll());

  it('replays the recorded September response through the SDK', async () => {
    nock('https://api.openai.com').post('/v1/chat/completions').reply(200, recorded);
    const client = new OpenAI({ apiKey: 'test', maxRetries: 0 });

    const completion = await client.chat.completions.create({ model: 'gpt-5.6-terra', messages: [{ role: 'user', content: '{}' }] });

    expect(completion.choices[0].finish_reason).toBe('stop');
  });

  it('returns the narrative text and its prompt version', async () => {
    nock('https://api.openai.com').post('/v1/chat/completions').reply(200, recorded);
    const service = new ReportNarrativeService();

    const out = await service.narrate({
      workspace: 'Northwind Bikes',
      month: '2026-09',
      ticketsOpened: 430,
      ticketsSolved: 412,
      medianFirstResponseMinutes: 33,
      byChannel: { email: 260, chat: 170 },
    });

    expect(out.promptVersion).toBe('monthly-narrative@2');
    expect(out.text).toContain('412 tickets solved');
  });
});
