import {
  BadRequestException,
  Controller,
  Headers,
  HttpCode,
  Post,
  RawBodyRequest,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'crypto';
import { Request } from 'express';
import { config } from '../config';
import { PrismaService } from '../prisma/prisma.service';

interface PaymentEvent {
  type: 'charge.succeeded' | 'charge.refunded';
  data: { orderId: string; amountCents: number };
}

interface ShippingEvent {
  type: 'shipment.delivered';
  data: { orderId: string; trackingNumber: string };
}

// Provider callbacks. Both providers sign the raw request body with HMAC-SHA256 and send
// the hex digest in a header.
@Controller('webhooks')
export class WebhooksController {
  constructor(private readonly prisma: PrismaService) {}

  @Post('payments')
  @HttpCode(204)
  async payments(@Req() req: RawBodyRequest<Request>, @Headers('x-payments-signature') signature?: string) {
    if (!req.rawBody) throw new BadRequestException();
    const expected = createHmac('sha256', config.webhooks.paymentsSecret).update(req.rawBody).digest('hex');
    if (signature !== expected) throw new UnauthorizedException('Invalid signature');

    const event = JSON.parse(req.rawBody.toString('utf8')) as PaymentEvent;
    if (event.type === 'charge.succeeded') {
      await this.prisma.order.updateMany({
        where: { id: event.data.orderId, status: 'PENDING', totalCents: event.data.amountCents },
        data: { status: 'PAID' },
      });
    } else if (event.type === 'charge.refunded') {
      await this.prisma.order.updateMany({
        where: { id: event.data.orderId, status: { in: ['PAID', 'SHIPPED'] } },
        data: { status: 'REFUNDED' },
      });
    }
  }

  @Post('shipping')
  @HttpCode(204)
  async shipping(@Req() req: RawBodyRequest<Request>, @Headers('x-shipping-signature') signature?: string) {
    if (!req.rawBody) throw new BadRequestException();
    const expected = createHmac('sha256', config.webhooks.shippingSecret).update(req.rawBody).digest();
    const given = Buffer.from(signature ?? '', 'hex');
    if (given.length !== expected.length || !timingSafeEqual(given, expected)) {
      throw new UnauthorizedException('Invalid signature');
    }

    const event = JSON.parse(req.rawBody.toString('utf8')) as ShippingEvent;
    if (event.type === 'shipment.delivered') {
      await this.prisma.order.updateMany({
        where: { id: event.data.orderId, status: 'PAID' },
        data: { status: 'SHIPPED' },
      });
    }
  }
}
