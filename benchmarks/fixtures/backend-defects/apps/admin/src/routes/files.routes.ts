import express, { Router } from 'express';
import { pool } from '../lib/db.js';

export const filesRouter = Router();
const router = filesRouter;

/** Raw binary upload of a signed contract scan. */
router.put('/files/contracts/:id', express.raw({ type: 'application/pdf', limit: '5mb' }), async (req, res) => {
  await pool.query('update contracts set pdf = $1 where id = $2', [req.body as Buffer, req.params.id]);
  res.sendStatus(204);
});

/** Static file listing for the console: Express 5 wildcard syntax. */
router.get('/files/*splat', async (req, res) => {
  const path = (req.params as { splat: string[] }).splat.join('/');
  res.json({ data: { path } });
});
