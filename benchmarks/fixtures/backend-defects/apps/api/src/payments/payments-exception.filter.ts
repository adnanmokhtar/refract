import { ArgumentsHost, Catch, ExceptionFilter } from '@nestjs/common';
import type { Response } from 'express';
import { PaymentDeclinedError } from '../common/errors';

/** Declines answer 402 with the PSP's decline code. */
@Catch(PaymentDeclinedError)
export class PaymentsExceptionFilter implements ExceptionFilter {
  catch(exception: PaymentDeclinedError, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<Response>();
    res.status(402).json({ error: { code: exception.code, message: exception.message } });
  }
}
