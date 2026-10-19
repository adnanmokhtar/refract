import { Controller, Get, Header } from '@nestjs/common';
import { ApiExcludeEndpoint } from '@nestjs/swagger';

/** Prometheus scrape endpoint: served outside the /v1 prefix and kept out of the public spec. */
@Controller('metrics')
export class MetricsController {
  @Get()
  @ApiExcludeEndpoint()
  @Header('Content-Type', 'text/plain; version=0.0.4')
  scrape(): string {
    return '# HELP tallyhook_up 1 when the API is serving\n# TYPE tallyhook_up gauge\ntallyhook_up 1\n';
  }
}
