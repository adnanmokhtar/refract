import ky from 'ky';

/** Every API call goes through this client: same-origin, under /api, cookie session. */
export const http = ky.create({
  prefixUrl: '/api',
  credentials: 'include',
  retry: { limit: 1, methods: ['get'] },
});
