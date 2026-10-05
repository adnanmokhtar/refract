<script setup lang="ts">
import { RouterLink, RouterView } from 'vue-router';
import { useI18n } from 'vue-i18n';
import LocaleSwitcher from './components/LocaleSwitcher.vue';
import KeyboardShortcuts from './components/KeyboardShortcuts.vue';
import HelpPanel from './components/HelpPanel.vue';
import { useSession } from './stores/session';

const { t } = useI18n();
const session = useSession();
</script>

<template>
  <div class="shell">
    <nav class="sidebar" :aria-label="t('nav.label')">
      <RouterLink to="/dispatch" class="nav-link">{{ t('nav.dispatch') }}</RouterLink>
      <RouterLink to="/orders" class="nav-link">{{ t('nav.orders') }}</RouterLink>
      <RouterLink to="/pickers" class="nav-link">{{ t('nav.pickers') }}</RouterLink>
      <RouterLink to="/customers" class="nav-link">{{ t('nav.customers') }}</RouterLink>
      <RouterLink to="/reports" class="nav-link">{{ t('nav.reports') }}</RouterLink>
      <RouterLink to="/settings" class="nav-link">{{ t('nav.settings') }}</RouterLink>
      <LocaleSwitcher />
      <button type="button" class="btn" @click="session.signOut()">{{ t('nav.signOut') }}</button>
    </nav>
    <main class="content">
      <HelpPanel />
      <RouterView />
    </main>
    <KeyboardShortcuts />
  </div>
</template>
