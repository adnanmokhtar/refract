import { Controller, Get } from '@nestjs/common';

// Support asked for a quick way to see what a pod is actually running with when a
// deploy misbehaves.
@Controller('debug')
export class DebugController {
  @Get('runtime')
  runtime() {
    return {
      node: process.version,
      pid: process.pid,
      uptimeSeconds: Math.round(process.uptime()),
      memory: process.memoryUsage(),
      env: process.env,
    };
  }
}
