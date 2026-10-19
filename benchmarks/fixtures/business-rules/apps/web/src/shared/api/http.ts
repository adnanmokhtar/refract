import ky from 'ky';

export const http = ky.create({ prefixUrl: '/api', credentials: 'include' });
