import { Injectable } from '@nestjs/common';
import nodemailer from 'nodemailer';

/** The merchant's weekly newsletter campaign to subscribed customers. */
@Injectable()
export class NewsletterSender {
  private readonly transporter = nodemailer.createTransport({ host: 'smtp.fernhollow.example', port: 587 });

  async sendCampaign(recipients: string[], subject: string, html: string) {
    for (const to of recipients) {
      await this.transporter.sendMail({ from: 'news@fernhollow.example', to, subject, html });
    }
  }
}
