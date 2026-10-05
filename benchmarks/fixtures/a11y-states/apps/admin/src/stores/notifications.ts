import { defineStore } from 'pinia';
import { api } from '../lib/api';

type Notification = { id: string; text: string; at: string; read: boolean };

export const useNotifications = defineStore('notifications', {
  state: () => ({ items: [] as Notification[], fetched: false }),
  getters: {
    unread: (state) => state.items.filter((n) => !n.read).length,
  },
  actions: {
    async load() {
      try {
        const { data } = await api.get<Notification[]>('/notifications');
        this.items = data;
      } catch {
        this.items = [];
      } finally {
        this.fetched = true;
      }
    },
  },
});
