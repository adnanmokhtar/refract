import { defineStore } from 'pinia';
import { useOrdersStore } from './orders-store';

export const useFiltersStore = defineStore('filters', {
  state: () => ({ status: 'all' }),
  actions: {
    apply() {
      void useOrdersStore().load();
    },
  },
});
