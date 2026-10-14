import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class SearchIndex {
  async upsertEvents(rows: Array<{ id: string }>): Promise<void> {
    await request(`${process.env.SEARCH_URL}/events/_bulk`, { method: 'POST', body: JSON.stringify(rows.map((r) => ({ index: { _id: r.id }, doc: r }))) });
  }
}
