import { condition, defineSignal, proxyActivities, setHandler } from '@temporalio/workflow';
import type * as acts from '../activities';

const { allocateStock, createPickList, notifyWarehouse, requestCarrierPickup, markOrderShipped } = proxyActivities<typeof acts>({
  startToCloseTimeout: '2 minutes',
  retry: { maximumAttempts: 5, initialInterval: '5 seconds', backoffCoefficient: 2 },
});

export const packedSignal = defineSignal<[{ parcels: number }]>('packed');

/**
 * One execution per order, open from placement until the parcel leaves the dock (typically 4–30 hours, up to
 * 5 days for backorders). Recorded histories of the previous release: histories/fulfilment-2.13.json.
 */
export async function fulfilmentWorkflow(orderId: string): Promise<void> {
  let parcels = 0;
  setHandler(packedSignal, (p) => {
    parcels = p.parcels;
  });

  await allocateStock(orderId);
  const pickList = await createPickList(orderId);
  await notifyWarehouse(orderId, pickList);

  const packed = await condition(() => parcels > 0, '5 days');
  if (!packed) throw new Error(`order ${orderId} not packed within 5 days`);

  await requestCarrierPickup(orderId, parcels);
  await markOrderShipped(orderId);
}

