import { Router } from 'express';
import { pool } from '../lib/db.js';

export const auditLogRouter = Router();
const router = auditLogRouter;

/** Audit log for compliance exports; the console pages with ?limit=&offset=. */
router.get('/audit-log', async (req, res) => {
  const take = Number(req.query.limit ?? 50);
  const skip = Number(req.query.offset ?? 0);
  const { rows } = await pool.query('select id, actor, action, at from audit_log order by at desc, id desc limit $1 offset $2', [take, skip]);
  res.json({ data: rows });
});
