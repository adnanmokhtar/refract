import { Injectable } from '@nestjs/common';
import twilio from 'twilio';

/** WhatsApp replies to customers who opened a ticket from WhatsApp. */
@Injectable()
export class WhatsAppSender {
  private readonly client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

  async reply(to: string, body: string): Promise<string> {
    const message = await this.client.messages.create({ body, to: `whatsapp:${to}`, from: `whatsapp:${process.env.TWILIO_WHATSAPP_FROM}` });
    return message.sid;
  }
}
