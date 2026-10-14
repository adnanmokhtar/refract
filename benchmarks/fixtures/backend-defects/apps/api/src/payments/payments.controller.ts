import { Body, Controller, HttpCode, Post, UseFilters, UseInterceptors } from '@nestjs/common';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { Idempotent, IdempotencyInterceptor } from '../common/idempotency/idempotency.interceptor';
import { CapturePaymentDto } from './dto/capture-payment.dto';
import { CaptureProducer } from './capture.producer';
import { PaymentsExceptionFilter } from './payments-exception.filter';

@Controller('payments')
@UseInterceptors(IdempotencyInterceptor)
@UseFilters(PaymentsExceptionFilter)
export class PaymentsController {
  constructor(private readonly captures: CaptureProducer) {}

  @Post('captures')
  @HttpCode(202)
  @Idempotent()
  async capture(@CurrentUser() user: Principal, @Body() dto: CapturePaymentDto): Promise<{ queued: boolean }> {
    await this.captures.enqueue(user, dto);
    return { queued: true };
  }
}
