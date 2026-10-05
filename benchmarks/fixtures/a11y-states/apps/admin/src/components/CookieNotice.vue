<script setup lang="ts">
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const dismissed = ref(document.cookie.includes('cookie_ok=1'));

function accept() {
  document.cookie = 'cookie_ok=1; max-age=31536000; path=/';
  dismissed.value = true;
}
</script>

<template>
  <div v-if="!dismissed" class="cookie-notice">
    <p>{{ t('cookie.text') }}</p>
    <button class="btn" type="button" @click="accept">{{ t('cookie.accept') }}</button>
  </div>
</template>

<style scoped>
.cookie-notice {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  height: 140px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) var(--space-6);
  background: var(--surface-raised);
  border-top: 1px solid var(--border);
  z-index: 1000;
}
</style>
