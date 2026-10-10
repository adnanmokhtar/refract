import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { captureDuration, paymentAttempts } from '../metrics/metrics';
import { PaymentRepository } from './payment.repository';
import { PspClient } from './psp.client';

@Injectable()
export class CaptureService {
  constructor(
    private readonly psp: PspClient,
    private readonly payments: PaymentRepository,
    @InjectPinoLogger(CaptureService.name) private readonly logger: PinoLogger,
  ) {}

  async capture(paymentId: string): Promise<void> {
    const startedAt = Date.now();
    try {
      const result = await this.psp.capture(paymentId);
      await this.payments.markCaptured(paymentId, result.pspReference);
      paymentAttempts.inc({ outcome: 'captured' });
    } catch (err) {
      paymentAttempts.inc({ outcome: 'error' });
      this.logger.error('capture failed', err);
      throw err;
    } finally {
      captureDuration.observe(Date.now() - startedAt);
    }
  }

  async markSettled(paymentId: string, settlementId: string): Promise<void> {
    await this.payments.markSettled(paymentId, settlementId);
    this.logger.info({ paymentId, settlementId }, 'payment settled');
  }

  async findOpen(limit = 100): Promise<string[]> {
    return this.payments.findOpenIds(limit);
  }

  async voidAuthorization(paymentId: string): Promise<void> {
    try {
      await this.psp.void(paymentId);
      await this.payments.markVoided(paymentId);
    } catch (err) {
      this.logger.error({ err, paymentId }, 'void failed');
      throw err;
    }
  }
}
