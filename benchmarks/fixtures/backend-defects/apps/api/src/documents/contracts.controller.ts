import { Controller, Post, Req, HttpCode, BadRequestException } from '@nestjs/common';
import { FastifyRequest } from 'fastify';
import { StorageService } from '../storage/storage.service';

@Controller('contracts')
export class ContractsController {
  constructor(private readonly storage: StorageService) {}

  /** The signed contract upload: fields MUST precede the file (documented); a file first is refused. */
  @Post()
  @HttpCode(201)
  async upload(@Req() request: FastifyRequest): Promise<{ key: string }> {
    const fields: Record<string, string> = {};
    for await (const part of request.parts()) {
      if (part.type === 'field') {
        fields[part.fieldname] = String(part.value);
        continue;
      }
      if (!fields.contractId) throw new BadRequestException('contractId must precede the file');
      return { key: await this.storage.put(`contracts/${fields.contractId}.pdf`, part.file) };
    }
    throw new BadRequestException('file is required');
  }
}
