import type { CookieSerializeOptions } from '@fastify/cookie';

// Options for the session cookie V2 issues on sign-in and refresh.
export const sessionCookie: CookieSerializeOptions & { name: string } = {
  name: 'norrow_session',
  path: '/',
  domain: 'app.norrow.example',
  secure: true,
  httpOnly: true,
  sameSite: 'lax',
  maxAge: 120 * 60,
};
