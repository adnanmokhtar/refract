import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';
import { EtaModel } from '../clients/eta-model';

/**
 * Recomputes the ETA of every open shipment from the latest scans. On a busy day (180 k open shipments) a pass
 * takes 70–110 s.
 */
@Injectable()
export class EtaRecomputeCron {
  private readonly logger = new Logger(EtaRecomputeCron.name);

  constructor(
    private readonly pool: Pool,
    private readonly model: EtaModel,
  ) {}

  @Interval(60_000)
  async recomputeAll(): Promise<void> {
    const { rows } = await this.pool.query<{ id: string }>("SELECT id FROM shipments WHERE status IN ('booked', 'in_transit')");
    for (const s of rows) {
      const eta = await this.model.predict(s.id);
      await this.pool.query('UPDATE shipments SET eta = $1, eta_version = eta_version + 1 WHERE id = $2', [eta, s.id]);
    }
    this.logger.log(`recomputed ${rows.length} ETAs`);
  }
}
