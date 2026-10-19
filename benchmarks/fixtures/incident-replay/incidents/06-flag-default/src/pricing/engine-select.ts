import { OpenFeature } from '@openfeature/server-sdk';
import { legacyEngine } from './legacy-engine';
import { nextEngine } from './next-engine';

const client = OpenFeature.getClient('pricing');

export async function selectEngine(tenantId: string) {
  const ctx = { targetingKey: tenantId };
  const useNext = await client.getBooleanValue('new-pricing-engine', true, ctx);
  return useNext ? nextEngine : legacyEngine;
}
