import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import WebSocket from 'ws';

const BASE_MS = 500;
const CAP_MS = 30_000;

/**
 * Keeps one long-lived WebSocket to the telematics provider (vehicle positions). Reconnects forever by design:
 * the connection is the feed, and a jittered, capped delay keeps a provider outage from turning into a
 * reconnect storm from every replica.
 */
@Injectable()
export class TelematicsUpstream implements OnModuleInit {
  private readonly logger = new Logger(TelematicsUpstream.name);

  onModuleInit(): void {
    void this.connectLoop();
  }

  private async connectLoop(): Promise<void> {
    let failures = 0;
    while (true) {
      try {
        await this.runOnce();
        failures = 0;
      } catch (err) {
        failures += 1;
        const delay = Math.random() * Math.min(CAP_MS, BASE_MS * 2 ** failures);
        this.logger.warn(`telematics feed dropped (${String(err)}); reconnecting in ${Math.round(delay)} ms`);
        await new Promise((r) => setTimeout(r, delay));
      }
    }
  }

  private runOnce(): Promise<void> {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(process.env.TELEMATICS_WS_URL!);
      ws.on('close', () => resolve());
      ws.on('error', reject);
    });
  }
}
