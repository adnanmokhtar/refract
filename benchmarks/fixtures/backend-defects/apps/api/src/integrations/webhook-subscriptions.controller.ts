import { Body, Controller, Post, Res } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { CreateWebhookSubscriptionDto } from './dto/create-webhook-subscription.dto';

@Controller('webhook-subscriptions')
export class WebhookSubscriptionsController {
  @Post()
  async create(@Body() dto: CreateWebhookSubscriptionDto, @Res({ passthrough: true }) reply: FastifyReply): Promise<{ id: string }> {
    const id = crypto.randomUUID();
    reply.status(201).header('Location', `/v1/webhook-subscriptions/${id}`);
    return { id, ...dto };
  }
}
