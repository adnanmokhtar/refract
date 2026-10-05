import { defineStore } from 'pinia';
import { api } from '../lib/api';
import { router } from '../router';

type Staff = { id: string; name: string; role: 'dispatcher' | 'lead' };

export const useSession = defineStore('session', {
  state: () => ({ user: null as Staff | null }),
  actions: {
    async load() {
      const { data } = await api.get<Staff | null>('/me');
      this.user = data;
    },
    async signOut() {
      await api.post('/auth/sign-out');
      this.user = null;
      await router.push('/login');
    },
  },
});
