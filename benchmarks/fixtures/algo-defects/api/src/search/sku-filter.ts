import { BadRequestException, Controller, Get, Req } from '@nestjs/common';
import type { FastifyRequest } from 'fastify';

/** Public product search; `q` is a space-separated list of SKU words. */
@Controller('search')
export class SkuFilterController {
  @Get('skus')
  search(@Req() req: FastifyRequest<{ Querystring: { q?: string } }>): { terms: string[] } {
    const q = req.query.q ?? '';
    if (!/^(\w+\s?)*$/.test(req.query.q ?? '')) {
      throw new BadRequestException('invalid query');
    }
    return { terms: q.split(' ').filter(Boolean) };
  }
}
