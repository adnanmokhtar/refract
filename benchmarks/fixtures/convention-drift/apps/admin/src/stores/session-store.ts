import { defineStore } from 'pinia';

export const useSessionStore = defineStore('session', {
  state: () => ({ token: '', isAuthenticated: false }),
  actions: {
    signIn(token: string) {
      this.token = token;
      this.isAuthenticated = true;
    },
  },
});
