import { HttpException, Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { PspClient } from '../payments/psp.client';

/** 402 to the client; HttpExceptionFilter logs it with its `cause` (the PSP error, stack included). */
export class ChargeFailedError extends HttpException {
  constructor(chargeId: string, options: { cause: unknown }) {
    super({ statusCode: 402, message: `charge ${chargeId} was declined` }, 402, options);
  }
}

@Injectable()
export class ChargesService {
  constructor(
    private readonly psp: PspClient,
    @InjectPinoLogger(ChargesService.name) private readonly logger: PinoLogger,
  ) {}

  async charge(chargeId: string, amountCents: number): Promise<void> {
    try {
      await this.psp.charge(chargeId, amountCents);
    } catch (e) {
      this.logger.warn('charge declined, rethrowing with the PSP error as its cause');
      throw new ChargeFailedError(chargeId, { cause: e });
    }
  }
}
