import { Controller, Post, Req, HttpCode, BadRequestException } from '@nestjs/common';
import { FastifyRequest } from 'fastify';
import { StorageService } from '../storage/storage.service';

@Controller('documents')
export class DocumentsController {
  constructor(private readonly storage: StorageService) {}

  /** multipart/form-data: file + "kind" (invoice | contract) + "orderId". */
  @Post()
  @HttpCode(201)
  async upload(@Req() request: FastifyRequest): Promise<{ key: string }> {
    let key = '';
    let kind: string | undefined;
    for await (const part of request.parts()) {
      if (part.type === 'file') {
        key = await this.storage.put(`documents/${kind ?? 'misc'}/${part.filename}`, part.file);
      } else if (part.fieldname === 'kind') {
        kind = String(part.value);
      }
    }
    if (!key) throw new BadRequestException('file is required');
    return { key };
  }
}
