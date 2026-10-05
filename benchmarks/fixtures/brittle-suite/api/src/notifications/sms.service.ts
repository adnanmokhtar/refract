import { Injectable } from '@nestjs/common';

export interface SmsMessage {
  to: string;
  body: string;
}

export abstract class SmsGateway {
  abstract deliver(message: SmsMessage): Promise<void>;
}

@Injectable()
export class SmsService {
  constructor(private readonly gateway: SmsGateway) {}

  // One text per pickup: a second request for the same return is a no-op.
  private readonly notified = new Set<string>();

  async pickupBooked(returnId: string, phone: string, window: string): Promise<void> {
    if (this.notified.has(returnId)) return;
    this.notified.add(returnId);
    await this.gateway.deliver({ to: phone, body: `Your return pickup is booked for ${window}.` });
  }
}
