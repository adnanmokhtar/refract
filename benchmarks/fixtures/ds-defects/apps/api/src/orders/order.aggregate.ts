import { AggregateRoot } from '@nestjs/cqrs';
import { CustomerMailer } from '../notifications/customer-mailer';

export class OrderPlaced {
  constructor(public readonly orderId: string, public readonly lines: Array<{ sku: string; qty: number }>) {}
}
export class OrderPacked {
  constructor(public readonly orderId: string, public readonly parcels: number) {}
}
export class OrderShipped {
  constructor(public readonly orderId: string, public readonly trackingNo: string, public readonly customerEmail: string) {}
}

/** Event-sourced order (stream `order-<id>` in KurrentDB). State is rebuilt with loadFromHistory on every command. */
export class OrderAggregate extends AggregateRoot {
  status: 'new' | 'placed' | 'packed' | 'shipped' = 'new';
  parcels = 0;
  trackingNo?: string;

  constructor(public readonly id: string, private readonly mailer: CustomerMailer) {
    super();
  }

  ship(trackingNo: string, customerEmail: string): void {
    if (this.status !== 'packed') throw new Error(`order ${this.id} is ${this.status}, not packed`);
    this.apply(new OrderShipped(this.id, trackingNo, customerEmail));
  }

  onOrderPlaced(): void {
    this.status = 'placed';
  }

  onOrderPacked(event: OrderPacked): void {
    this.status = 'packed';
    this.parcels = event.parcels;
  }

  onOrderShipped(event: OrderShipped): void {
    this.status = 'shipped';
    this.trackingNo = event.trackingNo;
    this.mailer.sendShippedEmail(event.customerEmail, event.trackingNo);
  }
}
