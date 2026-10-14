import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Courier } from './courier.entity';

export interface PresencePing {
  courierId: string;
  lastSeenAt: Date;
}

/**
 * "Last seen" in the dispatcher console. Display only: dispatch decisions read the courier's shift state, never
 * this column, so a ping that lands out of order only shows an older time until the next ping.
 */
@Injectable()
export class CourierPresence {
  constructor(private readonly em: EntityManager) {}

  async record(ping: PresencePing): Promise<void> {
    const courier = await this.em.findOneOrFail(Courier, ping.courierId);
    if (ping.lastSeenAt > courier.lastSeenAt) courier.lastSeenAt = ping.lastSeenAt;
    await this.em.flush();
  }
}
