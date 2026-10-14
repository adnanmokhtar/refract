import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';
import { CursorStore } from './cursor-store';
import { SearchIndex } from '../clients/search-index';

const LAG_MS = 30_000;           // longer than the longest api transaction (statement_timeout 20 s)
const FULL_RESCAN_EVERY = 720;   // ticks: one full rescan per hour heals anything the lag missed

/**
 * Indexes outbox events into search. The floor is held back by LAG_MS behind the database clock, and an hourly
 * rescan re-reads the last two hours; the index write is an upsert by event id.
 */
@Injectable()
export class OutboxFeedCursor {
  private ticks = 0;

  constructor(
    private readonly pool: Pool,
    private readonly cursors: CursorStore,
    private readonly search: SearchIndex,
  ) {}

  @Interval(5_000)
  async tick(): Promise<void> {
    this.ticks += 1;
    const rescan = this.ticks % FULL_RESCAN_EVERY === 0;
    const floor = rescan ? '00000000-0000-7000-8000-000000000000' : ((await this.cursors.get('search-outbox')) ?? '00000000-0000-7000-8000-000000000000');
    const { rows } = await this.pool.query<{ id: string; type: string; payload: unknown }>(
      `SELECT id, type, payload FROM outbox_event
        WHERE id > $1 AND created_at < now() - ($2 || ' milliseconds')::interval
          AND ($3::boolean IS FALSE OR created_at > now() - interval '2 hours')
        ORDER BY id LIMIT 1000`,
      [floor, LAG_MS, rescan],
    );
    if (rows.length === 0) return;
    await this.search.upsertEvents(rows);
    if (!rescan) await this.cursors.set('search-outbox', rows[rows.length - 1].id);
  }
}
