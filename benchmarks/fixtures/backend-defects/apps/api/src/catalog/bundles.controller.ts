import { Body, Controller, Post, Res } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { CreateBundleDto } from './dto/bundle.dto';

@Controller('bundles')
export class BundlesController {
  @Post()
  async create(@Body() dto: CreateBundleDto, @Res({ passthrough: true }) reply: FastifyReply): Promise<{ id: string; items: number }> {
    const id = crypto.randomUUID();
    reply.status(201).header('Location', `/v1/bundles/${id}`);
    return { id, items: dto.items.length };
  }
}
