import { Injectable } from '@nestjs/common';

@Injectable()
export class ShippingRefunds {
  async refundShipping(shipmentId: string, amountMinor: number): Promise<void> {}
}
