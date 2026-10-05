import { defineStore } from 'pinia';
import type { DispatchOrder } from '../lib/api';

export const useDispatchStore = defineStore('dispatch', {
  state: () => ({ orders: [] as DispatchOrder[], selected: null as string | null }),
  actions: {
    setOrders(orders: DispatchOrder[]) {
      this.orders = orders;
    },
    select(id: string | null) {
      this.selected = id;
    },
  },
});
