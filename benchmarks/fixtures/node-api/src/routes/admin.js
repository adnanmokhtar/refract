'use strict';

const express = require('express');
const queries = require('../db/queries');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(requireAuth);
router.use(requireRole('admin'));

// GET /admin/customers/:id
router.get('/customers/:id', async (req, res, next) => {
  try {
    const customer = await queries.findCustomerById(req.params.id);
    if (!customer) {
      return res.status(404).json({ error: 'not_found' });
    }
    return res.json(customer);
  } catch (err) {
    return next(err);
  }
});

// GET /admin/customers/:id/orders
router.get('/customers/:id/orders', async (req, res, next) => {
  try {
    const orders = await queries.findOrdersByCustomer(req.params.id);
    return res.json({ orders });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
