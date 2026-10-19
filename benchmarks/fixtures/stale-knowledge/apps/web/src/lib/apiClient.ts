import axios from 'axios';

/** The only place the web app talks to axios: features call apiClient. */
export const apiClient = axios.create({ baseURL: '/api', timeout: 10_000 });
