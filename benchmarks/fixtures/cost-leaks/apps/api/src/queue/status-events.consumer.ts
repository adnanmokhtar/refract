import { Injectable, OnApplicationShutdown, OnModuleInit } from '@nestjs/common';
import { DeleteMessageBatchCommand, ReceiveMessageCommand, SQSClient } from '@aws-sdk/client-sqs';
import { AppConfig } from '../config/app-config';
import { NotificationsService } from '../notifications/notifications.service';

/** Shipment status changes (qw-status-events) → recipient notifications. */
@Injectable()
export class StatusEventsConsumer implements OnModuleInit, OnApplicationShutdown {
  private readonly sqs = new SQSClient({ region: this.config.region });
  private stopping = false;

  constructor(private readonly config: AppConfig, private readonly notifications: NotificationsService) {}

  onModuleInit(): void {
    void this.run();
  }

  onApplicationShutdown(): void {
    this.stopping = true;
  }

  private async run(): Promise<void> {
    while (!this.stopping) {
      const out = await this.sqs.send(new ReceiveMessageCommand({
        QueueUrl: this.config.statusQueueUrl,
        MaxNumberOfMessages: 10,
        WaitTimeSeconds: 20,
      }));
      const done: { Id: string; ReceiptHandle: string }[] = [];
      for (const m of out.Messages ?? []) {
        await this.notifications.onStatusChange(JSON.parse(m.Body ?? '{}'));
        done.push({ Id: m.MessageId!, ReceiptHandle: m.ReceiptHandle! });
      }
      if (done.length > 0) {
        await this.sqs.send(new DeleteMessageBatchCommand({ QueueUrl: this.config.statusQueueUrl, Entries: done }));
      }
    }
  }
}
