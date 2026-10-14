import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import Redis from 'ioredis';
import { TrackingProjector } from './tracking-projector';

const STREAM = 'tracking-events';
const GROUP = 'tracking-projector';

/**
 * Reads the tracking-events Redis stream (XADD by the carrier gateway, ~3 k entries/s at peak) and projects
 * each entry. Entries left pending by a crashed reader are reclaimed after 60 s.
 */
@Injectable()
export class TrackingStreamReader implements OnModuleInit {
  private readonly logger = new Logger(TrackingStreamReader.name);
  private readonly redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
  private readonly consumerName = `reader-${process.env.HOSTNAME ?? 'local'}`;

  constructor(private readonly projector: TrackingProjector) {}

  onModuleInit(): void {
    void this.loop();
  }

  private async loop(): Promise<void> {
    for (;;) {
      await this.redis.xautoclaim(STREAM, GROUP, this.consumerName, 60_000, '0-0', 'COUNT', 100);
      const res = (await this.redis.xreadgroup('GROUP', GROUP, this.consumerName, 'BLOCK', 5_000, 'STREAMS', STREAM, '>')) as Array<[string, Array<[string, string[]]>]> | null;
      if (!res) continue;
      for (const [, entries] of res) {
        for (const [id, fields] of entries) {
          await this.projector.apply(fields);
          await this.redis.xack(STREAM, GROUP, id);
        }
      }
    }
  }
}
