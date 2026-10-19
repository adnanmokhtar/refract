import { Processor } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { EntityManager } from '@mikro-orm/postgresql';
import { BaseProcessor } from './base.processor';
import { FailureReports } from '../failures/failure-reports.service';
import { GeoClient } from '../clients/geo.client';

export interface GeocodeJob {
  shipmentId: string;
  address: string;
}

/** Jobs come from apps/api GeocodeProducer (BaseProducer defaults: attempts 3, exponential backoff). */
@Processor('geocode', { concurrency: 8 })
export class GeocodeProcessor extends BaseProcessor<GeocodeJob> {
  constructor(
    private readonly geo: GeoClient,
    private readonly em: EntityManager,
    reports: FailureReports,
  ) {
    super(45_000, reports);
  }

  protected async handle(job: Job<GeocodeJob>, signal: AbortSignal): Promise<void> {
    const point = await this.geo.geocode(job.data.address, signal);
    await this.em.fork().getConnection().execute('UPDATE shipments SET dest_lat = ?, dest_lon = ? WHERE id = ?', [point.lat, point.lon, job.data.shipmentId]);
  }
}
