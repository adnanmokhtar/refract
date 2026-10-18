import { defineStore } from 'pinia';

export const useCustomersStore = defineStore('customers', {
  state: () => ({ selectedId: null as string | null }),
  actions: {
    select(id: string) {
      this.selectedId = id;
    },
  },
});
