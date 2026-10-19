import { Injectable } from '@nestjs/common';
import { LabelArchiveClient } from './label-archive.client';
import { LabelJobPoller } from './label-job.poller';
import { LabelRendererClient } from './label-renderer.client';
import { CarrierClient } from '../tracking/carrier.client';

export interface LabelPurchase {
  shipmentId: string;
  carrierService: string;
  format: 'pdf-a6' | 'zpl';
}

@Injectable()
export class LabelService {
  constructor(
    private readonly carrier: CarrierClient,
    private readonly poller: LabelJobPoller,
    private readonly renderer: LabelRendererClient,
    private readonly archive: LabelArchiveClient,
  ) {}

  async purchase(req: LabelPurchase): Promise<string> {
    const jobId = await this.carrier.createLabelJob(req.shipmentId, req.carrierService);
    const label = await this.poller.waitForLabel(jobId);
    const pdf = await this.renderer.render({ shipmentId: req.shipmentId, format: req.format, carrierLabelUrl: label.pdfUrl });
    return this.archive.archive(req.shipmentId, label.trackingNumber, pdf);
  }
}
