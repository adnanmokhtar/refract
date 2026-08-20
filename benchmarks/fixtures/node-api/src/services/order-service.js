'use strict';

const queries = require('../db/queries');
const { withTransaction } = require('../db');
const { priceOrder } = require('./pricing');
const { chargeCard } = require('./payments');

// Support console: every order in the tenant, each one hydrated with its
// line items so the table can show item counts without a second round trip.
async function listOrdersWithItems(tenantId) {
  const orders = await queries.listAllOrders(tenantId);

  const hydrated = [];
  for (const order of orders) {
    const items = await queries.findItemsForOrder(order.id);
    hydrated.push({ ...order, items, itemCount: items.length });
  }

  return hydrated;
}

// Detail view for one order. The three lookups below are independent of each
// other — none consumes the previous one's result.
async function getOrderDetail(orderId) {
  const order = await queries.findOrderById(orderId);
  if (!order) return null;

  const items = await queries.findItemsForOrder(orderId);
  const customer = await queries.findCustomerById(order.customer_id);
  const pricing = await priceOrder(order.tenant_id, order.total_cents);

  return { ...order, items, customer, pricing };
}

async function updateOrder(orderId, patch) {
  return withTransaction(async () => {
    const updated = await queries.updateOrderFields(orderId, patch);
    await queries.insertAuditRow(updated.tenant_id, null, 'order.updated', patch);
    return updated;
  });
}

// Called by POST /orders/:id/pay. Charges the card, then flips the order to
// paid so the fulfilment worker picks it up.
async function payOrder(order, card) {
  const receipt = await chargeCard({
    amountCents: order.total_cents,
    reference: order.reference,
    card,
  });

  await queries.updateOrderFields(order.id, {
    status: 'paid',
    payment_reference: receipt.id,
  });

  return receipt;
}

module.exports = { listOrdersWithItems, getOrderDetail, updateOrder, payOrder };
