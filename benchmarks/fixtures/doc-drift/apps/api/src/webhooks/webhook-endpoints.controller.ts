import { Body, Controller, Get, Post } from '@nestjs/common';

import { WebhooksService } from './webhooks.service';

@Controller('webhooks/endpoints')
export class WebhookEndpointsController {
  constructor(private readonly webhooksService: WebhooksService) {}

  @Get()
  list() {
    return this.webhooksService.listEndpoints();
  }

  @Post()
  create(@Body() body: { url: string; events: string[] }) {
    return this.webhooksService.createEndpoint(body.url, body.events);
  }
}
