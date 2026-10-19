import { Controller, Get, NotFoundException, Param, Res } from '@nestjs/common';
import type { FastifyReply } from 'fastify';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const WIDGET_DIR = join(__dirname, '..', '..', 'widget-dist');

// The embeddable tracking widget merchants put on their order-status pages. The build names every
// bundle by content hash (widget.3f9a1c2e.js), and the embed snippet always points at the current one.
@Controller('widget')
export class WidgetController {
  @Get(':file')
  async asset(@Param('file') file: string, @Res() reply: FastifyReply) {
    if (!/^widget\.[0-9a-f]{8}\.(js|css)$/.test(file)) {
      throw new NotFoundException();
    }
    const body = await readFile(join(WIDGET_DIR, file));
    reply.header('cache-control', 'no-store');
    return reply.type(file.endsWith('.css') ? 'text/css' : 'application/javascript').send(body);
  }
}
