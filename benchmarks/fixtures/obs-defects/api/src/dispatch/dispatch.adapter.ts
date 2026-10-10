import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { CourierClient, toCourierJob } from './courier.client';

export interface DispatchOrder {
  id: string;
  customerName: string;
  customerPhone: string;
  deliveryAddress: string;
  parcels: number;
}

@Injectable()
export class DispatchAdapter {
  constructor(
    private readonly courier: CourierClient,
    @InjectPinoLogger(DispatchAdapter.name) private readonly logger: PinoLogger,
  ) {}

  async dispatch(order: DispatchOrder): Promise<void> {
    this.logger.info(
      { orderId: order.id, name: order.customerName, phone: order.customerPhone, address: order.deliveryAddress },
      'dispatching order to courier',
    );
    await this.courier.createJob(toCourierJob(order));
  }
}
