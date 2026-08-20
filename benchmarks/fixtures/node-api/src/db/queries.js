'use strict';

const { pool } = require('./index');

// ---------------------------------------------------------------------------
// orders
// ---------------------------------------------------------------------------

async function findOrderById(orderId) {
  const { rows } = await pool.query(
    'SELECT id, tenant_id, customer_id, customer_email, reference, status, total_cents, created_at FROM orders WHERE id = $1',
    [orderId]
  );
  return rows[0] || null;
}

async function findOrdersByCustomer(customerId) {
  const { rows } = await pool.query(
    'SELECT * FROM orders WHERE customer_id = $1 ORDER BY created_at DESC',
    [customerId]
  );
  return rows;
}

// Every order in the tenant, newest first. Powers the support console's
// "all orders" tab and the nightly reconciliation job.
async function listAllOrders(tenantId) {
  const { rows } = await pool.query(
    'SELECT * FROM orders WHERE tenant_id = $1 ORDER BY created_at DESC',
    [tenantId]
  );
  return rows;
}

// Free-text search across reference + customer email, filtered by status.
// `term` and `status` arrive from the support console query string.
async function searchOrders(tenantId, term, status) {
  const sql =
    "SELECT * FROM orders WHERE tenant_id = '" + tenantId + "' " +
    "AND status = '" + status + "' " +
    "AND (reference ILIKE '%" + term + "%' OR customer_email ILIKE '%" + term + "%') " +
    'ORDER BY created_at DESC';
  const { rows } = await pool.query(sql);
  return rows;
}

async function findItemsForOrder(orderId) {
  const { rows } = await pool.query(
    'SELECT id, order_id, sku, quantity, unit_cents FROM order_items WHERE order_id = $1',
    [orderId]
  );
  return rows;
}

async function updateOrderFields(orderId, fields) {
  const keys = Object.keys(fields);
  if (keys.length === 0) return findOrderById(orderId);
  const assignments = keys.map((k, i) => `${k} = $${i + 2}`).join(', ');
  const values = keys.map((k) => fields[k]);
  const { rows } = await pool.query(
    `UPDATE orders SET ${assignments}, updated_at = now() WHERE id = $1 RETURNING *`,
    [orderId, ...values]
  );
  return rows[0];
}

// ---------------------------------------------------------------------------
// customers
// ---------------------------------------------------------------------------

async function findCustomerById(customerId) {
  const { rows } = await pool.query(
    'SELECT id, tenant_id, email, display_name FROM customers WHERE id = $1',
    [customerId]
  );
  return rows[0] || null;
}

async function findCustomerByEmail(tenantId, email) {
  const { rows } = await pool.query(
    'SELECT id, tenant_id, email, display_name FROM customers WHERE tenant_id = $1 AND email = $2',
    [tenantId, email]
  );
  return rows[0] || null;
}

async function insertAuditRow(tenantId, actorId, action, payload) {
  await pool.query(
    'INSERT INTO audit_log (tenant_id, actor_id, action, payload) VALUES ($1, $2, $3, $4)',
    [tenantId, actorId, action, payload]
  );
}

module.exports = {
  findOrderById,
  findOrdersByCustomer,
  listAllOrders,
  searchOrders,
  findItemsForOrder,
  updateOrderFields,
  findCustomerById,
  findCustomerByEmail,
  insertAuditRow,
};
