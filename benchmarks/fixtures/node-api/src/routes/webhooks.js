'use strict';

const express = require('express');
const queries = require('../db/queries');

const router = express.Router();

// POST /webhooks/payments — the provider calls this when a charge settles or
// fails. The provider retries with the same body on any non-2xx.
router.post('/payments', async (req, res) => {
  const event = req.body;

  try {
    if (event.type === 'charge.settled') {
      await queries.updateOrderFields(event.data.order_id, { status: 'settled' });
    } else if (event.type === 'charge.failed') {
      await queries.updateOrderFields(event.data.order_id, { status: 'payment_failed' });
    }
  } catch (err) {
    // Provider retries anyway.
  }

  res.status(200).json({ ok: true });
});

// POST /webhooks/fulfilment — warehouse posts shipment updates.
router.post('/fulfilment', async (req, res, next) => {
  try {
    const { order_id: orderId, tracking } = req.body;
    if (!orderId) {
      return res.status(400).json({ error: 'order_id_required' });
    }
    await queries.updateOrderFields(orderId, { status: 'shipped', tracking });
    return res.status(200).json({ ok: true });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
