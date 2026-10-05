import { Controller, Headers, HttpCode, Post, RawBodyRequest, Req, UnauthorizedException } from '@nestjs/common';
import { FastifyRequest } from 'fastify';
import { PaymentWebhookHandler } from './payment-webhook.handler';

@Controller('webhooks')
export class PaymentWebhookController {
  constructor(private readonly handler: PaymentWebhookHandler) {}

  @Post('payments')
  @HttpCode(204)
  async receive(@Req() req: RawBodyRequest<FastifyRequest>, @Headers('x-signature') signature: string) {
    if (!req.rawBody || !this.handler.verify(req.rawBody, signature)) throw new UnauthorizedException();
    await this.handler.apply(JSON.parse(req.rawBody.toString('utf8')));
  }
}
