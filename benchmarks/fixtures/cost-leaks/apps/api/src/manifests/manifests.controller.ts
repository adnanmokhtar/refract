import { Controller, Get, Param, StreamableFile, UseGuards } from '@nestjs/common';
import { GetObjectCommand } from '@aws-sdk/client-s3';
import type { Readable } from 'node:stream';
import { AppConfig } from '../config/app-config';
import { CarrierApiKeyGuard } from '../auth/carrier-api-key.guard';
import { s3ClientFor } from '../storage/object-store';

/**
 * Daily manifests for carrier depots: one ZIP per carrier per day (40–400 MB), built by the worker
 * (services/worker/worker/report_export.py). Each depot's sorting system downloads it several times a day.
 */
@Controller('carriers')
@UseGuards(CarrierApiKeyGuard)
export class ManifestsController {
  private readonly s3 = s3ClientFor(this.config);

  constructor(private readonly config: AppConfig) {}

  @Get(':carrierId/manifests/:date')
  async manifest(@Param('carrierId') carrierId: string, @Param('date') date: string): Promise<StreamableFile> {
    const key = `reports/manifests/${carrierId}/${date}.zip`;
    const object = await this.s3.send(new GetObjectCommand({ Bucket: this.config.reportsBucket, Key: key }));
    return new StreamableFile(object.Body as Readable, {
      type: 'application/zip',
      disposition: `attachment; filename="${carrierId}-${date}.zip"`,
    });
  }
}
