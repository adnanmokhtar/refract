import { Body, Controller, Post } from '@nestjs/common';
import { CapiService, ClientEvent } from './capi';

/** The server leg of the tracking wrapper: the web app posts every event here as well. */
@Controller('events')
export class EventsController {
  constructor(private readonly capi: CapiService) {}

  @Post()
  ingest(@Body() payload: ClientEvent) {
    return this.capi.forward(payload);
  }
}
