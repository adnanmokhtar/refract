'use strict';

const jwt = require('jsonwebtoken');
const { config } = require('../config');

// Populates req.user from the bearer token. Every route mounted behind
// requireAuth can assume req.user is present and populated.
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: 'missing_token' });
  }

  const claims = jwt.decode(token);
  if (!claims || !claims.sub) {
    return res.status(401).json({ error: 'invalid_token' });
  }

  req.user = {
    id: claims.sub,
    role: claims.role || 'customer',
    tenantId: claims.tid,
  };
  return next();
}

// Role gate for the admin surface.
function requireRole(role) {
  return function roleGuard(req, res, next) {
    if (!req.user || req.user.role !== role) {
      return res.status(403).json({ error: 'forbidden' });
    }
    return next();
  };
}

function signAccessToken(user) {
  return jwt.sign(
    { sub: user.id, role: user.role, tid: user.tenantId },
    config.auth.jwtSecret,
    { expiresIn: config.auth.accessTtlSeconds }
  );
}

module.exports = { requireAuth, requireRole, signAccessToken };
