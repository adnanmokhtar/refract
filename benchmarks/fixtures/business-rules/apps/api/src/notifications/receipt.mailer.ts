import { Injectable } from '@nestjs/common';
import nodemailer from 'nodemailer';

/** The order receipt — a transactional message the customer cannot opt out of. */
@Injectable()
export class ReceiptMailer {
  private readonly transporter = nodemailer.createTransport({ host: 'smtp.fernhollow.example', port: 587 });

  async sendReceipt(to: string, orderNumber: string, html: string) {
    return this.transporter.sendMail({ to, subject: `Your receipt for order ${orderNumber}`, html });
  }
}
