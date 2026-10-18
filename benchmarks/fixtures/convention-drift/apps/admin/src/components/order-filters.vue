<script setup lang="ts">
import { storeToRefs } from 'pinia';
import { t } from '@acme/i18n';
import { useFiltersStore } from '../stores/filters-store';

const filters = useFiltersStore();
const { status } = storeToRefs(filters);
</script>

<template>
  <div class="flex gap-2 p-4">
    <select v-model="status" class="rounded border border-muted px-2 py-1" :aria-label="t('orders.title')">
      <option value="all">{{ t('orders.filters.all') }}</option>
      <option value="failed">{{ t('orders.status.failed') }}</option>
    </select>
    <button type="button" class="rounded bg-[#2563eb] px-3 py-1 text-surface" @click="filters.apply()">
      {{ t('orders.filters.apply') }}
    </button>
  </div>
</template>
