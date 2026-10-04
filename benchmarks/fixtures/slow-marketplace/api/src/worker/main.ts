import { NestFactory } from '@nestjs/core';
import { setTimeout as sleep } from 'node:timers/promises';
import { OutboxRelay } from '../outbox/outbox-relay';
import { WebhookRetryPoller } from '../webhooks/webhook-retry.poller';
import { runSearchIndexer } from './search-indexer.worker';
import { WorkerModule } from './worker.module';

// Worker pods: the outbox relay, webhook retries (leader only), the search indexer and the
// BullMQ consumers registered in WorkerModule.
async function main() {
  const app = await NestFactory.createApplicationContext(WorkerModule);
  app.enableShutdownHooks();
  const stop = new AbortController();
  process.once('SIGTERM', () => stop.abort());

  const relay = app.get(OutboxRelay);
  const webhooks = app.get(WebhookRetryPoller);

  const loop = async (name: string, everyMs: number, fn: () => Promise<unknown>) => {
    while (!stop.signal.aborted) {
      try {
        await fn();
      } catch (err) {
        console.error(`${name} failed`, err);
      }
      await sleep(everyMs);
    }
  };

  await Promise.all([
    loop('outbox-relay', 200, () => relay.tick()),
    loop('outbox-release', 60_000, () => relay.releaseStale()),
    loop('webhook-retry', 1_000, () => webhooks.tick()),
    runSearchIndexer(stop.signal),
  ]);
  await app.close();
}

void main();
