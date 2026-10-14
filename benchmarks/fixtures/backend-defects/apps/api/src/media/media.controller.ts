import { BadRequestException, Controller, HttpCode, Post, Req } from '@nestjs/common';
import { FastifyRequest } from 'fastify';
import { createHash } from 'node:crypto';

@Controller('media')
export class MediaController {
  /** Product videos (up to 25 MB per the multipart limit). */
  @Post('videos')
  @HttpCode(201)
  async uploadVideo(@Req() request: FastifyRequest): Promise<{ sha256: string; bytes: number }> {
    const file = await request.file();
    if (!file) throw new BadRequestException('file is required');
    const buffer = await file.toBuffer();
    return { sha256: createHash('sha256').update(buffer).digest('hex'), bytes: buffer.length };
  }
}
