import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { Principal } from '../common/current-user.decorator';
import { CapturePaymentDto } from './dto/capture-payment.dto';

@Injectable()
export class CaptureProducer {
  constructor(@InjectQueue('payments') private readonly paymentsQueue: Queue) {}

  async enqueue(user: Principal, dto: CapturePaymentDto): Promise<void> {
    await this.paymentsQueue.add('capture', {
      tenantId: user.tenantId,
      orderId: dto.orderId,
      amount: Number(dto.amount),
      currency: dto.currency,
    });
  }
}
