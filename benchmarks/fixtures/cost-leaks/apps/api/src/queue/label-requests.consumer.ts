import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { DeleteMessageCommand, Message, ReceiveMessageCommand, SQSClient } from '@aws-sdk/client-sqs';
import { AppConfig } from '../config/app-config';
import { LabelService } from '../labels/label.service';
import { logger } from '../logging/logger';

/** Label purchase requests from the merchant dashboard and the bulk importer (qw-label-requests). */
@Injectable()
export class LabelRequestsConsumer implements OnModuleInit, OnModuleDestroy {
  private readonly sqs = new SQSClient({ region: this.config.region });
  private timer?: NodeJS.Timeout;

  constructor(private readonly config: AppConfig, private readonly labels: LabelService) {}

  onModuleInit(): void {
    this.timer = setInterval(() => void this.pollOnce(), 1_000);
  }

  onModuleDestroy(): void {
    clearInterval(this.timer);
  }

  private async pollOnce(): Promise<void> {
    const out = await this.sqs.send(new ReceiveMessageCommand({ QueueUrl: this.config.labelQueueUrl, MaxNumberOfMessages: 10 }));
    for (const message of out.Messages ?? []) {
      await this.handle(message);
    }
  }

  private async handle(message: Message): Promise<void> {
    try {
      await this.labels.purchase(JSON.parse(message.Body ?? '{}'));
      await this.sqs.send(new DeleteMessageCommand({ QueueUrl: this.config.labelQueueUrl, ReceiptHandle: message.ReceiptHandle }));
    } catch (err) {
      logger.warn('label request failed; SQS will redeliver', { messageId: message.MessageId, err: String(err) });
    }
  }
}
