import { proxyActivities, sleep } from '@temporalio/workflow';
import type * as acts from '../activities';

const { allocateStock } = proxyActivities<typeof acts>({
  startToCloseTimeout: '2 minutes',
  retry: { maximumAttempts: 5, initialInterval: '5 seconds', backoffCoefficient: 2 },
});

/**
 * Holds a backordered line until stock lands, re-checking hourly, for at most 14 days. In a TypeScript workflow
 * Date.now() is the workflow task's start time, replayed identically by the SDK sandbox.
 */
export async function backorderWaitWorkflow(orderId: string, sku: string): Promise<void> {
  const deadline = Date.now() + 14 * 24 * 3600_000;
  while (Date.now() < deadline) {
    if (await allocateStock(`${orderId}:${sku}`)) return;
    await sleep('1 hour');
  }
  throw new Error(`backorder ${orderId}/${sku} expired`);
}
