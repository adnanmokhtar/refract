import axios from 'axios';

export const api = axios.create({
  baseURL: '/api/admin',
  timeout: 15_000,
  withCredentials: true,
});

export type AdminOrder = { id: string; number: string; customer: string; total: number; status: string };
export type Customer = { id: string; name: string; email: string; orders: number };
export type Invoice = { id: string; number: string; amount: number; dueAt: string };
export type AuditEntry = { id: string; actor: string; action: string; at: string };
