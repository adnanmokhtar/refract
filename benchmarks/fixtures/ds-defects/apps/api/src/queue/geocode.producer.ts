import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { BaseProducer } from './base.producer';

export interface GeocodeJob {
  shipmentId: string;
  address: string;
}

/** Geocodes delivery addresses for route planning (worker: src/jobs/geocode.processor.ts). */
@Injectable()
export class GeocodeProducer extends BaseProducer<GeocodeJob> {
  constructor(@InjectQueue('geocode') queue: Queue<GeocodeJob>) {
    super(queue);
  }

  async geocode(shipmentId: string, address: string): Promise<void> {
    await this.enqueue('geocode', { shipmentId, address });
  }
}
