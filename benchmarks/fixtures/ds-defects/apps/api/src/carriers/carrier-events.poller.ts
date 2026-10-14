import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { SQSClient } from '@aws-sdk/client-sqs';
import { Consumer } from 'sqs-consumer';
import { CarrierScanSchema, TrackingService } from './tracking.service';

/**
 * Long-lived poller of the carrier-events SQS queue (deploy/terraform/sqs-carrier-events.tf: visibility 120 s,
 * DLQ after 5 receives). Each message is one tracking scan from a carrier.
 */
@Injectable()
export class CarrierEventsPoller implements OnModuleInit, OnModuleDestroy {
  private consumer?: Consumer;

  constructor(private readonly tracking: TrackingService) {}

  onModuleInit(): void {
    this.consumer = Consumer.create({
      queueUrl: process.env.CARRIER_EVENTS_QUEUE_URL!,
      sqs: new SQSClient({}),
      batchSize: 10,
      handleMessageTimeout: 60_000,
      heartbeatInterval: 20,
      visibilityTimeout: 120,
      handleMessage: async (message) => {
        const scan = CarrierScanSchema.parse(JSON.parse(message.Body ?? '{}'));
        await this.tracking.applyScan(scan);
      },
    });
    this.consumer.start();
  }

  onModuleDestroy(): void {
    this.consumer?.stop({ abort: false });
  }
}
