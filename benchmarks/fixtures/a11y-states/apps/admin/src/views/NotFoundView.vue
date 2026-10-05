<script setup lang="ts">
import { RouterLink } from 'vue-router';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
</script>

<template>
  <section>
    <h1>404</h1>
    <RouterLink to="/orders" class="nav-link">{{ t('nav.orders') }}</RouterLink>
  </section>
</template>
