<script setup lang="ts">
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
</script>

<template>
  <section>
    <h1>{{ t('login.title') }}</h1>
    <a class="btn" href="/api/admin/auth/sso">{{ t('login.sso') }}</a>
  </section>
</template>
