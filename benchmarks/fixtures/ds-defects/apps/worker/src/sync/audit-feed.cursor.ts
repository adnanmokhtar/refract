import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';
import { uuidv7At } from './uuidv7-at';
import { ComplianceArchive } from '../clients/compliance-archive';

const FLOOR_LAG_MS = 2_000;

/**
 * Ships admin_actions rows to the compliance archive. admin_actions.id is a UUIDv7 minted by whichever service
 * wrote the row (api pods, ledger-jvm, notify-dotnet — each on its own host clock). The upper bound of each window
 * is computed here, on the worker's clock; the window's lower bound is the previous upper bound.
 */
@Injectable()
export class AuditFeedCursor {
  private lastUpper = '00000000-0000-7000-8000-000000000000';

  constructor(
    private readonly pool: Pool,
    private readonly archive: ComplianceArchive,
  ) {}

  @Interval(10_000)
  async tick(): Promise<void> {
    const upper = uuidv7At(Date.now() - FLOOR_LAG_MS);
    const { rows } = await this.pool.query('SELECT * FROM admin_actions WHERE id > $1 AND id <= $2 ORDER BY id', [this.lastUpper, upper]);
    await this.archive.ship(rows);
    this.lastUpper = upper;
  }
}
