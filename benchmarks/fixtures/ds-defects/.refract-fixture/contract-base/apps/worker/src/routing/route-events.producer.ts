import { Injectable } from '@nestjs/common';
import { sharedProducer } from '../kafka/kafka.provider';

/** routes.completed feeds the courier pay calculation (ledger-jvm) and the ops dashboards. */
@Injectable()
export class RouteEventsProducer {
  readonly topic = 'routes.completed';

  async routeCompleted(routeId: string, courierId: string, startedAt: number, stops: number): Promise<void> {
    const producer = await sharedProducer();
    await producer.send({
      topic: this.topic,
      messages: [{
        key: routeId,
        value: JSON.stringify({
          routeId,
          courierId,
          stops,
          durationS: Math.round((Date.now() - startedAt) / 1000),
        }),
      }],
    });
  }
}
