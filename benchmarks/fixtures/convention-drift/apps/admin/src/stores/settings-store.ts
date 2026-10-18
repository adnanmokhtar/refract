import { defineStore } from 'pinia';

export const useSettingsStore = defineStore('settings', {
  state: () => ({ locale: 'en' as 'en' | 'ar', hasCompactRows: false }),
});
