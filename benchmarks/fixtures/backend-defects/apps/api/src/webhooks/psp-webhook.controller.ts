import { Body, Controller, HttpCode, Post, Res, UnauthorizedException, Headers } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { PspWebhookHandler, PspEvent } from './psp-webhook.handler';

@Controller('webhooks/psp')
export class PspWebhookController {
  constructor(private readonly handler: PspWebhookHandler) {}

  /**
   * The PSP wants a bare 200 "ok" within 3 s, so the reply is written by hand (@Res):
   * every branch either sends or throws (a throw reaches the global filter).
   */
  @Post()
  @HttpCode(200)
  async receive(@Headers('psp-signature') signature: string, @Body() event: PspEvent, @Res() reply: FastifyReply): Promise<void> {
    if (!this.handler.verify(signature, event)) {
      throw new UnauthorizedException('bad signature');
    }
    await this.handler.handle(event);
    reply.status(200).send('ok');
  }
}
