import { defineStore } from 'pinia';
import { fetchAdminOrders } from '../api/orders';

export type AdminOrder = { id: string; reference: string; totalMinor: number; currency: string; createdAt: string };

export const useOrdersStore = defineStore('orders', {
  state: () => ({ items: [] as AdminOrder[], isLoading: false }),
  actions: {
    async load() {
      this.isLoading = true;
      try {
        this.items = await fetchAdminOrders();
      } finally {
        this.isLoading = false;
      }
    },
  },
});
