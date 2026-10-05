<script setup lang="ts">
import { useI18n } from 'vue-i18n';

const { locale, availableLocales, t } = useI18n();

function change(next: string) {
  locale.value = next;
  localStorage.setItem('dispatch-locale', next);
}
</script>

<template>
  <label class="locale">
    {{ t('nav.language') }}
    <select :value="locale" @change="change(($event.target as HTMLSelectElement).value)">
      <option v-for="l in availableLocales" :key="l" :value="l">{{ l.toUpperCase() }}</option>
    </select>
  </label>
</template>
