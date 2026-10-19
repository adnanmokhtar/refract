import { Controller, Headers, HttpCode, Post, RawBodyRequest, Req } from '@nestjs/common';
import { FastifyRequest } from 'fastify';
import Stripe from 'stripe';

@Controller('webhooks/stripe')
export class StripeWebhookController {
  private readonly stripe = new Stripe(process.env.STRIPE_API_KEY ?? '');

  @Post()
  @HttpCode(200)
  async handle(@Req() req: RawBodyRequest<FastifyRequest>, @Headers('stripe-signature') signature: string) {
    const secret = process.env.STRIPE_WEBHOOK_SECRET;
    const event = this.stripe.webhooks.constructEvent(req.rawBody!, signature, secret!);
    return { received: event.id };
  }
}
