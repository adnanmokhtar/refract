import { Injectable } from '@nestjs/common';
import { ClientProxy } from '@nestjs/microservices';
import { Inject } from '@nestjs/common';
import { lastValueFrom } from 'rxjs';

/** Publishes domain events to the shared bus (Redis transport). */
@Injectable()
export class EventBus {
  constructor(@Inject('BUS') private readonly client: ClientProxy) {}

  async publish(topic: string, payload: Record<string, unknown>): Promise<void> {
    await lastValueFrom(this.client.emit(topic, payload));
  }
}
