import { Injectable } from '@nestjs/common';
import nodemailer from 'nodemailer';

@Injectable()
export class Mailer {
  private readonly transporter = nodemailer.createTransport({ host: 'smtp.fernhollow.example', port: 587 });

  async sendVerificationEmail(to: string, token: string) {
    return this.transporter.sendMail({ to, subject: 'Verify your e-mail', text: `https://app.fernhollow.example/verify/${token}` });
  }
}
