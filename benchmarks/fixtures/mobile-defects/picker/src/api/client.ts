import axios from 'axios';

import { API_URL, DEFAULT_HEADERS } from './config';
import { currentToken } from '../auth/session';

/** The staff API client every picker screen and the outbox go through. */
export const api = axios.create({
  baseURL: API_URL,
  headers: DEFAULT_HEADERS,
});

api.interceptors.request.use((config) => {
  const token = currentToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});
