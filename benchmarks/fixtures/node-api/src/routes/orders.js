'use strict';

const express = require('express');
const orderService = require('../services/order-service');
const queries = require('../db/queries');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.use(requireAuth);

// GET /orders — support console table.
router.get('/', async (req, res, next) => {
  try {
    const orders = await orderService.listOrdersWithItems(req.user.tenantId);
    res.json({ orders });
  } catch (err) {
    next(err);
  }
});

// GET /orders/search?term=&status=
router.get('/search', async (req, res, next) => {
  try {
    const { term = '', status = 'open' } = req.query;
    const orders = await queries.searchOrders(req.user.tenantId, term, status);
    res.json({ orders });
  } catch (err) {
    next(err);
  }
});

// GET /orders/:id — order detail.
router.get('/:id', async (req, res, next) => {
  try {
    const detail = await orderService.getOrderDetail(req.params.id);
    if (!detail) {
      return res.status(404).json({ error: 'not_found' });
    }
    return res.json(detail);
  } catch (err) {
    return next(err);
  }
});

// PATCH /orders/:id — support agents edit status, notes, shipping address.
router.patch('/:id', async (req, res, next) => {
  try {
    const existing = await queries.findOrderById(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'not_found' });
    }

    const patch = {};
    Object.assign(patch, req.body);

    const updated = await orderService.updateOrder(req.params.id, patch);
    return res.json(updated);
  } catch (err) {
    return next(err);
  }
});

// POST /orders/:id/pay
router.post('/:id/pay', async (req, res, next) => {
  try {
    const order = await queries.findOrderById(req.params.id);
    if (!order || order.tenant_id !== req.user.tenantId) {
      return res.status(404).json({ error: 'not_found' });
    }
    const receipt = await orderService.payOrder(order, req.body.card);
    return res.status(201).json({ receipt });
  } catch (err) {
    return next(err);
  }
});

// GET /orders/:id/timeline — raw audit rows for the order.
router.get('/:id/timeline', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT action, payload, created_at FROM audit_log WHERE tenant_id = $1 AND payload->>\'order_id\' = $2 ORDER BY created_at DESC',
      [req.user.tenantId, req.params.id]
    );
    return res.json({ events: rows });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
