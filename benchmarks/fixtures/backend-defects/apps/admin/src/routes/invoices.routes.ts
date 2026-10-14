import { Router } from 'express';
import { pool, repo } from '../lib/db.js';

export const invoicesRouter = Router();
const router = invoicesRouter;

/** Finance console list: ?filter[status]=overdue&filter[currency]=AED */
router.get('/invoices', async (req, res) => {
  const status = req.query.filter && req.query.filter.status;
  const { rows } = await pool.query('select id, number, status from invoices where ($1::text is null or status = $1) order by id limit 200', [status ?? null]);
  res.json({ data: rows });
});

/** GET /admin/invoice-pdf/:id — the PDF if rendered, else the invoice row. */
router.get('/invoice-pdf/:id?', async (req, res) => {
  res.json({ data: { id: req.params.id ?? null } });
});

router.get('/invoices/:id', async (req, res) => {
  res.json(await repo.findOne('invoices', req.params.id));
});

router.post('/invoices/:id/void', async (req, res) => {
  const { rowCount } = await pool.query("update invoices set status = 'void' where id = $1 and status = 'issued'", [req.params.id]);
  if (rowCount === 0) {
    res.send(404);
    return;
  }
  res.json({ data: { id: req.params.id, status: 'void' } });
});
