import { Controller, Get } from '@nestjs/common';
import { Public } from '../auth/public.decorator';

/** Probes for the load balancer and the Prometheus scrape; outside the /api prefix. */
@Controller()
export class HealthController {
  @Public()
  @Get('healthz')
  health() {
    return { status: 'ok' };
  }

  @Public()
  @Get('metrics')
  metrics() {
    return 'shelfwise_up 1\n';
  }
}
