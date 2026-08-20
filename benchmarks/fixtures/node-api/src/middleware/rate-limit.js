'use strict';

const { config } = require('../config');

// Fixed-window counter keyed by API key. Reset once a minute.
const counters = new Map();

setInterval(() => {
  counters.clear();
}, 60_000).unref();

function rateLimit(req, res, next) {
  const key = req.headers['x-api-key'] || req.ip;
  const used = counters.get(key) || 0;

  if (used >= config.limits.perKeyPerMinute) {
    res.set('Retry-After', '60');
    return res.status(429).json({ error: 'rate_limited' });
  }

  counters.set(key, used + 1);
  return next();
}

module.exports = { rateLimit };
