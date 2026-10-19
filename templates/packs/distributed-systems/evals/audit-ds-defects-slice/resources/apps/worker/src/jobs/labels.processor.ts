import { Processor } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { BaseProcessor } from './base.processor';
import { FailureReports } from '../failures/failure-reports.service';
import { ClaimsLedger } from '../outbox/claims-ledger';
import { CarrierLabels } from '../clients/carrier-labels';

export interface LabelJob {
  shipmentId: string;
  carrier: string;
}

/**
 * Buys the shipping label from the carrier (a billable carrier transaction per call) and stores the PDF.
 * The claim keeps a re-run from buying a second label.
 */
@Processor('labels', { concurrency: 4 })
export class LabelsProcessor extends BaseProcessor<LabelJob> {
  constructor(
    private readonly claims: ClaimsLedger,
    private readonly labels: CarrierLabels,
    reports: FailureReports,
  ) {
    super(60_000, reports);
  }

  protected async handle(job: Job<LabelJob>, signal: AbortSignal): Promise<void> {
    const fresh = await this.claims.reserve(`label:${job.id}`);
    if (!fresh) return;
    const label = await this.labels.buy(job.data.carrier, job.data.shipmentId, signal);
    await this.labels.store(job.data.shipmentId, label);
  }
}
