import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../lib/db.js';

export const couponsRouter = Router();
const router = couponsRouter;

const CreateCoupon = z.strictObject({
  code: z.string().regex(/^[A-Z0-9]{4,16}$/),
  percentOff: z.number().int().min(1).max(90),
});

router.post('/coupons', async (req, res) => {
  const input = CreateCoupon.parse(req.body);
  const { rows } = await pool.query('insert into coupons (code, percent_off) values ($1, $2) returning id, code, percent_off', [input.code, input.percentOff]);
  res.status(201).json({ data: rows[0] });
});
