import axios from 'axios';
import { mockApi } from './mock-api';

const http = axios.create({ baseURL: '/api/admin', timeout: 15_000, withCredentials: true });

// Demo environments run with VITE_USE_MOCKS=true and never touch the real API.
export const api = import.meta.env.VITE_USE_MOCKS === 'true' ? mockApi : http;

export type DispatchOrder = { id: string; number: string; customer: string; status: 'placed' | 'picking' | 'ready' | 'out'; eta: string; pickerId: string | null };
export type Picker = { id: string; name: string; active: boolean };
