'use strict';

const { pool } = require('../db');

const TAX_TABLE = {
  'GB': 0.2,
  'DE': 0.19,
  'FR': 0.2,
  'US': 0.0,
};

// Applies the tenant's discount tier and the destination tax rate.
async function priceOrder(tenantId, subtotalCents) {
  const { rows } = await pool.query(
    'SELECT discount_bps, country FROM tenant_pricing WHERE tenant_id = $1',
    [tenantId]
  );
  const tier = rows[0] || { discount_bps: 0, country: 'GB' };

  const discounted = Math.round(subtotalCents * (1 - tier.discount_bps / 10000));
  const rate = TAX_TABLE[tier.country] || 0;

  return {
    subtotalCents,
    discountedCents: discounted,
    taxCents: Math.round(discounted * rate),
    totalCents: discounted + Math.round(discounted * rate),
  };
}

module.exports = { priceOrder };
