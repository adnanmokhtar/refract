<script setup lang="ts">
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { api } from '../lib/api';

const { t } = useI18n();
const storeName = ref('Lumen Home');
const supportEmail = ref('');
const saving = ref(false);
const saved = ref(false);

async function save() {
  saving.value = true;
  saved.value = false;
  try {
    await api.put('/settings', { storeName: storeName.value, supportEmail: supportEmail.value });
    saved.value = true;
    setTimeout(() => (saved.value = false), 4000);
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <section>
    <h1>{{ t('nav.settings') }}</h1>
    <form class="settings-form" @submit.prevent="save">
      <label for="store-name">Store name</label>
      <input id="store-name" v-model="storeName" />
      <label for="support-email">Support email</label>
      <input id="support-email" v-model="supportEmail" type="email" autocomplete="off" />
      <button class="btn" type="submit" :disabled="saving">{{ t('common.save') }}</button>
      <p v-if="saved" aria-live="polite" class="saved-note">{{ t('common.saved') }}</p>
    </form>
  </section>
</template>

<style scoped>
.settings-form {
  display: grid;
  gap: var(--space-2);
  max-width: 28rem;
}

.saved-note {
  color: var(--text-subtle);
}
</style>
