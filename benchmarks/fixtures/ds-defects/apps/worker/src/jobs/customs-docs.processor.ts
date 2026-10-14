import { Processor } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { EntityManager } from '@mikro-orm/postgresql';
import { BaseProcessor } from './base.processor';
import { FailureReports } from '../failures/failure-reports.service';
import { CustomsClient } from '../clients/customs.client';

export interface CustomsDocsJob {
  shipmentId: string;
}

const JOB_TIMEOUT_MS = 30_000;

/** Files the export declaration for an international shipment and stores the MRN on the shipment. */
@Processor('customs-docs', { concurrency: 2 })
export class CustomsDocsProcessor extends BaseProcessor<CustomsDocsJob> {
  constructor(
    private readonly customs: CustomsClient,
    private readonly em: EntityManager,
    reports: FailureReports,
  ) {
    super(JOB_TIMEOUT_MS, reports);
  }

  protected async handle(job: Job<CustomsDocsJob>): Promise<void> {
    const declaration = await this.buildDeclaration(job.data.shipmentId);
    const { mrn } = await this.customs.fileDeclaration(job.data.shipmentId, declaration);
    await this.em.fork().getConnection().execute('UPDATE shipments SET customs_mrn = ? WHERE id = ?', [mrn, job.data.shipmentId]);
  }

  private async buildDeclaration(shipmentId: string): Promise<Record<string, unknown>> {
    const [row] = await this.em.fork().getConnection().execute('SELECT customs_payload FROM shipments WHERE id = ?', [shipmentId]);
    return row.customs_payload as Record<string, unknown>;
  }
}
