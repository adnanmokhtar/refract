<script setup lang="ts">
import { ref } from 'vue';
import { RouterLink } from 'vue-router';
import { useI18n } from 'vue-i18n';
import NotificationsPanel from './NotificationsPanel.vue';

const { t } = useI18n();
const collapsed = ref(false);
const links = ['orders', 'customers', 'invoices', 'reports', 'dashboard', 'audit-log', 'menu-builder', 'settings'] as const;
const labels: Record<(typeof links)[number], string> = {
  orders: 'nav.orders',
  customers: 'nav.customers',
  invoices: 'nav.invoices',
  reports: 'nav.reports',
  dashboard: 'nav.dashboard',
  'audit-log': 'nav.auditLog',
  'menu-builder': 'nav.menu',
  settings: 'nav.settings',
};
</script>

<template>
  <nav class="sidebar" :class="{ collapsed }" :aria-label="t('nav.orders')">
    <button class="collapse-toggle" type="button" aria-hidden="true" @click="collapsed = !collapsed">
      <svg viewBox="0 0 16 16" width="16" height="16"><path d="M10 3 5 8l5 5" fill="none" stroke="currentColor" /></svg>
    </button>
    <ul class="sidebar-links">
      <li v-for="link in links" :key="link">
        <RouterLink :to="`/${link}`" class="nav-link">{{ t(labels[link]) }}</RouterLink>
      </li>
    </ul>
    <NotificationsPanel />
  </nav>
</template>

<style scoped>
.sidebar {
  padding: var(--space-4);
  border-inline-end: 1px solid var(--border);
}

.sidebar-links {
  list-style: none;
  padding: 0;
}

.collapse-toggle {
  border: 0;
  background: transparent;
  cursor: pointer;
}
</style>
