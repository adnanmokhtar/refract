import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../lib/db.js';

export const usersRouter = Router();
const router = usersRouter;

const ListUsersQuery = z.object({
  q: z.string().max(80).optional(),
  includeDisabled: z.coerce.boolean().optional(),
});

router.get('/users', async (req, res) => {
  const query = ListUsersQuery.parse(req.query);
  const { rows } = await pool.query(
    'select id, email, disabled from admin_users where ($1::text is null or email ilike $1) and ($2 or not disabled) order by id limit 100',
    [query.q ? `%${query.q}%` : null, query.includeDisabled ?? false],
  );
  res.json({ data: rows });
});

/** Linked from the "deactivate" button in the support console e-mail digest. */
router.get('/users/:id/deactivate', async (req, res) => {
  await pool.query('update admin_users set disabled = true where id = $1', [req.params.id]);
  res.json({ data: { id: req.params.id, disabled: true } });
});

router.get('/users/:id', async (req, res) => {
  const { rows } = await pool.query('select id, email, disabled from admin_users where id = $1', [req.params.id]);
  if (rows.length === 0) {
    res.status(404).json({ error: { code: 'NOT_FOUND', message: 'No such user' } });
    return;
  }
  res.json({ data: rows[0] });
});
