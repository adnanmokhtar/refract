import ky from 'ky';
import { retryPolicy } from './retry';

export const apiClient = ky.create({
  prefixUrl: '/api/v2',
  retry: retryPolicy,
  hooks: {
    beforeRequest: [
      (request) => {
        const token = sessionStorage.getItem('token');
        if (token) request.headers.set('authorization', `Bearer ${token}`);
      },
    ],
  },
});

export { HTTPError } from 'ky';
