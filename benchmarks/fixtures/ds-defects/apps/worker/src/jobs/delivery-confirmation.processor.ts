import { Processor } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { BaseProcessor } from './base.processor';
import { FailureReports } from '../failures/failure-reports.service';
import { DeliveryMailer } from '../clients/delivery-mailer';
import { CarrierClient } from '../clients/carrier.client';

export interface DeliveryConfirmationJob {
  shipmentId: string;
  customerEmail: string;
  trackingNo: string;
}

/** On "delivered": tell the customer, then close the shipment at the carrier (stops their tracking billing). */
@Processor('delivery-confirmation', { concurrency: 4 })
export class DeliveryConfirmationProcessor extends BaseProcessor<DeliveryConfirmationJob> {
  constructor(
    private readonly mailer: DeliveryMailer,
    private readonly carrierClient: CarrierClient,
    reports: FailureReports,
  ) {
    super(30_000, reports);
  }

  protected async handle(job: Job<DeliveryConfirmationJob>, signal: AbortSignal): Promise<void> {
    await this.mailer.sendDeliveredEmail(job.data.customerEmail, job.data.trackingNo, signal);
    await this.carrierClient.closeShipment(job.data.trackingNo, signal);
  }
}
