'use strict';

const express = require('express');
const { config } = require('./config');
const { rateLimit } = require('./middleware/rate-limit');
const { requestLog } = require('./middleware/request-log');

const ordersRouter = require('./routes/orders');
const webhooksRouter = require('./routes/webhooks');
const adminRouter = require('./routes/admin');

const app = express();

app.use(express.json({ limit: '5mb' }));
app.use(requestLog);
app.use(rateLimit);

app.get('/healthz', (req, res) => res.json({ ok: true }));

app.use('/orders', ordersRouter);
app.use('/webhooks', webhooksRouter);
app.use('/admin', adminRouter);

app.use((err, req, res, next) => {
  process.stderr.write(`unhandled: ${err.stack}\n`);
  res.status(500).json({ error: 'internal_error' });
});

app.listen(config.port, () => {
  process.stdout.write(`orders-api listening on ${config.port}\n`);
});

module.exports = { app };
