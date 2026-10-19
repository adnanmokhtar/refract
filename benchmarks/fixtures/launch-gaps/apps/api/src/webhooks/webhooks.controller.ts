import { BadRequestException, Controller, Headers, Post, RawBodyRequest, Req } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import Stripe from 'stripe';
import { Public } from '../auth/public.decorator';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY ?? '');

@Controller('webhooks')
export class WebhooksController {
  constructor(private readonly events: EventEmitter2) {}

  /** Stripe calls this endpoint (configured in the Stripe dashboard); nothing in the app does. */
  @Public()
  @Post('stripe')
  async stripe(@Req() req: RawBodyRequest<{ rawBody: Buffer }>, @Headers('stripe-signature') sig: string) {
    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(req.rawBody!, sig, process.env.STRIPE_WEBHOOK_SECRET ?? '');
    } catch {
      throw new BadRequestException('bad signature');
    }
    await this.events.emitAsync(`stripe.${event.type}`, event);
    return { received: true };
  }
}
