import { Controller, Get, NotFoundException, Param, Res } from '@nestjs/common';
import { GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { FastifyReply } from 'fastify';
import { AppConfig } from '../config/app-config';
import { CurrentTenant } from '../auth/current-tenant.decorator';
import { bucketFor, s3ClientFor } from '../storage/object-store';
import { ExportJobs } from './export-jobs';

// A merchant downloads one of their own exports a handful of times; the browser fetches it from S3.
@Controller('exports')
export class ExportsController {
  private readonly s3 = s3ClientFor(this.config);

  constructor(private readonly config: AppConfig, private readonly jobs: ExportJobs) {}

  @Get(':id/download')
  async download(@Param('id') id: string, @CurrentTenant() tenantId: string, @Res() reply: FastifyReply) {
    const job = await this.jobs.findReady(tenantId, id);
    if (!job) {
      throw new NotFoundException();
    }
    const command = new GetObjectCommand({ Bucket: bucketFor(this.config, 'exports'), Key: job.key });
    const url = await getSignedUrl(this.s3, command, { expiresIn: 300 });
    return reply.redirect(url, 302);
  }
}
