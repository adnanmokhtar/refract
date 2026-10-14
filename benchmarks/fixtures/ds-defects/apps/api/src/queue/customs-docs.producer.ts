import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { BaseProducer } from './base.producer';

export interface CustomsDocsJob {
  shipmentId: string;
}

@Injectable()
export class CustomsDocsProducer extends BaseProducer<CustomsDocsJob> {
  constructor(@InjectQueue('customs-docs') queue: Queue<CustomsDocsJob>) {
    super(queue);
  }

  async fileDocs(shipmentId: string): Promise<void> {
    await this.enqueue('file-customs-docs', { shipmentId }, { attempts: 1 });
  }
}
