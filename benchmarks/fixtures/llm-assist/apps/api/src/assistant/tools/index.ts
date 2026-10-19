import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import { createTransport } from 'nodemailer';
import { PaymentsClient } from '../../orders/payments.client';
import { ToolCall } from '../../llm/llm-gateway.port';
import type { TurnInput } from '../assistant.use-case';
import { lookupOrder } from './lookup-order.tool';
import { readAttachment } from './read-attachment.tool';
import { refundOrder } from './refund-order.tool';
import { sendCustomerEmail } from './send-email.tool';

export { ASSISTANT_TOOLS } from './specs';

@Injectable()
export class AssistantTools {
  private readonly mailer = createTransport({ host: process.env.SMTP_HOST, port: 587 });

  constructor(
    private readonly em: EntityManager,
    private readonly payments: PaymentsClient,
  ) {}

  async run(call: ToolCall, ctx: TurnInput): Promise<string> {
    const args = JSON.parse(call.function.arguments);
    switch (call.function.name) {
      case 'lookup_order':
        return lookupOrder(this.em, args);
      case 'refund_order':
        return refundOrder(this.em, this.payments, args, ctx);
      case 'send_customer_email':
        return sendCustomerEmail(this.mailer, args);
      case 'read_attachment':
        return readAttachment(args);
      default:
        return JSON.stringify({ error: `unknown tool ${call.function.name}` });
    }
  }
}
