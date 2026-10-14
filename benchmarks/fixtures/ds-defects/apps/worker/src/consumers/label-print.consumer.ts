import { Injectable, OnModuleInit } from '@nestjs/common';
import { Channel, ConsumeMessage } from 'amqplib';
import { amqpChannel } from '../amqp/amqp-connection';
import { LabelPrinters } from './label-printers.service';

/**
 * Sends labels to the warehouse's thermal printers. A print burst at the 16:00 carrier cut-off queues 40–60 k
 * messages within a few minutes.
 */
@Injectable()
export class LabelPrintConsumer implements OnModuleInit {
  private channel!: Channel;

  constructor(private readonly printers: LabelPrinters) {}

  async onModuleInit(): Promise<void> {
    this.channel = await amqpChannel();
    await this.channel.consume('label-print', (msg) => void this.onMessage(msg));
  }

  private async onMessage(msg: ConsumeMessage | null): Promise<void> {
    if (!msg) return;
    await this.printers.print(JSON.parse(msg.content.toString()));
    this.channel.ack(msg);
  }
}
