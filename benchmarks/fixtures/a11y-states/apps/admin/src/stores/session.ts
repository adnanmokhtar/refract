import { defineStore } from 'pinia';

type StaffUser = { id: string; name: string; role: 'owner' | 'support' | 'finance' };

export const useSession = defineStore('session', {
  state: () => ({ user: null as StaffUser | null }),
  actions: {
    setUser(user: StaffUser | null) {
      this.user = user;
    },
  },
});
