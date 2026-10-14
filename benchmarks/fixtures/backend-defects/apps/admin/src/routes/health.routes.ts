import { Router } from 'express';
import { pool } from '../lib/db.js';

export const healthRouter = Router();
const router = healthRouter;

/** Express 5 forwards a rejected promise from an async handler to the error middleware. */
router.get('/health/db', async (_req, res) => {
  await pool.query('select 1');
  res.json({ data: { db: 'up' } });
});
