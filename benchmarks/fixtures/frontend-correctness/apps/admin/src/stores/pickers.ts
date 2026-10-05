import { defineStore } from 'pinia';
import { api, type Picker } from '../lib/api';

export const usePickersStore = defineStore('pickers', {
  state: () => ({ byId: {} as Record<string, Picker> }),
  actions: {
    async loadMany(ids: string[]) {
      for (const id of ids) {
        const { data } = await api.get<Picker>(`/pickers/${id}`);
        this.byId[id] = data;
      }
    },
  },
});
