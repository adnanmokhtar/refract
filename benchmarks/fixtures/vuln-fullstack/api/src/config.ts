import { join } from 'path';

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable ${name}`);
  return value;
}

export const config = {
  env: process.env.NODE_ENV ?? 'development',
  port: Number(process.env.PORT ?? 3000),
  publicUrl: process.env.PUBLIC_URL ?? 'http://localhost:5173',

  auth: {
    // RS256 key pair, mounted from the marketly-jwt secret. The private key signs access
    // tokens at login; the public key is what the guards verify against.
    privateKeyPath: process.env.JWT_PRIVATE_KEY_PATH ?? '/etc/marketly/jwt.key',
    publicKeyPath: process.env.JWT_PUBLIC_KEY_PATH ?? '/etc/marketly/jwt.pub',
    accessTtl: '15m',
    sessionCookie: 'mk_sid',
    sessionDays: 7,
  },

  storage: {
    uploads: join(process.cwd(), 'public', 'uploads'),
    attachments: join(process.cwd(), 'storage', 'attachments'),
    exports: join(process.cwd(), 'storage', 'exports'),
    themes: join(process.cwd(), 'storage', 'themes'),
  },

  webhooks: {
    paymentsSecret: required('PAYMENTS_WEBHOOK_SECRET'),
    shippingSecret: required('SHIPPING_WEBHOOK_SECRET'),
  },

  // Hosts the catalogue feed importer may pull product images from.
  imageHosts: ['cdn.marketly.example', 'images.marketly.example'],
};
