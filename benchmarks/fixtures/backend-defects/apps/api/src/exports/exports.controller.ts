import { Controller, Get, Param, Res } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { ExportsService } from './exports.service';

@Controller('exports')
export class ExportsController {
  constructor(private readonly exportsService: ExportsService) {}

  /** CSV when ready; otherwise the job status as JSON. */
  @Get(':id')
  async download(@Param('id') id: string, @Res() reply: FastifyReply): Promise<unknown> {
    const job = await this.exportsService.find(id);
    if (job.status === 'ready') {
      reply.header('content-type', 'text/csv').send(await this.exportsService.csv(id));
      return;
    }
    return { id, status: job.status };
  }
}
