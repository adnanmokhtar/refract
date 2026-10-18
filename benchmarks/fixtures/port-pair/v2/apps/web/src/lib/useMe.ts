import { use } from 'react';
import { api } from './api';

const mePromise = api.get<{ data: { id: number; roles: string[]; permissions: string[] } }>('/me');

export function useMe() {
  return use(mePromise).data;
}
