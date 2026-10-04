import { Controller, Get } from '@nestjs/common';

// Liveness and readiness for the kubelet. Neither touches Postgres or Redis: a database
// blip must not restart every pod at once, and readiness only says this process can serve.
@Controller('health')
export class HealthController {
  private ready = false;

  constructor() {
    setImmediate(() => (this.ready = true));
  }

  @Get('live')
  live() {
    return { status: 'ok' };
  }

  @Get('ready')
  readyCheck() {
    return { status: this.ready ? 'ok' : 'starting' };
  }
}
