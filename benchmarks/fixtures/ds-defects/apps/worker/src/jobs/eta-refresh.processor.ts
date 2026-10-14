import { Processor } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { EntityManager } from '@mikro-orm/postgresql';
import { BaseProcessor } from './base.processor';
import { FailureReports } from '../failures/failure-reports.service';
import { EtaClient } from '../clients/eta.client';

export interface EtaRefreshJob {
  shipmentId: string;
  trackingNo: string;
}

@Processor('eta-refresh', { concurrency: 4 })
export class EtaRefreshProcessor extends BaseProcessor<EtaRefreshJob> {
  constructor(
    private readonly eta: EtaClient,
    private readonly em: EntityManager,
    reports: FailureReports,
  ) {
    super(20_000, reports);
  }

  protected async handle(job: Job<EtaRefreshJob>, signal: AbortSignal): Promise<void> {
    const { eta } = await this.eta.fetchEta(job.data.trackingNo, signal);
    await this.em.fork().getConnection().execute('UPDATE shipments SET eta = ? WHERE id = ?', [eta, job.data.shipmentId]);
  }
}
