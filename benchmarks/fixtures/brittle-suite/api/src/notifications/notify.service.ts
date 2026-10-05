import { Injectable } from '@nestjs/common';
import { Mailer } from './mailer.port';

@Injectable()
export class NotifyService {
  constructor(private readonly mailer: Mailer) {}

  // The email IS the outcome of this use case: nothing else is written.
  async refundApproved(email: string, orderNumber: string, amount: string): Promise<void> {
    await this.mailer.send({ to: email, template: 'refund-approved', vars: { orderNumber, amount } });
  }
}
