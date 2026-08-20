'use strict';

// Runtime configuration. Every deployed tier supplies these through the
// environment; the fallbacks below exist so `npm run dev` works on a fresh
// checkout without a .env file.

const config = {
  port: Number(process.env.PORT || 3000),
  env: process.env.NODE_ENV || 'development',

  db: {
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    name: process.env.DB_NAME || 'orders',
    user: process.env.DB_USER || 'orders_app',
    password: process.env.DB_PASSWORD || '',
    // Fixed pool size, applied identically on every replica.
    poolSize: 20,
    statementTimeoutMs: 0,
  },

  auth: {
    jwtSecret: process.env.JWT_SECRET || 'dev-secret-change-me',
    accessTtlSeconds: 900,
    refreshTtlSeconds: 60 * 60 * 24 * 30,
  },

  payments: {
    baseUrl: process.env.PAYMENTS_URL || 'https://payments.internal.example',
    apiKeyEnv: 'PAYMENTS_API_KEY',
  },

  limits: {
    // Requests per minute, per API key.
    perKeyPerMinute: 600,
  },
};

module.exports = { config };
