import { Controller, Get, NotFoundException, Param, Res } from '@nestjs/common';
import { GetObjectCommand } from '@aws-sdk/client-s3';
import type { FastifyReply } from 'fastify';
import { AppConfig } from '../config/app-config';
import { CurrentTenant } from '../auth/current-tenant.decorator';
import { bucketFor, s3ClientFor } from '../storage/object-store';
import { ShipmentsRepository } from '../shipments/shipments.repository';
import { PodPhotosService } from './pod-photos.service';

// Full-resolution proof-of-delivery photos (3–6 MB each) for the merchant dashboard and the claims export.
@Controller('shipments')
export class PodPhotosController {
  private readonly s3 = s3ClientFor(this.config);

  constructor(
    private readonly config: AppConfig,
    private readonly shipments: ShipmentsRepository,
    private readonly photos: PodPhotosService,
  ) {}

  @Get(':id/photos/:photoId')
  async photo(@Param('id') id: string, @Param('photoId') photoId: string, @CurrentTenant() tenantId: string, @Res() reply: FastifyReply) {
    if (!(await this.shipments.belongsTo(id, tenantId))) {
      throw new NotFoundException();
    }
    const object = await this.s3.send(new GetObjectCommand({ Bucket: bucketFor(this.config, 'podPhotos'), Key: this.photos.keyFor(id, photoId) }));
    reply.header('content-type', object.ContentType ?? 'image/jpeg');
    return reply.send(object.Body);
  }
}
