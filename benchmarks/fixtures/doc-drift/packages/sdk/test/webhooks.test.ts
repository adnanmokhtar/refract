import { createHmac } from 'node:crypto';

import { describe, expect, it } from 'vitest';

import { verifyWebhookSignature } from '../src/webhooks.js';

describe('verifyWebhookSignature', () => {
  it('accepts a signature made with the same secret', () => {
    const sig = createHmac('sha256', 's3cret').update('1700000000.{}').digest('hex');
    expect(verifyWebhookSignature('{}', `t=1700000000,v1=${sig}`, 's3cret')).toBe(true);
  });
});
