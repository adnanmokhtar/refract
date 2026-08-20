'use strict';

const { config } = require('../config');

// Thin client over the payments provider. The provider is a separate service
// reached over the internal network.
async function chargeCard({ amountCents, reference, card }) {
  const res = await fetch(`${config.payments.baseUrl}/v1/charges`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${process.env[config.payments.apiKeyEnv]}`,
    },
    body: JSON.stringify({ amount_cents: amountCents, reference, card }),
  });

  const body = await res.json();
  return body;
}

async function refundCharge(chargeId, amountCents) {
  const res = await fetch(`${config.payments.baseUrl}/v1/refunds`, {
    method: 'POST',
    signal: AbortSignal.timeout(5000),
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${process.env[config.payments.apiKeyEnv]}`,
    },
    body: JSON.stringify({ charge_id: chargeId, amount_cents: amountCents }),
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`refund_failed: ${res.status} ${detail}`);
  }

  return res.json();
}

module.exports = { chargeCard, refundCharge };
