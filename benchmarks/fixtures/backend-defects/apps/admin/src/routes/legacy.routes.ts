import { Router } from 'express';
import { pool } from '../lib/db.js';

export const legacyRouter = Router();
const router = legacyRouter;

/** The 2023 console export; replaced by /admin/exports, kept for one more quarter. */
router.get('/legacy/export', async (_req, res) => {
  res.setHeader('Deprecation', 'true');
  res.setHeader('Link', '</admin/exports>; rel="successor-version"');
  const { rows } = await pool.query('select id, number, status from invoices order by id limit 1000');
  res.json({ data: rows });
});
