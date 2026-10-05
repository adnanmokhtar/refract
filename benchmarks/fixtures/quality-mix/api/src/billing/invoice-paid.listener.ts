import { Injectable } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { BILLING_EVENTS, RenewedEvent } from './billing.events';
import { log } from '../lib/logger';

@Injectable()
export class InvoicePaidListener {
  @OnEvent(BILLING_EVENTS.renewed)
  onRenewed(event: RenewedEvent): void {
    log.log(`renewal ${event.subscriptionId} charged ${event.amountCents}`);
  }
}
