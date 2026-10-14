import express, { NextFunction, Request, Response } from 'express';
import { usersRouter } from './routes/users.routes.js';
import { couponsRouter } from './routes/coupons.routes.js';
import { invoicesRouter } from './routes/invoices.routes.js';
import { auditLogRouter } from './routes/audit-log.routes.js';
import { legacyRouter } from './routes/legacy.routes.js';
import { pspProxyRouter } from './routes/psp-proxy.routes.js';
import { geoProxyRouter } from './routes/geo-proxy.routes.js';
import { uploadsRouter } from './routes/uploads.routes.js';
import { importsRouter } from './routes/imports.routes.js';
import { filesRouter } from './routes/files.routes.js';
import { healthRouter } from './routes/health.routes.js';

export const app = express();

app.disable('x-powered-by');
app.use(express.json({ type: '*/*', limit: '256kb' }));

app.use('/admin', usersRouter);
app.use('/admin', couponsRouter);
app.use('/admin', invoicesRouter);
app.use('/admin', auditLogRouter);
app.use('/admin', legacyRouter);
app.use('/admin', pspProxyRouter);
app.use('/admin', geoProxyRouter);
app.use('/admin', uploadsRouter);
app.use('/admin', importsRouter);
app.use('/admin', filesRouter);
app.use('/admin', healthRouter);

// Last: every error the routes raise or forward lands here.
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  if (res.headersSent) return next(err);
  console.error(`[admin] ${req.method} ${req.path} failed`, err);
  res.status(500).json({ error: { code: 'INTERNAL', message: 'Something went wrong' } });
});
