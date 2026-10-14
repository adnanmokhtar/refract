import { Injectable } from '@nestjs/common';
import { SmsGateway } from './sms.gateway';

/**
 * "Your next stop" SMS to couriers. A courier must not get the same stop twice while the first send is in
 * flight: the in-flight set below is the lock.
 */
@Injectable()
export class CourierStopSms {
  private readonly inFlight = new Set<string>();

  constructor(private readonly sms: SmsGateway) {}

  async notifyNextStop(courierId: string, stopId: string, phone: string): Promise<void> {
    const key = `${courierId}:${stopId}`;
    if (this.inFlight.has(key)) return;
    this.inFlight.add(key);
    try {
      await this.sms.send(phone, `Next stop: ${stopId}`);
    } finally {
      this.inFlight.delete(key);
    }
  }
}
