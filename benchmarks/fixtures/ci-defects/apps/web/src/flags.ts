import { OpenFeature } from '@openfeature/web-sdk';

const client = OpenFeature.getClient('storefront');

// The redesigned checkout. Rolled out from flags/flags.yaml through the flag service.
export async function newCheckoutEnabled(): Promise<boolean> {
  return client.getBooleanValue('new-checkout', true);
}
